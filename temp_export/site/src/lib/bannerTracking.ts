import { supabaseBrowser } from '@/lib/supabase-client';

/// يمنع تكرار احتساب نفس البنر في نفس الجلسة والعرض
const seen = new Set<string>();

/// يُحتسب الظهور مرة واحدة لكل بنر في كل تحميل صفحة
export async function trackImpression(bookingId?: string | null) {
  if (!bookingId) return;
  if (seen.has(bookingId)) return;
  seen.add(bookingId);

  try {
    await supabaseBrowser.rpc('track_banner_impression', {
      p_booking_id: bookingId,
    });
  } catch (err) {
    console.error('impression error:', err);
  }
}

/// يُحتسب النقر في كل ضغطة
export async function trackClick(bookingId?: string | null) {
  if (!bookingId) return;

  try {
    await supabaseBrowser.rpc('track_banner_click', {
      p_booking_id: bookingId,
    });
  } catch (err) {
    console.error('click error:', err);
  }
}
