import { supabase } from '@/lib/supabase';
import { notFound, permanentRedirect } from 'next/navigation';

// صفحة التصنيف الفرعي صارت داخل صفحة التصنيف الرئيسي
// /category-offers/[id]  →  /category/[parent]?sub=[id]
export default async function CategoryOffersRedirect({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { data } = await supabase
    .from('product_categories')
    .select('parent_id')
    .eq('id', id)
    .maybeSingle();

  if (!data?.parent_id) notFound();
  permanentRedirect(`/category/${data.parent_id}?sub=${id}`);
}
