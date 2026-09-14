import { supabase } from '@/lib/supabase';
import HeroBanner from '@/components/HeroBanner';
import SmallBanners from '@/components/SmallBanners';
import CategoryStrip from '@/components/CategoryStrip';
import RotatingMerchants from '@/components/RotatingMerchants';
import RotatingProducts from '@/components/RotatingProducts';
import CuratedProducts from '@/components/CuratedProducts';
import CategoryRows from '@/components/CategoryRows';
import FollowedStoresFeed from '@/components/FollowedStoresFeed';
import RecentlyViewed from '@/components/RecentlyViewed';
import CategoryShowcase from '@/components/CategoryShowcase';
import DiscoverMore from '@/components/DiscoverMore';
import VisitLogger from '@/components/VisitLogger';
import CampaignBanner from '@/components/CampaignBanner';
import { getActiveCampaign } from '@/lib/campaignApi';
import type { Product, Category, Merchant } from '@/lib/types';

export const revalidate = 60;

async function getData() {
  const nowIso = new Date().toISOString();

  const [wideRes, smallRes, catRes, latestRes, flashRes, merchRes] =
    await Promise.all([
      supabase
        .from('banners')
        .select('id, image_url, product_id, merchant_id, category_id')
        .eq('is_active', true)
        .eq('banner_type', 'wide'),
      supabase
        .from('banners')
        .select('id, image_url, product_id, merchant_id, category_id')
        .eq('is_active', true)
        .eq('banner_type', 'small'),
      supabase
        .from('store_categories')
        .select('*')
        .eq('is_visible', true),
      supabase
        .from('products')
        .select('*')
        .eq('is_available', true)
        // العروض المجدولة تُخفى حتى موعدها
        .or(`flash_sale_start.is.null,flash_sale_start.lte.${nowIso}`)
        .order('created_at', { ascending: false })
        .limit(100),
      supabase
        .from('products')
        .select('*')
        .eq('is_available', true)
        .eq('is_flash_sale', true)
        .or(`flash_sale_start.is.null,flash_sale_start.lte.${nowIso}`)
        .gt('flash_sale_expiry', nowIso),
      // المتاجر المميّزة: احترافيون فقط، أو الجميع إن كانوا أقل من 5
      supabase.rpc('get_featured_merchants'),
    ]);

  return {
    wide: wideRes.data ?? [],
    small: smallRes.data ?? [],
    categories: (catRes.data as Category[]) ?? [],
    latest: (latestRes.data as Product[]) ?? [],
    flash: (flashRes.data as Product[]) ?? [],
    merchants: (merchRes.data as Merchant[]) ?? [],
  };
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-5">
      <h2 className="text-base font-bold mb-3">{title}</h2>
      {children}
    </section>
  );
}

export default async function Home() {
  const [{ wide, small, categories, latest, flash, merchants }, campaign] =
    await Promise.all([getData(), getActiveCampaign()]);

  return (
    <main className="max-w-6xl mx-auto px-4 py-6 overflow-x-hidden">
      <VisitLogger page="home" />

      {/* الترتيب موحّد مع التطبيق */}

      {categories.length > 0 && (
        <div className="mt-2">
          <CategoryStrip categories={categories} />
        </div>
      )}

      {/* البنرات تمتد لحافتي الشاشة على الجوال — والنصّ يبقى بهامشه */}
      <div className="mt-6 -mx-4 md:mx-0">
        <HeroBanner banners={wide} />
      </div>

      {campaign && (
        <div className="mt-6 -mx-4 md:mx-0">
          <CampaignBanner campaign={campaign} />
        </div>
      )}

      {flash.length > 0 && (
        <Section title="عروض 24 ساعة">
          <RotatingProducts products={flash} show={12} />
        </Section>
      )}

      <CuratedProducts />

      {small.length > 0 && (
        <div className="mt-3 -mx-4 md:mx-0">
          <SmallBanners banners={small} />
        </div>
      )}

      {merchants.length > 0 && (
        <Section title="المتاجر">
          <RotatingMerchants merchants={merchants} products={latest} />
        </Section>
      )}

      <Section title="وصل حديثاً">
        {latest.length === 0 ? (
          <p className="text-gray-500 py-12 text-center">
            لا توجد عروض حالياً
          </p>
        ) : (
          <RotatingProducts products={latest} show={18} />
        )}
      </Section>

      <FollowedStoresFeed />

      <CategoryRows />

      <RecentlyViewed />
      <CategoryShowcase />
      <DiscoverMore />
    </main>
  );
}
