-- ============================================================
-- الاشتراك المجاني (كود 100% أو فترة تجريبية):
--   1) الترقية منه = سعر الباقة الجديدة كاملاً، ومدة جديدة كاملة
--   2) لا يتجدد تلقائياً أبداً — ولا يمكن تفعيل تجديده
-- يُنفَّذ في Supabase ← SQL Editor
-- ============================================================

-- ------------------------------------------------------------
-- 1) calc_proration — نفس النسخة السابقة؛ تغيّر "المسار 2" فقط
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calc_proration(p_new_plan_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_cur RECORD;
  v_cur_days int;
  v_new public.subscription_plans%ROWTYPE;
  v_days_left numeric;
  v_total_days numeric;
  v_credit numeric;
  v_new_cost numeric;
  v_due numeric;
  v_same_cycle boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'غير مسجّل');
  END IF;

  SELECT * INTO v_new FROM public.subscription_plans
  WHERE id = p_new_plan_id AND is_active;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'الباقة غير متاحة');
  END IF;

  SELECT ms.price, ms.plan_id, ms.started_at, ms.expires_at
  INTO v_cur
  FROM public.merchant_subscriptions ms
  WHERE ms.merchant_id = v_uid AND ms.status = 'active'
  ORDER BY ms.created_at DESC LIMIT 1;

  -- المسار 1: اشتراك جديد
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'mode', 'new',
      'credit', 0, 'new_cost', v_new.price, 'due', v_new.price,
      'days_left', 0, 'keep_expiry', false, 'full_price', v_new.price);
  END IF;

  -- المسار 2: ترقية من اشتراك مجاني (كود 100% أو تجريبي) — السعر كاملاً بلا رصيد
  IF COALESCE(v_cur.price, 0) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'mode', 'free_upgrade',
      'credit', 0, 'new_cost', v_new.price, 'due', v_new.price,
      'days_left', 0, 'keep_expiry', false, 'full_price', v_new.price);
  END IF;

  -- الرصيد التناسبي من الباقة الحالية المدفوعة
  v_days_left := GREATEST(0,
    EXTRACT(epoch FROM (v_cur.expires_at - now())) / 86400);
  v_total_days := GREATEST(1,
    EXTRACT(epoch FROM (v_cur.expires_at - v_cur.started_at)) / 86400);

  v_credit := ROUND((v_cur.price / v_total_days) * v_days_left, 2);

  -- هل المدتان متطابقتان؟ (شهري→شهري أو سنوي→سنوي)
  SELECT duration_days INTO v_cur_days
  FROM public.subscription_plans WHERE id = v_cur.plan_id;

  v_same_cycle := (COALESCE(v_cur_days, 30) >= 365)
                  = (v_new.duration_days >= 365);

  IF v_same_cycle THEN
    -- المسار 3أ: نفس الدورة — يدفع فرق الأيام المتبقية ويبقى التاريخ
    v_new_cost := ROUND((v_new.price / v_new.duration_days) * v_days_left, 2);
    v_due := GREATEST(0, ROUND(v_new_cost - v_credit, 2));

    RETURN jsonb_build_object('ok', true, 'mode', 'paid_upgrade',
      'credit', v_credit, 'new_cost', v_new_cost, 'due', v_due,
      'days_left', ROUND(v_days_left), 'keep_expiry', true,
      'full_price', v_new.price);
  ELSE
    -- المسار 3ب: تغيّرت الدورة — سعر كامل ناقص الرصيد، ومدة جديدة
    v_due := GREATEST(0, ROUND(v_new.price - v_credit, 2));

    RETURN jsonb_build_object('ok', true, 'mode', 'cycle_change',
      'credit', v_credit, 'new_cost', v_new.price, 'due', v_due,
      'days_left', ROUND(v_days_left), 'keep_expiry', false,
      'full_price', v_new.price);
  END IF;
END;
$function$;

-- ------------------------------------------------------------
-- 2) toggle_auto_renew — منع تفعيل التجديد على أي اشتراك مجاني (تجريبي أو بكود 100%)
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
    WHERE merchant_id = v_uid AND status = 'active'
      AND (is_trial OR COALESCE(price, 0) = 0)
  ) THEN
    RETURN jsonb_build_object('ok', false,
      'error', 'الاشتراك المجاني لا يتجدد تلقائياً — عند انتهائه اشترك في باقة مدفوعة');
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
-- 3) renew_subscriptions — حماية إضافية: لا يجدد أي اشتراك سعره 0
--    (يعدّل سطر الشرط فقط، وباقي الدالة كما هو)
-- ------------------------------------------------------------
DO $do$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'renew_subscriptions';

  IF position('COALESCE(ms.price, 0) > 0' IN v_def) > 0 THEN
    RAISE NOTICE 'renew_subscriptions — معدّلة مسبقاً';
    RETURN;
  END IF;

  -- مطابقة مرنة: لا تتأثر بالمسافات أو نهايات الأسطر
  IF v_def !~ 'AND\s+NOT\s+ms\.is_trial' THEN
    RAISE EXCEPTION 'لم يُعثر على سطر الشرط في renew_subscriptions';
  END IF;

  EXECUTE regexp_replace(
    v_def,
    'AND\s+NOT\s+ms\.is_trial',
    'AND NOT ms.is_trial AND COALESCE(ms.price, 0) > 0'
  );
END
$do$;

-- ------------------------------------------------------------
-- 4) إيقاف التجديد على أي اشتراك مجاني فعّال حالياً، وعرض العدد
-- ------------------------------------------------------------
WITH fixed AS (
  UPDATE public.merchant_subscriptions
  SET auto_renew = false
  WHERE status = 'active' AND auto_renew AND (is_trial OR COALESCE(price, 0) = 0)
  RETURNING id
)
SELECT
  (SELECT COUNT(*) FROM fixed) AS free_subscriptions_fixed,
  (SELECT COUNT(*) FROM pg_proc WHERE proname = 'renew_subscriptions'
     AND prosrc LIKE '%COALESCE(ms.price, 0) > 0%') AS renew_guard_installed;
