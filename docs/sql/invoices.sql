-- ============================================================
-- الفواتير والإيصالات التلقائية
-- يُنفَّذ في Supabase ← SQL Editor
-- ------------------------------------------------------------
-- • كل شراء من الرصيد (اشتراك/ترقية/تجديد/بنر/إعلان افتتاح) ← فاتورة
-- • كل شحن رصيد عبر البوابة ← إيصال
-- • بدون رقم ضريبي: "فاتورة" بلا ضريبة
--   مع رقم ضريبي: "فاتورة ضريبية مبسطة" + ضريبة + رمز QR (المرحلة الأولى لهيئة الزكاة)
-- لا يغيّر أي دالة شراء: يعمل عبر trigger على wallet_transactions
-- ============================================================

-- ------------------------------------------------------------
-- 1) بيانات المنشأة (البائع) — الرقم الضريبي اختياري
-- ------------------------------------------------------------
ALTER TABLE public.system_settings
  ADD COLUMN IF NOT EXISTS seller_name       text,
  ADD COLUMN IF NOT EXISTS seller_cr_number  text,
  ADD COLUMN IF NOT EXISTS seller_address    text,
  ADD COLUMN IF NOT EXISTS seller_vat_number text,
  ADD COLUMN IF NOT EXISTS vat_rate          numeric NOT NULL DEFAULT 15;

-- ------------------------------------------------------------
-- 2) أعمدة إضافية: لقطة بيانات البائع والمشتري وقت الإصدار
-- ------------------------------------------------------------
ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS is_tax_invoice        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS seller_name           text,
  ADD COLUMN IF NOT EXISTS seller_cr_number      text,
  ADD COLUMN IF NOT EXISTS seller_address        text,
  ADD COLUMN IF NOT EXISTS seller_vat_number     text,
  ADD COLUMN IF NOT EXISTS buyer_name            text,
  ADD COLUMN IF NOT EXISTS buyer_vat_number      text,
  ADD COLUMN IF NOT EXISTS qr_base64             text,
  ADD COLUMN IF NOT EXISTS splash_ad_id          uuid REFERENCES public.splash_ads(id),
  ADD COLUMN IF NOT EXISTS wallet_transaction_id uuid UNIQUE;

ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS amount                numeric,
  ADD COLUMN IF NOT EXISTS wallet_transaction_id uuid UNIQUE;

CREATE SEQUENCE IF NOT EXISTS public.invoice_number_seq;
CREATE SEQUENCE IF NOT EXISTS public.receipt_number_seq;

-- ------------------------------------------------------------
-- 3) رمز QR بصيغة TLV (هيئة الزكاة — المرحلة الأولى)
--    1 اسم البائع · 2 الرقم الضريبي · 3 الوقت · 4 الإجمالي · 5 الضريبة
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.zatca_qr(
  p_seller text, p_vat_no text, p_time timestamptz, p_total numeric, p_vat numeric)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $function$
DECLARE
  v_vals text[] := ARRAY[
    COALESCE(p_seller, ''),
    COALESCE(p_vat_no, ''),
    to_char(p_time AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    to_char(p_total, 'FM999999990.00'),
    to_char(p_vat,   'FM999999990.00')];
  v_out bytea := ''::bytea;
  v_b   bytea;
  i     int;
BEGIN
  FOR i IN 1..5 LOOP
    v_b   := convert_to(v_vals[i], 'UTF8');
    v_out := v_out || set_byte(set_byte('\x0000'::bytea, 0, i), 1, octet_length(v_b)) || v_b;
  END LOOP;
  RETURN replace(encode(v_out, 'base64'), E'\n', '');
END;
$function$;

-- ------------------------------------------------------------
-- 4) إصدار المستند تلقائياً لكل حركة محفظة
--    يعمل عند نهاية العملية (DEFERRED) حتى يكون الاشتراك/الحجز قد أُنشئ
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.issue_document_for_wallet_tx()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_m        RECORD;
  v_set      RECORD;
  v_pay_id   uuid;
  v_total    numeric;
  v_vat      numeric := 0;
  v_rate     numeric;
  v_tax      boolean;
  v_type     text;
  v_item     text;
  v_desc     text;
  v_qty      int := 1;
  v_sub_id   uuid;
  v_book_id  uuid;
  v_splash   RECORD;
  v_splash_id uuid;
  v_book     RECORD;
  v_inv_id   uuid;
  v_year     text := to_char(now() AT TIME ZONE 'Asia/Riyadh', 'YYYY');
