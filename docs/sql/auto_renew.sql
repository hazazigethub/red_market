-- ============================================================
-- التجديد التلقائي للاشتراكات من رصيد المحفظة
-- يُنفَّذ في Supabase ← SQL Editor
-- ============================================================

-- ------------------------------------------------------------
-- 1) دالة التجديد: تعمل كل ساعة عبر cron
--    تجدد الاشتراك المفعّل تجديده إذا بقي على انتهائه ساعة أو أقل،
--    أو انتهى منذ أقل من 3 أيام (مهلة لشحن الرصيد).
--    المدة الجديدة تبدأ من تاريخ الانتهاء، فلا يخسر التاجر أي يوم.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.renew_subscriptions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r         RECORD;
  v_plan    public.subscription_plans%ROWTYPE;
  v_balance numeric;
  v_new     numeric;
  v_start   timestamptz;
  v_expires timestamptz;
  v_renewed int := 0;
  v_skipped int := 0;
BEGIN
  FOR r IN
    SELECT ms.*
    FROM public.merchant_subscriptions ms
    WHERE ms.status = 'active'
      AND ms.auto_renew
      AND ms.cancelled_at IS NULL
      AND NOT ms.is_trial
      AND ms.expires_at <= now() + interval '1 hour'
      AND ms.expires_at >  now() - interval '3 days'
    FOR UPDATE SKIP LOCKED
  LOOP
    -- الباقة لم تعد متاحة: نوقف التجديد
    SELECT * INTO v_plan FROM public.subscription_plans
    WHERE id = r.plan_id AND is_active;

    IF NOT FOUND OR v_plan.price <= 0 THEN
      UPDATE public.merchant_subscriptions SET auto_renew = false WHERE id = r.id;
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    INSERT INTO public.merchant_wallets (merchant_id)
    VALUES (r.merchant_id)
    ON CONFLICT (merchant_id) DO NOTHING;

    SELECT balance INTO v_balance
    FROM public.merchant_wallets
    WHERE merchant_id = r.merchant_id
    FOR UPDATE;

    -- رصيد غير كافٍ: لا شيء الآن، نعيد المحاولة في الساعة القادمة ضمن المهلة
    IF COALESCE(v_balance, 0) < v_plan.price THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    UPDATE public.merchant_wallets
    SET balance     = balance - v_plan.price,
        total_spent = total_spent + v_plan.price,
        updated_at  = now()
    WHERE merchant_id = r.merchant_id
    RETURNING balance INTO v_new;

    INSERT INTO public.wallet_transactions
      (merchant_id, type, amount, balance_after, description)
    VALUES
      (r.merchant_id, 'purchase', -v_plan.price, v_new,
       'تجديد تلقائي — باقة ' || v_plan.name);

    v_start   := GREATEST(r.expires_at, now());
    v_expires := v_start + (v_plan.duration_days || ' days')::interval;

    UPDATE public.merchant_subscriptions SET status = 'expired' WHERE id = r.id;

    INSERT INTO public.merchant_subscriptions
      (merchant_id, plan_id, plan_name, billing, status, price,
       original_price, discount_percent, promo_code, is_trial,
       auto_renew, started_at, expires_at)
    VALUES
      (r.merchant_id, v_plan.id, v_plan.name,
       CASE WHEN v_plan.duration_days >= 365 THEN 'yearly' ELSE 'monthly' END,
       'active', v_plan.price, v_plan.price, 0, NULL, false,
       true, v_start, v_expires);

    PERFORM set_config('app.bypass_profile_guard', 'on', true);

    UPDATE public.profiles
    SET plan_id                = v_plan.id,
        package_name           = v_plan.name,
        max_products           = v_plan.product_limit,
        max_reels              = v_plan.reels_limit,
        subscription_end_date  = v_expires,
        is_subscription_active = true
    WHERE id = r.merchant_id;

    PERFORM set_config('app.bypass_profile_guard', 'off', true);

    v_renewed := v_renewed + 1;
  END LOOP;

  RETURN jsonb_build_object('renewed', v_renewed, 'skipped', v_skipped);
END;
$function$;

-- يستدعيها cron فقط
REVOKE ALL ON FUNCTION public.renew_subscriptions() FROM PUBLIC, anon, authenticated;

-- ------------------------------------------------------------
-- 2) تشغيلها كل ساعة عند الدقيقة 0 — قبل expire_subscriptions (الدقيقة 5)
-- ------------------------------------------------------------
SELECT cron.schedule('renew-subscriptions', '0 * * * *', 'SELECT public.renew_subscriptions();');

-- ------------------------------------------------------------
-- 3) toggle_auto_renew: منع تفعيل التجديد على الفترة التجريبية
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.toggle_auto_renew(p_enabled boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'غير مسجّل');
  END IF;

  IF p_enabled AND EXISTS (
    SELECT 1 FROM public.merchant_subscriptions
    WHERE merchant_id = v_uid AND status = 'active' AND is_trial
  ) THEN
    RETURN jsonb_build_object('ok', false,
      'error', 'لا يمكن تفعيل التجديد على الفترة التجريبية');
  END IF;

  UPDATE public.merchant_subscriptions
  SET auto_renew = p_enabled,
      cancelled_at = CASE WHEN p_enabled THEN NULL ELSE cancelled_at END
  WHERE merchant_id = v_uid AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'لا يوجد اشتراك نشط');
  END IF;

  RETURN jsonb_build_object('ok', true, 'auto_renew', p_enabled);
END;
$function$;

