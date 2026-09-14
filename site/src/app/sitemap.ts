import type { MetadataRoute } from 'next';
import { supabase } from '@/lib/supabase';

const BASE =
  process.env.NEXT_PUBLIC_SITE_URL ?? 'https://redmarket.pro';

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();

  // الصفحات الثابتة
  const staticPages: MetadataRoute.Sitemap = [
    { url: `${BASE}/`, lastModified: now, changeFrequency: 'hourly', priority: 1 },
    { url: `${BASE}/categories`, lastModified: now, changeFrequency: 'daily', priority: 0.9 },
    { url: `${BASE}/reels`, lastModified: now, changeFrequency: 'daily', priority: 0.8 },
    { url: `${BASE}/campaign`, lastModified: now, changeFrequency: 'daily', priority: 0.8 },
    { url: `${BASE}/search`, lastModified: now, changeFrequency: 'weekly', priority: 0.6 },
    { url: `${BASE}/merchants`, lastModified: now, changeFrequency: 'weekly', priority: 0.7 },
    { url: `${BASE}/about`, lastModified: now, changeFrequency: 'monthly', priority: 0.4 },
    { url: `${BASE}/faq`, lastModified: now, changeFrequency: 'monthly', priority: 0.4 },
    { url: `${BASE}/support`, lastModified: now, changeFrequency: 'monthly', priority: 0.4 },
    { url: `${BASE}/terms`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
    { url: `${BASE}/privacy`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
  ];

  try {
    // المتاجر النشطة والعروض المتاحة
    const [merchantsRes, productsRes, categoriesRes, subCatsRes] =
      await Promise.all([
      supabase
        .from('merchants')
        .select('id, updated_at')
        .eq('is_subscription_active', true)
        .eq('is_banned', false)
        .limit(1000),
      supabase
        .from('products')
        .select('id, updated_at')
        .eq('is_available', true)
        .eq('is_banned', false)
        .order('created_at', { ascending: false })
        .limit(2000),
      supabase
        .from('store_categories')
        .select('id')
        .eq('is_visible', true)
        .limit(200),
      supabase
        .from('product_categories')
        .select('id')
        .eq('is_visible', true)
        .limit(500),
    ]);

    const merchants: MetadataRoute.Sitemap = (merchantsRes.data ?? []).map(
      (m) => ({
        url: `${BASE}/store/${m.id}`,
        lastModified: m.updated_at ? new Date(m.updated_at) : now,
        changeFrequency: 'daily' as const,
        priority: 0.7,
      })
    );

    const products: MetadataRoute.Sitemap = (productsRes.data ?? []).map(
      (p) => ({
        url: `${BASE}/offer/${p.id}`,
        lastModified: p.updated_at ? new Date(p.updated_at) : now,
        changeFrequency: 'daily' as const,
        priority: 0.6,
      })
    );

    const categories: MetadataRoute.Sitemap = (categoriesRes.data ?? []).map(
      (c) => ({
        url: `${BASE}/category/${c.id}`,
        lastModified: now,
        changeFrequency: 'weekly' as const,
        priority: 0.5,
      })
    );

    const subCategories: MetadataRoute.Sitemap = (subCatsRes.data ?? []).map(
      (c) => ({
        url: `${BASE}/category-offers/${c.id}`,
        lastModified: now,
        changeFrequency: 'daily' as const,
        priority: 0.6,
      })
    );

    return [
      ...staticPages,
      ...categories,
      ...subCategories,
      ...merchants,
      ...products,
    ];
  } catch (err) {
    console.error('sitemap error:', err);
    // الصفحات الثابتة على الأقل — لا تُفشل الخريطة كلياً
    return staticPages;
  }
}
