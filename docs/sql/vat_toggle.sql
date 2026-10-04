-- ============================================================
-- الضريبة مربوطة بالرقم الضريبي في الإعدادات
--   رقم ضريبي موجود ← 15%    ·    غير موجود ← 0%
-- يُنفَّذ في Supabase ← SQL Editor
-- ============================================================

-- ------------------------------------------------------------
-- 1) النسبة الحالية
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_vat_rate()
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT COALESCE((
    SELECT CASE
             WHEN NULLIF(trim(COALESCE(seller_vat_number, '')), '') IS NULL THEN 0
             ELSE COALESCE(vat_rate, 15)
           END
    FROM public.system_settings
    ORDER BY id
    LIMIT 1
  ), 0);
$function$;

GRANT EXECUTE ON FUNCTION public.current_vat_rate() TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) دوال الشراء: استبدال سطر الضريبة الثابت فقط، وباقي كل دالة كما هو
-- ------------------------------------------------------------
DO $do$
DECLARE
  r       record;
  v_def   text;
  v_old   constant text := 'ROUND(v_subtotal * 0.15, 2)';
  v_new   constant text := 'ROUND(v_subtotal * public.current_vat_rate() / 100, 2)';
  v_count int := 0;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('purchase_banner', 'purchase_splash_ad', 'book_banner', 'purchase_campaign_quota')
  LOOP
    v_def := pg_get_functiondef(r.oid);

    IF position(v_new IN v_def) > 0 THEN
      RAISE NOTICE '% — معدّلة مسبقاً', r.proname;
      CONTINUE;
    END IF;

    IF position(v_old IN v_def) = 0 THEN
      RAISE EXCEPTION 'لم يُعثر على سطر الضريبة في %', r.proname;
    END IF;

    EXECUTE replace(v_def, v_old, v_new);
    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'عُدّلت % دوال', v_count;
END
$do$;

-- ------------------------------------------------------------
-- 3) فواتير الحملات بنوع "campaign" بدل "custom"
-- ------------------------------------------------------------
DO $do$
DECLARE
  v_def text;
  v_old1 constant text := $$v_type := CASE WHEN v_sub_id IS NOT NULL THEN 'subscription' ELSE 'custom' END;$$;
  v_new1 constant text := $$v_type := CASE WHEN v_sub_id IS NOT NULL THEN 'subscription' WHEN NEW.description LIKE '% عرض في حملة %' THEN 'campaign' ELSE 'custom' END;$$;
  v_old2 constant text := $$v_item := CASE WHEN v_sub_id IS NOT NULL THEN 'subscription' ELSE 'service' END;$$;
  v_new2 constant text := $$v_item := CASE WHEN v_sub_id IS NOT NULL THEN 'subscription' WHEN NEW.description LIKE '% عرض في حملة %' THEN 'campaign_quota' ELSE 'service' END;$$;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'issue_document_for_wallet_tx';

  IF position('campaign_quota' IN v_def) > 0 THEN
    RAISE NOTICE 'issue_document_for_wallet_tx — معدّلة مسبقاً';
    RETURN;
  END IF;

  IF position(v_old1 IN v_def) = 0 OR position(v_old2 IN v_def) = 0 THEN
    RAISE EXCEPTION 'لم يُعثر على سطري النوع في issue_document_for_wallet_tx';
  END IF;

  EXECUTE replace(replace(v_def, v_old1, v_new1), v_old2, v_new2);
END
$do$;

-- ------------------------------------------------------------
-- 4) تحقق: النسبة الحالية، وعدد الدوال التي لم يبقَ فيها 0.15
-- ------------------------------------------------------------
SELECT public.current_vat_rate() AS current_rate,
       (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN ('purchase_banner','purchase_splash_ad','book_banner','purchase_campaign_quota')
          AND p.prosrc LIKE '%current_vat_rate()%') AS functions_updated;
