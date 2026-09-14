import { supabase } from '@/lib/supabase';
import StoreProducts from '@/components/StoreProducts';
import FollowButton from '@/components/FollowButton';
import ShareButton from '@/components/ShareButton';
import { TvMinimalPlay } from 'lucide-react';
import type { Product, Merchant } from '@/lib/types';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import type { Metadata } from 'next';
import VisitLogger from '@/components/VisitLogger';

export const revalidate = 60;

// متاجر التجار النشطين تُبنى وقت البناء — فلا ينتظر الزائر
export async function generateStaticParams() {
  const { data } = await supabase
    .from('merchants')
    .select('id')
    .eq('is_subscription_active', true)
    .eq('is_banned', false)
    .limit(500);

  return (data ?? []).map((m) => ({ id: String(m.id) }));
}

const BRAND = '#D32027';

async function getStore(id: string) {
  const [merchRes, prodRes] = await Promise.all([
    supabase.from('merchants').select('*').eq('id', id).maybeSingle(),
    supabase
      .from('products')
      .select('*')
      .eq('merchant_id', id)
      .eq('is_available', true)
      // العروض المجدولة تُخفى حتى موعدها
      .or(`flash_sale_start.is.null,flash_sale_start.lte.${new Date().toISOString()}`)
      .order('created_at', { ascending: false })
      .limit(60),
  ]);

  return {
    merchant: merchRes.data as Merchant | null,
    products: (prodRes.data as Product[]) ?? [],
  };
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const { data } = await supabase
    .from('merchants')
    .select('store_name, store_description')
    .eq('id', id)
    .maybeSingle();

  const name = data?.store_name ?? 'متجر';
  return {
    title: `${name} — رد ماركت`,
    description: data?.store_description ?? `تصفّح عروض ${name} على رد ماركت`,
  };
}

export default async function StorePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { merchant, products } = await getStore(id);

  if (!merchant) notFound();

  return (
    <main className="max-w-6xl mx-auto px-4 py-8">
      <VisitLogger page="store" merchantId={merchant.id} />

      <section className="pb-4">
        <div className="flex flex-col md:flex-row md:items-start gap-5 md:gap-8">
          {/* الشعار */}
          <div className="flex items-center gap-5 md:gap-0 md:block">
            <div className="relative w-20 h-20 md:w-32 md:h-32 rounded-full overflow-hidden bg-gray-100 border shrink-0">
              {merchant.logo_url ? (
                <Image
                  src={merchant.logo_url}
                  alt={merchant.store_name ?? ''}
                  fill
                  sizes="(max-width: 768px) 80px, 128px"
                  priority
                  className="object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-gray-400 text-xs">
                  متجر
                </div>
              )}
            </div>

            {/* الإحصاءات والأيقونات — بجانب الشعار على الجوال */}
            <div className="flex items-center gap-5 md:hidden">
              <div className="flex flex-col items-center leading-tight">
                <span className="text-xl font-bold text-gray-900">
                  {products.length}
                </span>
                <span className="text-xs text-gray-500">عرض</span>
              </div>

              <FollowButton
                merchantId={merchant.id}
                initialCount={merchant.followers_count ?? 0}
              />

              <div className="flex items-center gap-1.5">
                <Link
                  prefetch={false}
                  href={`/store/${merchant.id}/reels`}
                  aria-label="فيديوهات المتجر"
                  title="فيديوهات المتجر"
                  className="w-12 h-12 rounded-full flex items-center justify-center hover:bg-gray-100 transition-colors"
                  style={{ color: BRAND }}
                >
                  <TvMinimalPlay size={30} strokeWidth={1.7} />
                </Link>

                <ShareButton name={merchant.store_name ?? 'متجر'} />
              </div>
            </div>
          </div>

          {/* العمود الثاني */}
          <div className="flex-1 min-w-0">
            {/* الإحصاءات والأيقونات — صفّ مستقل على الحاسب */}
            <div className="hidden md:flex items-center gap-7 mb-4">
              <div className="flex flex-col items-center leading-tight">
                <span className="text-xl font-bold text-gray-900">
                  {products.length}
                </span>
                <span className="text-xs text-gray-500">عرض</span>
              </div>

              <FollowButton
                merchantId={merchant.id}
                initialCount={merchant.followers_count ?? 0}
              />

              <div className="flex items-center gap-2.5">
                <Link
                  prefetch={false}
                  href={`/store/${merchant.id}/reels`}
                  aria-label="فيديوهات المتجر"
                  title="فيديوهات المتجر"
                  className="w-12 h-12 rounded-full flex items-center justify-center hover:bg-gray-100 transition-colors"
                  style={{ color: BRAND }}
                >
                  <TvMinimalPlay size={30} strokeWidth={1.7} />
                </Link>

                <ShareButton name={merchant.store_name ?? 'متجر'} />
              </div>
            </div>

            <div className="flex items-center gap-3 flex-wrap">
              <h1 className="text-lg md:text-xl font-bold text-gray-900">
                {merchant.store_name ?? 'متجر'}
              </h1>

              {merchant.store_url && (
                <a
                  href={merchant.store_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="px-5 py-1.5 rounded-lg text-white text-xs font-bold hover:opacity-90 transition-opacity whitespace-nowrap"
                  style={{ backgroundColor: BRAND }}
                >
                  زيارة المتجر
                </a>
              )}
            </div>

            {merchant.store_description && (
              <p className="mt-2 text-sm text-gray-700 leading-7 whitespace-pre-line">
                {merchant.store_description}
              </p>
            )}
          </div>
        </div>
      </section>

      <section className="mt-4">
        <StoreProducts products={products} />
      </section>
    </main>
  );
}
