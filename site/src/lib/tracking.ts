import { supabaseBrowser } from '@/lib/supabase-client';

/// معرّف ثابت للجهاز — لحذف تكرار الانتقالات من الزوار غير المسجلين
function deviceId(): string | null {
  if (typeof window === 'undefined') return null;
  try {
    let id = localStorage.getItem('rm_device_id');
    if (!id) {
      id = crypto.randomUUID();
      localStorage.setItem('rm_device_id', id);
    }
    return id;
  } catch {
    return null;
  }
}

/// مؤشر الأداء: انتقال العميل إلى متجر التاجر
export async function logStoreClick(opts: {
  productId?: string | number | null;
  merchantId?: string | null;
  source: 'product' | 'store';
}): Promise<void> {
  if (typeof window === 'undefined') return;
  try {
    await supabaseBrowser.from('store_clicks').insert({
      product_id: opts.productId != null ? String(opts.productId) : null,
      merchant_id: opts.merchantId ?? null,
      source: opts.source,
      device_id: deviceId(),
      platform: 'web',
    });
  } catch (err) {
    console.error('logStoreClick error:', err);
  }
}

/// مؤشر الأداء: البحث وعدد نتائجه
export async function logSearch(query: string, resultsCount: number): Promise<void> {
  if (typeof window === 'undefined') return;
  const q = query.trim().slice(0, 200);
  if (q.length < 2) return;
  try {
    await supabaseBrowser.from('search_logs').insert({
      query: q,
      results_count: resultsCount,
      platform: 'web',
    });
  } catch (err) {
    console.error('logSearch error:', err);
  }
}
