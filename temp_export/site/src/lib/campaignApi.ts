import { supabase } from '@/lib/supabase';

export type Campaign = {
  id: string;
  title: string;
  description: string | null;
  banner_image: string | null;
  starts_at: string;
  ends_at: string;
  entry_fee: number;
  days_left: number;
  product_count: number;
};

/// يجلب الحملة النشطة إن وُجدت
export async function getActiveCampaign(): Promise<Campaign | null> {
  try {
    const { data, error } = await supabase.rpc('get_active_campaign');
    if (error || !data) return null;
    return data as Campaign;
  } catch (err) {
    console.error('campaign error:', err);
    return null;
  }
}
