-- ============================================================
-- الاشتراك في الباقات: الدفع من رصيد المحفظة
-- يُنفَّذ في Supabase ← SQL Editor
-- نفس توقيع apply_upgrade الحالي، فلا يتغيّر شيء في استدعاء اللوحة.
-- ============================================================
-- المعادلة (مطابقة لما تعرضه صفحة الدفع):
--   القيمة   = قيمة الفترة (new_cost من calc_proration) − خصم الكود
--   المستحق  = القيمة − رصيد الباقة الحالية (credit من calc_proration)
-- أسعار الباقات شاملة الضريبة، فلا تُضاف ضريبة.
-- ============================================================

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
          false,   -- لا تجديد تلقائي حالياً
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
