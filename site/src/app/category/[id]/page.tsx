import { supabase } from '@/lib/supabase';
import ProductCard from '@/components/ProductCard';
import type { Product } from '@/lib/types';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import type { Metadata } from 'next';
import VisitLogger from '@/components/VisitLogger';

// التصنيف الرئيسي + الفرعي + فرع الفرعي في صفحة واحدة
// ?sub=<product_categories.id>&leaf=<sup_product_subcategories.id>

type Cat = { id: string; name: string | null };

async function getData(id: string, sub?: string, leaf?: string) {
  const { data: category } = await supabase
    .from('store_categories')
    .select('id, name')
    .eq('id', id)
    .maybeSingle();

  if (!category) return null;

  const { data: subsData } = await supabase
    .from('product_categories')
    .select('id, name')
    .eq('parent_id', id)
    .eq('is_visible', true)
    .order('sort_order', { ascending: true }).order('name');
  const subs = (subsData as Cat[]) ?? [];

  // الفرعي المختار يجب أن يتبع هذا التصنيف
  const activeSub = sub && subs.some((s) => String(s.id) === sub) ? sub : null;

  let leaves: Cat[] = [];
  if (activeSub) {
    const { data } = await supabase
      .from('sup_product_subcategories')
      .select('id, name')
      .eq('parent_id', activeSub)
      .eq('is_visible', true)
      .order('sort_order', { ascending: true }).order('name');
    leaves = (data as Cat[]) ?? [];
  }
  const activeLeaf =
    activeSub && leaf && leaves.some((l) => String(l.id) === leaf) ? leaf : null;

  let products: Product[] = [];

  if (activeLeaf) {
    // فرع الفرعي — نفس استعلام صفحة فرع الفرعي السابقة
    const { data } = await supabase
      .from('products')
      .select('*')
      .eq('sub_category_id', activeLeaf)
      .eq('is_available', true)
      .limit(60);
    products = (data as Product[]) ?? [];
  } else if (activeSub) {
    // الفرعي — نفس دالة صفحة التصنيف الفرعي السابقة
    const { data } = await supabase.rpc('get_category_products', {
      p_category_ids: [activeSub],
      p_limit: 60,
    });
    products = (data as Product[]) ?? [];
  } else if (subs.length > 0) {
    // الرئيسي — كل الفرعيات
    const { data } = await supabase
      .from('products')
      .select('*')
      .in(
        'category_id',
        subs.map((s) => s.id)
      )
      .eq('is_available', true)
      .order('created_at', { ascending: false })
      .limit(60);
    products = (data as Product[]) ?? [];
  }

  return { category, subs, leaves, activeSub, activeLeaf, products };
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

function Chip({
  href,
  active,
  label,
  small = false,
}: {
  href: string;
  active: boolean;
  label: string;
  small?: boolean;
}) {
  return (
    <Link
      prefetch={false}
      scroll={false}
      href={href}
      className={`shrink-0 snap-start whitespace-nowrap rounded-lg border transition-colors ${
        small ? 'px-3 py-1.5 text-xs' : 'px-4 py-2 text-sm'
      } ${
        active
          ? 'bg-[#D32027] border-[#D32027] text-white font-bold'
          : 'bg-white border-gray-200 text-gray-600 hover:border-red-300 hover:text-red-700'
      }`}
    >
      {label}
    </Link>
  );
}

export default async function CategoryPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ sub?: string; leaf?: string }>;
}) {
  const { id } = await params;
  const { sub, leaf } = await searchParams;
  const data = await getData(id, sub, leaf);

  if (!data) notFound();
  const { category, subs, leaves, activeSub, activeLeaf, products } = data;

  const base = `/category/${category.id}`;
  const subName = subs.find((s) => String(s.id) === activeSub)?.name;
  const leafName = leaves.find((l) => String(l.id) === activeLeaf)?.name;

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
        <Link href={base} scroll={false} className="hover:text-red-700">
          {category.name}
        </Link>
        {subName && (
          <>
            <span className="mx-2">/</span>
            <span className="text-gray-700">{subName}</span>
          </>
        )}
        {leafName && (
          <>
            <span className="mx-2">/</span>
            <span className="text-gray-700">{leafName}</span>
          </>
        )}
      </nav>

      <h1 className="text-2xl font-bold">{leafName ?? subName ?? category.name}</h1>
      <p className="text-sm text-gray-500 mt-1">{products.length} عرض</p>

      {/* ===== الفرعية: شريط يُسحب أفقياً ===== */}
      {subs.length > 0 && (
        <div className="flex gap-2 overflow-x-auto snap-x mt-6 pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <Chip href={base} active={!activeSub} label="الكل" />
          {subs.map((s) => (
            <Chip
              key={s.id}
              href={`${base}?sub=${s.id}`}
              active={String(s.id) === activeSub}
              label={s.name ?? 'تصنيف'}
            />
          ))}
        </div>
      )}

      {/* ===== فرع الفرعية: شريط ثانٍ يظهر عند اختيار فرعي ===== */}
      {activeSub && leaves.length > 0 && (
        <div className="flex gap-2 overflow-x-auto snap-x mt-2 pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <Chip
            small
            href={`${base}?sub=${activeSub}`}
            active={!activeLeaf}
            label="الكل"
          />
          {leaves.map((l) => (
            <Chip
              small
              key={l.id}
              href={`${base}?sub=${activeSub}&leaf=${l.id}`}
              active={String(l.id) === activeLeaf}
              label={l.name ?? 'فرع'}
            />
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
