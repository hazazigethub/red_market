import { supabase } from '@/lib/supabase';
import ProductCard from '@/components/ProductCard';
import ProductInteractions from '@/components/ProductInteractions';
import TrackView from '@/components/TrackView';
import ProductGallery from '@/components/ProductGallery';
import type { Product, Merchant } from '@/lib/types';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import type { Metadata } from 'next';

export const revalidate = 60;

const BRAND = '#D32027';
const LIGHT_RED = '#D32027';

// أحدث العروض تُبنى وقت البناء — والباقي يُبنى عند أول طلب ثم يُخزَّن
export async function generateStaticParams() {
  const { data } = await supabase
    .from('products')
    .select('id')
    .eq('is_available', true)
    .order('created_at', { ascending: false })
    .limit(500);

  return (data ?? []).map((p) => ({ id: String(p.id) }));
}

async function getProduct(id: string) {
  const { data: product } = await supabase
    .from('products')
    .select('*')
    .eq('id', id)
    .maybeSingle();

  if (!product) {
    return { product: null, merchant: null, related: [] };
  }

  const p = product as Product;

  const [merchRes, relatedRes, catRes, subCatRes] = await Promise.all([
    p.merchant_id
      ? supabase.from('merchants').select('*').eq('id', p.merchant_id).maybeSingle()
      : Promise.resolve({ data: null }),
    supabase
      .from('products')
      .select('*')
      .eq('merchant_id', p.merchant_id ?? '')
      .eq('is_available', true)
      .neq('id', id)
      .limit(5),
    p.category_id
      ? supabase
          .from('product_categories')
          .select('id, name, parent_id')
          .eq('id', p.category_id)
          .maybeSingle()
      : Promise.resolve({ data: null }),
    p.sub_category_id
      ? supabase
          .from('sup_product_subcategories')
          .select('id, name')
          .eq('id', p.sub_category_id)
          .maybeSingle()
      : Promise.resolve({ data: null }),
  ]);

  const category = catRes.data as
    | { id: string; name: string; parent_id: string }
    | null;

  // اسم التصنيف الرئيسي — نجلبه فقط إن وُجد فرعي
  const mainCat = category?.parent_id
    ? await supabase
        .from('store_categories')
        .select('id, name')
        .eq('id', category.parent_id)
        .maybeSingle()
    : { data: null };

  return {
    product: p,
    merchant: (merchRes.data as Merchant) ?? null,
    related: (relatedRes.data as Product[]) ?? [],
    category,
    mainCategory: mainCat.data as { id: string; name: string } | null,
    subCategory: subCatRes.data as { id: string; name: string } | null,
  };
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const { data } = await supabase
    .from('products')
    .select('name, description, image_url')
    .eq('id', id)
    .maybeSingle();

  const name = data?.name ?? 'عرض';
  return {
    title: `${name} — رد ماركت`,
    description: data?.description ?? `تصفّح ${name} على رد ماركت`,
    openGraph: {
      title: name,
      description: data?.description ?? '',
      images: data?.image_url ? [data.image_url] : [],
    },
  };
}

function Price({
  value,
  strike = false,
}: {
  value: number;
  strike?: boolean;
}) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <span className={strike ? 'line-through' : undefined}>
        {value.toLocaleString('en-US')}
      </span>
      <Image src="/sar.svg" alt="ر.س" width={18} height={18} className="opacity-80" />
    </span>
  );
}

