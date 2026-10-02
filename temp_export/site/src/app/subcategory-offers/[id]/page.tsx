import { supabase } from '@/lib/supabase';
import { notFound, permanentRedirect } from 'next/navigation';

// صفحة فرع الفرعي صارت داخل صفحة التصنيف الرئيسي
// /subcategory-offers/[id]  →  /category/[main]?sub=[parent]&leaf=[id]
export default async function SubCategoryOffersRedirect({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { data: leaf } = await supabase
    .from('sup_product_subcategories')
    .select('parent_id')
    .eq('id', id)
    .maybeSingle();

  if (!leaf?.parent_id) notFound();

  const { data: sub } = await supabase
    .from('product_categories')
    .select('parent_id')
    .eq('id', leaf.parent_id)
    .maybeSingle();

  if (!sub?.parent_id) notFound();
  permanentRedirect(
    `/category/${sub.parent_id}?sub=${leaf.parent_id}&leaf=${id}`
  );
}
