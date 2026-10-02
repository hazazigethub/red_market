-- ============================================================
-- إحصائيات المدفوعات للإدارة — استدعاء واحد يجمع كل ما تحتاجه اللوحة
-- يُنفَّذ في Supabase ← SQL Editor
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_admin_payment_stats(p_days int DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_role  text;
  v_days  int  := LEAST(GREATEST(COALESCE(p_days, 30), 1), 365);
  v_today date := (now() AT TIME ZONE 'Asia/Riyadh')::date;
  v_from  date;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'super_admin' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'غير مصرّح');
  END IF;

  v_from := v_today - (v_days - 1);

  RETURN jsonb_build_object(
    'ok', true,
    'days', v_days,

    -- المبالغ المستلمة عبر البوابة خلال الفترة
    'total_received', (
      SELECT COALESCE(SUM(total_amount), 0) FROM public.payments
      WHERE status = 'completed'
        AND (created_at AT TIME ZONE 'Asia/Riyadh')::date >= v_from),

    'completed_count', (
      SELECT COUNT(*) FROM public.payments
      WHERE status = 'completed'
        AND (created_at AT TIME ZONE 'Asia/Riyadh')::date >= v_from),

    'failed_count', (
      SELECT COUNT(*) FROM public.payments
      WHERE status = 'failed'
        AND (created_at AT TIME ZONE 'Asia/Riyadh')::date >= v_from),

    'pending_count', (
      SELECT COUNT(*) FROM public.payments
      WHERE status IN ('pending', 'processing')
        AND (created_at AT TIME ZONE 'Asia/Riyadh')::date >= v_from),

    -- ما صرفه التجار من أرصدتهم خلال الفترة
    'total_spent', (
      SELECT COALESCE(SUM(-amount), 0) FROM public.wallet_transactions
      WHERE type = 'purchase'
        AND (created_at AT TIME ZONE 'Asia/Riyadh')::date >= v_from),

    -- أرصدة التجار غير المصروفة حالياً (التزام على المنصة)
    'wallets_balance', (
      SELECT COALESCE(SUM(balance), 0) FROM public.merchant_wallets),

    -- المستلم يومياً
    'daily', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'day', d.day, 'amount', COALESCE(x.amount, 0)) ORDER BY d.day), '[]'::jsonb)
      FROM (SELECT generate_series(v_from, v_today, interval '1 day')::date AS day) d
      LEFT JOIN (
        SELECT (created_at AT TIME ZONE 'Asia/Riyadh')::date AS day,
               SUM(total_amount) AS amount
        FROM public.payments
        WHERE status = 'completed'
          AND (created_at AT TIME ZONE 'Asia/Riyadh')::date >= v_from
        GROUP BY 1
      ) x ON x.day = d.day),

    -- آخر 20 عملية
    'recent', (
      SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r.created_at DESC), '[]'::jsonb)
      FROM (
        SELECT p.id, p.created_at, p.total_amount, p.status, p.payment_type,
               p.payment_method, p.failure_reason, m.store_name
        FROM public.payments p
        LEFT JOIN public.merchants m ON m.id = p.merchant_id
        ORDER BY p.created_at DESC
        LIMIT 20
      ) r)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_admin_payment_stats(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_admin_payment_stats(int) TO authenticated;