export default async function ProductPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ from?: string }>;
}) {
  const { id } = await params;
  const { from } = await searchParams;
  const fromCategory = from === 'category';
  const { product, merchant, related, mainCategory, category, subCategory } =
    await getProduct(id);

  if (!product) notFound();

  const price = product.discount_price ?? product.price ?? 0;
  const oldPrice = product.old_price;
  const hasDiscount = oldPrice != null && oldPrice > price;
  const percent = hasDiscount
    ? Math.round(((oldPrice - price) / oldPrice) * 100)
    : 0;

  const images = [
    product.image_url,
    ...(product.images_url ?? []),
  ].filter(Boolean) as string[];

  return (
    <main className="max-w-6xl mx-auto px-4 py-8">
      <TrackView productId={product.id} merchantId={product.merchant_id} />

      {/* مسار التنقّل — يختلف حسب مصدر الدخول: متجر أو تصنيف */}
      <nav className="text-sm text-gray-500 mb-5 flex items-center gap-1.5 flex-wrap">
        <Link prefetch={false} href="/" className="hover:text-red-700">
          الرئيسية
        </Link>

        {fromCategory ? (
          <>
            {mainCategory && (
              <>
                <span className="text-gray-300">/</span>
                <Link
                  prefetch={false}
                  href={`/category/${mainCategory.id}`}
                  className="hover:text-red-700"
                >
                  {mainCategory.name}
                </Link>
              </>
            )}
            {category && (
              <>
                <span className="text-gray-300">/</span>
                <Link
                  prefetch={false}
                  href={`/category-offers/${category.id}`}
                  className="hover:text-red-700"
                >
                  {category.name}
                </Link>
              </>
            )}
            {subCategory && (
              <>
                <span className="text-gray-300">/</span>
                <Link
                  prefetch={false}
                  href={`/subcategory-offers/${subCategory.id}`}
                  className="hover:text-red-700"
                >
                  {subCategory.name}
                </Link>
              </>
            )}
          </>
        ) : (
          merchant && (
            <>
              <span className="text-gray-300">/</span>
              <Link
                prefetch={false}
                href={`/store/${merchant.id}`}
                className="hover:text-red-700"
              >
                {merchant.store_name ?? 'متجر'}
              </Link>
              {category && (
                <>
                  <span className="text-gray-300">/</span>
                  <Link
                    prefetch={false}
                    href={`/category-offers/${category.id}`}
                    className="hover:text-red-700"
                  >
                    {category.name}
                  </Link>
                </>
              )}
            </>
          )
        )}

        <span className="text-gray-300">/</span>
        <span className="text-gray-800">{product.name ?? 'عرض'}</span>
      </nav>

      <div className="grid md:grid-cols-2 gap-10">
        <ProductGallery images={images} alt={product.name ?? 'عرض'} />

        <div>
          <h1 className="text-2xl font-bold leading-9">
            {product.name ?? 'عرض'}
          </h1>

          {/* السعر كاملاً في سطر واحد، والزر بجانبه */}
          <div className="mt-5 flex items-center gap-4 flex-wrap">
            <div className="flex items-center gap-2 flex-wrap">
              <span
                className="text-2xl font-bold whitespace-nowrap"
                style={{ color: BRAND }}
              >
                <Price value={price} />
              </span>

              {hasDiscount && (
                <>
                  <span className="text-gray-500 line-through text-sm">
                    <Price value={oldPrice} strike />
                  </span>
                  <span
                    className="text-xs font-bold text-white px-2 py-0.5 rounded"
                    style={{ backgroundColor: LIGHT_RED }}
                  >
                    خصم {percent}%
                  </span>
                </>
              )}
            </div>

            {product.product_url && (
              <a
                href={product.product_url}
                target="_blank"
                rel="noopener noreferrer"
                className="px-6 py-2 rounded-lg text-white text-sm font-bold hover:opacity-90 transition-opacity whitespace-nowrap"
                style={{ backgroundColor: BRAND }}
              >
                شراء من المتجر
              </a>
            )}
          </div>

          {/* الوصف أسفل السعر */}
          {product.description && (
            <div className="mt-4">
              <h2 className="font-bold mb-2">الوصف</h2>
              <p className="text-gray-700 leading-7 text-sm whitespace-pre-line">
                {product.description}
              </p>
            </div>
          )}

          <ProductInteractions
            productId={product.id}
            initialLikes={product.likes_count ?? 0}
          />
        </div>
      </div>

      {related.length > 0 && (
        <section className="mt-16">
          <h2 className="text-xl font-bold mb-5">من نفس المتجر</h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
            {related.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}
    </main>
  );
}