BEGIN
  SELECT id, store_name, vat_number INTO v_m
  FROM public.merchants
  WHERE owner_id = NEW.merchant_id
  ORDER BY created_at
  LIMIT 1;

  IF v_m.id IS NULL THEN
    RETURN NULL;
  END IF;

  -- ===== شحن رصيد ← إيصال =====
  IF NEW.type = 'charge' THEN
    IF NEW.payment_id IS NULL THEN RETURN NULL; END IF;   -- أرصدة يدوية/تجريبية بلا دفعة

    SELECT id INTO v_pay_id FROM public.payments
    WHERE myratoorah_payment_id = NEW.payment_id
    LIMIT 1;
    IF v_pay_id IS NULL THEN RETURN NULL; END IF;

    INSERT INTO public.receipts (merchant_id, payment_id, receipt_number, amount, wallet_transaction_id)
    VALUES (v_m.id, v_pay_id,
            'RCP-' || v_year || '-' || lpad(nextval('public.receipt_number_seq')::text, 6, '0'),
            NEW.amount, NEW.id)
    ON CONFLICT (wallet_transaction_id) DO NOTHING;
    RETURN NULL;
  END IF;

  -- ===== استرداد إلغاء بنر ← إلغاء فاتورته =====
  IF NEW.type = 'refund' THEN
    IF NEW.booking_id IS NOT NULL THEN
      UPDATE public.invoices
      SET status = 'cancelled',
          notes  = COALESCE(notes || ' — ', '') || 'أُلغي الحجز وأُعيد المبلغ للرصيد'
      WHERE booking_id = NEW.booking_id AND status <> 'cancelled';
    END IF;
    RETURN NULL;
  END IF;

  IF NEW.type <> 'purchase' OR NEW.amount >= 0 THEN
    RETURN NULL;
  END IF;

  -- ===== شراء ← فاتورة =====
  v_total := -NEW.amount;

  SELECT * INTO v_set FROM public.system_settings ORDER BY id LIMIT 1;
  v_tax  := NULLIF(trim(COALESCE(v_set.seller_vat_number, '')), '') IS NOT NULL;
  v_rate := COALESCE(v_set.vat_rate, 15);

  IF NEW.booking_id IS NOT NULL THEN
    SELECT slots_count, vat_amount, banner_type INTO v_book
    FROM public.banner_bookings WHERE id = NEW.booking_id;

    v_type    := 'banner';
    v_item    := 'banner_slot';
    v_book_id := NEW.booking_id;
    v_qty     := GREATEST(COALESCE(v_book.slots_count, 1), 1);
    v_vat     := COALESCE(v_book.vat_amount, 0);
    v_desc    := 'بنر إعلاني ' ||
                 CASE WHEN v_book.banner_type = 'wide' THEN 'عريض' ELSE 'صغير' END;
  ELSE
    SELECT id, ad_date, vat_amount INTO v_splash
    FROM public.splash_ads
    WHERE merchant_id = NEW.merchant_id AND created_at = NEW.created_at
    LIMIT 1;

    IF v_splash.id IS NOT NULL THEN
      v_splash_id := v_splash.id;
      v_type := 'splash_ad';
      v_item := 'splash_ad';
      v_vat  := COALESCE(v_splash.vat_amount, 0);
      v_desc := 'إعلان الشاشة الافتتاحية — ' || v_splash.ad_date;
    ELSE
      SELECT id INTO v_sub_id
      FROM public.merchant_subscriptions
      WHERE merchant_id = NEW.merchant_id AND created_at = NEW.created_at
      ORDER BY created_at DESC
      LIMIT 1;

      v_type := CASE WHEN v_sub_id IS NOT NULL THEN 'subscription' ELSE 'custom' END;
      v_item := CASE WHEN v_sub_id IS NOT NULL THEN 'subscription' ELSE 'service' END;
      v_desc := COALESCE(NEW.description, 'خدمة');
      -- أسعار الباقات شاملة الضريبة
      v_vat  := ROUND(v_total * v_rate / (100 + v_rate), 2);
    END IF;
  END IF;

  -- بدون رقم ضريبي: لا تُظهر ضريبة
  IF NOT v_tax THEN
    v_vat := 0;
  END IF;

  INSERT INTO public.invoices (
    merchant_id, invoice_number, invoice_date, invoice_type,
    subtotal, vat_percent, vat_amount, total_amount,
    status, subscription_id, booking_id, splash_ad_id,
    description, payment_terms, issued_at, paid_at,
    is_tax_invoice, seller_name, seller_cr_number, seller_address, seller_vat_number,
    buyer_name, buyer_vat_number, qr_base64, wallet_transaction_id
  ) VALUES (
    v_m.id,
    'INV-' || v_year || '-' || lpad(nextval('public.invoice_number_seq')::text, 6, '0'),
    (now() AT TIME ZONE 'Asia/Riyadh')::date,
    v_type,
    v_total - v_vat,
    CASE WHEN v_tax THEN v_rate ELSE 0 END,
    v_vat,
    v_total,
    'paid', v_sub_id, v_book_id, v_splash_id,
    v_desc, NULL, now(), now(),
    v_tax, v_set.seller_name, v_set.seller_cr_number, v_set.seller_address,
    NULLIF(trim(COALESCE(v_set.seller_vat_number, '')), ''),
    v_m.store_name, v_m.vat_number,
    CASE WHEN v_tax
         THEN public.zatca_qr(v_set.seller_name, v_set.seller_vat_number, now(), v_total, v_vat)
    END,
    NEW.id
  )
  ON CONFLICT (wallet_transaction_id) DO NOTHING
  RETURNING id INTO v_inv_id;

  IF v_inv_id IS NOT NULL THEN
    INSERT INTO public.invoice_items (invoice_id, description, quantity, unit_price, line_total, item_type)
    VALUES (v_inv_id, v_desc, v_qty,
            ROUND((v_total - v_vat) / v_qty, 2), v_total - v_vat, v_item);
  END IF;

  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.issue_document_for_wallet_tx() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_issue_document_for_wallet_tx ON public.wallet_transactions;
