import { supabase } from '@/lib/supabase';

/// أسماء الصفحات المسجّلة
export type PageName =
  | 'home'
  | 'store'
  | 'product'
  | 'category'
  | 'search'
  | 'reels';

type VisitOptions = {
  merchantId?: string | null;
  categoryId?: string | null;
  categoryName?: string | null;
};

/// يمنع تكرار تسجيل الصفحة نفسها في الجلسة الواحدة
const sessionKey = (page: string, id?: string | null) =>
  `visit:${page}:${id ?? ''}`;

/// حارس فوري في الذاكرة — يمنع التنفيذ المزدوج في وضع التطوير
const inFlight = new Set<string>();

function alreadyLogged(key: string): boolean {
  if (typeof window === 'undefined') return true;
  try {
    return sessionStorage.getItem(key) === '1';
  } catch {
    return false;
  }
}

function markLogged(key: string) {
  if (typeof window === 'undefined') return;
  try {
    sessionStorage.setItem(key, '1');
  } catch {
    // تجاهل
  }
}

/**
 * يسجّل زيارة صفحة في جدول analytics_visits.
 * يعمل في المتصفح فقط، ولا يوقف الصفحة عند الفشل.
 */
export async function logVisit(
  page: PageName,
  options: VisitOptions = {},
): Promise<void> {
  if (typeof window === 'undefined') return;

  const {
    merchantId = null,
    categoryId = null,
    categoryName = null,
  } = options;

  // زيارة واحدة لكل صفحة في الجلسة
  const key = sessionKey(page, merchantId ?? categoryId ?? categoryName);
  if (inFlight.has(key) || alreadyLogged(key)) return;

  // يُحجز فوراً قبل أي انتظار
  inFlight.add(key);
  markLogged(key);

  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    await supabase.from('analytics_visits').insert({
      page_name: page,
      platform: 'web',
      user_id: user?.id ?? null,
      merchant_id: merchantId,
      category_id: categoryId,
      category_name: categoryName,
      visited_at: new Date().toISOString(),
    });

  } catch (err) {
    console.error('logVisit error:', err);
  } finally {
    inFlight.delete(key);
  }
}
