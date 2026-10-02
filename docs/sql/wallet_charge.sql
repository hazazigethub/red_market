-- ============================================================
-- شحن المحفظة من دفعة MyFatoorah مكتملة
-- يُنفَّذ في Supabase ← SQL Editor
-- ============================================================

-- علامة تمنع إضافة نفس الدفعة للرصيد مرتين
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS wallet_credited_at timestamptz;

CREATE OR REPLACE FUNCTION public.credit_wallet_from_payment(p_payment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_pay   public.payments%ROWTYPE;
  v_owner uuid;
  v_new   numeric;
BEGIN
  SELECT * INTO v_pay
  FROM public.payments
  WHERE id = p_payment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'الدفعة غير موجودة');
  END IF;

  IF v_pay.payment_type <> 'wallet_charge' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ليست عملية شحن رصيد');
  END IF;

  IF v_pay.status <> 'completed' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'الدفعة غير مكتملة');
  END IF;

  -- أُضيفت مسبقاً: لا شيء (آمن للتكرار من callback و webhook)
  IF v_pay.wallet_credited_at IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'already', true);
  END IF;

  -- المحفظة مرتبطة بمعرّف المستخدم، والدفعة مرتبطة بالمتجر
  SELECT owner_id INTO v_owner
  FROM public.merchants
  WHERE id = v_pay.merchant_id;

  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'صاحب المتجر غير معروف');
  END IF;

  INSERT INTO public.merchant_wallets (merchant_id)
  VALUES (v_owner)
  ON CONFLICT (merchant_id) DO NOTHING;

  UPDATE public.merchant_wallets
  SET balance       = balance + v_pay.amount,
      total_charged = total_charged + v_pay.amount,
      updated_at    = now()
  WHERE merchant_id = v_owner
  RETURNING balance INTO v_new;

  INSERT INTO public.wallet_transactions
    (merchant_id, type, amount, balance_after, description, payment_id)
  VALUES
    (v_owner, 'charge', v_pay.amount, v_new,
     'شحن الرصيد عبر بوابة الدفع', v_pay.myratoorah_payment_id);

  UPDATE public.payments
  SET wallet_credited_at = now()
  WHERE id = p_payment_id;

  RETURN jsonb_build_object('ok', true, 'credited', v_pay.amount, 'balance', v_new);
END;
$function$;

-- الخادم فقط يستطيع استدعاءها (لا اللوحة ولا التطبيق)
REVOKE ALL ON FUNCTION public.credit_wallet_from_payment(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.credit_wallet_from_payment(uuid) TO service_role;