CREATE CONSTRAINT TRIGGER trg_issue_document_for_wallet_tx
AFTER INSERT ON public.wallet_transactions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.issue_document_for_wallet_tx();

-- ------------------------------------------------------------
-- 5) صلاحيات القراءة: التاجر يرى مستنداته فقط، والإدارة ترى الكل
-- ------------------------------------------------------------
ALTER TABLE public.invoices         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_history  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_webhooks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Merchants view own invoices" ON public.invoices;
CREATE POLICY "Merchants view own invoices" ON public.invoices FOR SELECT
USING (merchant_id IN (SELECT id FROM public.merchants WHERE owner_id = auth.uid()));

DROP POLICY IF EXISTS "Merchants view own payments" ON public.payments;
CREATE POLICY "Merchants view own payments" ON public.payments FOR SELECT
USING (merchant_id IN (SELECT id FROM public.merchants WHERE owner_id = auth.uid()));

DROP POLICY IF EXISTS "Merchants view own invoice items" ON public.invoice_items;
CREATE POLICY "Merchants view own invoice items" ON public.invoice_items FOR SELECT
USING (invoice_id IN (
  SELECT i.id FROM public.invoices i
  JOIN public.merchants m ON m.id = i.merchant_id
  WHERE m.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Admins view all invoice items" ON public.invoice_items;
CREATE POLICY "Admins view all invoice items" ON public.invoice_items FOR SELECT
USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'super_admin');

DROP POLICY IF EXISTS "Merchants view own receipts" ON public.receipts;
CREATE POLICY "Merchants view own receipts" ON public.receipts FOR SELECT
USING (merchant_id IN (SELECT id FROM public.merchants WHERE owner_id = auth.uid()));

DROP POLICY IF EXISTS "Admins view all receipts" ON public.receipts;
CREATE POLICY "Admins view all receipts" ON public.receipts FOR SELECT
USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'super_admin');