-- ------------------------------------------------------------
-- 4) apply_upgrade: الاشتراك المدفوع يبدأ بالتجديد التلقائي مفعّلاً
--    (نفس النسخة السابقة؛ تغيّر سطر auto_renew فقط)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_upgrade(
  p_plan_id bigint,
  p_paid numeric,                       -- غير مستخدم: المبلغ يُحسب هنا فقط
  p_discount_percent numeric DEFAULT 0, -- غير مستخدم: الخصم من الكود نفسه
  p_promo_code text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_role text;
  v_plan public.subscription_plans%ROWTYPE;
  v_calc jsonb;
  v_keep boolean;
  v_base numeric;
  v_credit numeric;
  v_pct numeric := 0;
  v_value numeric;
  v_due numeric;
  v_code public.promo_codes%ROWTYPE;
  v_code_text text := NULLIF(trim(p_promo_code), '');
  v_balance numeric;
  v_new_balance numeric;
  v_expires timestamptz;
  v_cur_expires timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'غير مسجّل');
  END IF;

  -- حسابات التجار فقط
  SELECT role INTO v_role FROM public.profiles WHERE id = v_uid;
  IF v_role IS DISTINCT FROM 'merchant' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'الاشتراك متاح لحسابات التجار فقط');
  END IF;

  SELECT * INTO v_plan FROM public.subscription_plans
  WHERE id = p_plan_id AND is_active;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'الباقة غير متاحة');
  END IF;

  -- المبلغ يُحسب هنا، ولا يُقبل من التطبيق
  v_calc := public.calc_proration(p_plan_id);
  IF NOT COALESCE((v_calc->>'ok')::boolean, false) THEN
    RETURN v_calc;
  END IF;

  v_keep   := COALESCE((v_calc->>'keep_expiry')::boolean, false);
  v_base   := COALESCE((v_calc->>'new_cost')::numeric, v_plan.price);
  v_credit := COALESCE((v_calc->>'credit')::numeric, 0);

  -- كود الخصم (اختياري، أي نسبة)
  IF v_code_text IS NOT NULL THEN
    SELECT * INTO v_code FROM public.promo_codes
    WHERE lower(code) = lower(v_code_text)
      AND is_active
      AND (expiry_date IS NULL OR expiry_date > now())
      AND (plan_id IS NULL OR plan_id = p_plan_id)
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'كود الخصم غير صالح أو منتهي');
    END IF;

    IF EXISTS (SELECT 1 FROM public.merchant_subscriptions
               WHERE merchant_id = v_uid AND lower(promo_code) = lower(v_code.code)) THEN
      RETURN jsonb_build_object('ok', false, 'error', 'استخدمت هذا الكود من قبل');
    END IF;

    v_pct := LEAST(100, GREATEST(0, COALESCE(v_code.discount_percent, 0)));
  END IF;

  v_value := ROUND(v_base * (1 - v_pct / 100), 2);
  v_due   := GREATEST(0, ROUND(v_value - v_credit, 2));

  -- الخصم من الرصيد
  IF v_due > 0 THEN
    INSERT INTO public.merchant_wallets (merchant_id)
    VALUES (v_uid)
    ON CONFLICT (merchant_id) DO NOTHING;

    SELECT balance INTO v_balance
    FROM public.merchant_wallets
    WHERE merchant_id = v_uid
    FOR UPDATE;

    IF COALESCE(v_balance, 0) < v_due THEN
      RETURN jsonb_build_object('ok', false,
        'error', 'رصيدك غير كافٍ',
        'balance', COALESCE(v_balance, 0),
        'required', v_due);
    END IF;

    UPDATE public.merchant_wallets
    SET balance     = balance - v_due,
        total_spent = total_spent + v_due,
        updated_at  = now()
    WHERE merchant_id = v_uid
    RETURNING balance INTO v_new_balance;

    INSERT INTO public.wallet_transactions
      (merchant_id, type, amount, balance_after, description)
    VALUES
      (v_uid, 'purchase', -v_due, v_new_balance, 'اشتراك باقة ' || v_plan.name);
  END IF;

  SELECT expires_at INTO v_cur_expires
  FROM public.merchant_subscriptions
  WHERE merchant_id = v_uid AND status = 'active'
  ORDER BY created_at DESC LIMIT 1;

  IF v_keep AND v_cur_expires IS NOT NULL THEN
    v_expires := v_cur_expires;
  ELSE
    v_expires := now() + (v_plan.duration_days || ' days')::interval;
  END IF;

  UPDATE public.merchant_subscriptions
  SET status = 'expired'
  WHERE merchant_id = v_uid AND status = 'active';

  -- price = قيمة الاشتراك بعد الخصم؛ calc_proration يعتمد عليها لحساب رصيد الترقية القادمة
  INSERT INTO public.merchant_subscriptions
    (merchant_id, plan_id, plan_name, billing, status, price,
     original_price, discount_percent, promo_code, is_trial,
     auto_renew, started_at, expires_at)
  VALUES (v_uid, p_plan_id, v_plan.name,
          CASE WHEN v_plan.duration_days >= 365 THEN 'yearly' ELSE 'monthly' END,
          'active', v_value, v_plan.price, v_pct,
          v_code.code, false,
          (v_value > 0),   -- المدفوع يتجدد تلقائياً افتراضياً؛ المجاني لا
          now(), v_expires);

  PERFORM set_config('app.bypass_profile_guard', 'on', true);

  UPDATE public.profiles
  SET plan_id                 = p_plan_id,
      package_name            = v_plan.name,
      max_products            = v_plan.product_limit,
      max_reels               = v_plan.reels_limit,
      subscription_start_date = now(),
      subscription_end_date   = v_expires,
      is_subscription_active  = true
  WHERE id = v_uid;

  PERFORM set_config('app.bypass_profile_guard', 'off', true);

  RETURN jsonb_build_object('ok', true,
    'expires_at', v_expires,
    'mode', v_calc->>'mode',
    'paid', v_due,
    'balance', v_new_balance);
END;
$function$;
