import { supabase } from '@/lib/supabase';
import ProductCard from '@/components/ProductCard';
import type { Product } from '@/lib/types';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import type { Metadata } from 'next';

export const revalidate = 120;

// تُبنى كل التصنيفات الفرعية وقت البناء — فلا ينتظر الزائر
export async function generateStaticParams() {
  const { data } = await supabase
    .from('product_categories')
    .select('id')
    .eq('is_visible', true)
    .limit(500);

  return (data ?? []).map((c) => ({ id: String(c.id) }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const { data } = await supabase
    .from('product_categories')
    .select('name')
    .eq('id', id)
    .maybeSingle();

  const name = data?.name ?? 'تصنيف';
  return {
    title: `${name} — رد ماركت`,
    description: `تصفّح عروض ${name} على رد ماركت`,
  };
}

export default async function CategoryProductsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const [catRes, prodRes] = await Promise.all([
    supabase
      .from('product_categories')
      .select('id, name, parent_id')
      .eq('id', id)
      .maybeSingle(),
    // دالة تستبعد المحظور وعروض منتهي الاشتراك
    supabase.rpc('get_category_products', {
      p_category_ids: [id],
      p_limit: 60,
    }),
  ]);

  const category = catRes.data;
  if (!category) notFound();

  const products = (prodRes.data as Product[]) ?? [];

  return (
    <main className="max-w-6xl mx-auto px-4 py-8">
      <nav className="text-sm text-gray-500 mb-4">
        <Link href="/categories" className="hover:text-red-700">
          التصنيفات
        </Link>
        <span className="mx-2">/</span>
        <span className="text-gray-700">{category.name}</span>
      </nav>

      <h1 className="text-2xl font-bold">{category.name}</h1>
      <p className="text-sm text-gray-500 mt-1">{products.length} عرض</p>

      <section className="mt-8">
        {products.length === 0 ? (
          <p className="text-gray-500 py-16 text-center">
            لا توجد عروض في هذا التصنيف حالياً
          </p>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
            {products.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
