-- ترتيب ظهور التصنيفات (نُفّذ في 2026-10-08)
-- الأدمن يرتّب بالسحب والإفلات في صفحة التصنيفات (admin.redmarket.pro)،
-- والموقع يعرض حسب sort_order ثم الاسم.

-- 1) عمود الترتيب
alter table public.store_categories          add column if not exists sort_order integer;
alter table public.product_categories        add column if not exists sort_order integer;
alter table public.sup_product_subcategories add column if not exists sort_order integer;

-- 2) البداية = الترتيب الأبجدي داخل كل مستوى
update public.store_categories t set sort_order = s.rn
from (select id, row_number() over (order by name) rn from public.store_categories) s
where t.id = s.id and t.sort_order is null;

update public.product_categories t set sort_order = s.rn
from (select id, row_number() over (partition by parent_id order by name) rn from public.product_categories) s
where t.id = s.id and t.sort_order is null;

update public.sup_product_subcategories t set sort_order = s.rn
from (select id, row_number() over (partition by parent_id order by name) rn from public.sup_product_subcategories) s
where t.id = s.id and t.sort_order is null;

-- 3) التصنيف الجديد يُضاف في آخر قائمته
create or replace function public.set_category_sort_order()
returns trigger language plpgsql as $$
begin
  if new.sort_order is null then
    if tg_table_name = 'store_categories' then
      select coalesce(max(sort_order), 0) + 1 into new.sort_order from public.store_categories;
    else
      execute format('select coalesce(max(sort_order), 0) + 1 from public.%I where parent_id is not distinct from $1', tg_table_name)
        into new.sort_order using new.parent_id;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_category_sort_order on public.store_categories;
create trigger trg_category_sort_order before insert on public.store_categories
  for each row execute function public.set_category_sort_order();

drop trigger if exists trg_category_sort_order on public.product_categories;
create trigger trg_category_sort_order before insert on public.product_categories
  for each row execute function public.set_category_sort_order();

drop trigger if exists trg_category_sort_order on public.sup_product_subcategories;
create trigger trg_category_sort_order before insert on public.sup_product_subcategories
  for each row execute function public.set_category_sort_order();

-- 4) حفظ الترتيب بعد السحب — للأدمن فقط
create or replace function public.reorder_categories(p_table text, p_ids uuid[])
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin') then
    raise exception 'غير مصرح';
  end if;
  if p_table not in ('store_categories', 'product_categories', 'sup_product_subcategories') then
    raise exception 'جدول غير معروف';
  end if;
  execute format(
    'update public.%I t set sort_order = x.ord from unnest($1) with ordinality as x(id, ord) where t.id = x.id',
    p_table) using p_ids;
end $$;

revoke all on function public.reorder_categories(text, uuid[]) from public, anon;
grant execute on function public.reorder_categories(text, uuid[]) to authenticated;
