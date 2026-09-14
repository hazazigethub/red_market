import { supabase } from '@/lib/supabase';
import ProductCard from '@/components/ProductCard';
import type { Product } from '@/lib/types';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import type { Metadata } from 'next';
import VisitLogger from '@/components/VisitLogger';

export const revalidate = 120;

// تُبنى كل التصنيفات وقت البناء — فلا ينتظر الزائر
export async function generateStaticParams() {
  const { data } = await supabase
    .from('store_categories')
    .select('id')
    .eq('is_visible', true)
    .limit(200);

  return (data ?? []).map((c) => ({ id: String(c.id) }));
}

async function getCategoryData(id: string) {
  const { data: category } = await supabase
    .from('store_categories')
    .select('id, name')
    .eq('id', id)
    .maybeSingle();

  if (!category) return { category: null, subs: [], products: [] };

  const { data: subs } = await supabase
    .from('product_categories')
    .select('id, name')
    .eq('parent_id', id)
    .eq('is_visible', true)
    .order('name');

  const subIds = (subs ?? []).map((s) => s.id);

  let products: Product[] = [];
  if (subIds.length > 0) {
    const { data } = await supabase
      .from('products')
      .select('*')
      .in('category_id', subIds)
      .eq('is_available', true)
      .order('created_at', { ascending: false })
      .limit(60);
    products = (data as Product[]) ?? [];
  }

  return {
    category,
    subs: subs ?? [],
    products,
  };
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const { data } = await supabase
    .from('store_categories')
    .select('name')
    .eq('id', id)
    .maybeSingle();

  const name = data?.name ?? 'تصنيف';
  return {
    title: `${name} — رد ماركت`,
    description: `تصفّح عروض ${name} على رد ماركت`,
  };
}

export default async function CategoryPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { category, subs, products } = await getCategoryData(id);

  if (!category) notFound();

  return (
    <main className="max-w-6xl mx-auto px-4 py-8">
      <VisitLogger
        page="category"
        categoryId={category.id}
        categoryName={category.name}
      />

      <nav className="text-sm text-gray-500 mb-4">
        <Link href="/categories" className="hover:text-red-700">
          التصنيفات
        </Link>
        <span className="mx-2">/</span>
        <span className="text-gray-700">{category.name}</span>
      </nav>

      <h1 className="text-2xl font-bold">{category.name}</h1>
      <p className="text-sm text-gray-500 mt-1">{products.length} عرض</p>

      {subs.length > 0 && (
        <div className="flex gap-2 overflow-x-auto mt-6 pb-2">
          {subs.map((s) => (
            <Link
              prefetch={false}
              key={s.id}
              href={`/category-offers/${s.id}`}
              className="shrink-0 px-4 py-2 rounded-lg border border-gray-200 text-sm text-gray-600 whitespace-nowrap hover:border-red-300 hover:text-red-700 transition-colors"
            >
              {s.name}
            </Link>
          ))}
        </div>
      )}

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
