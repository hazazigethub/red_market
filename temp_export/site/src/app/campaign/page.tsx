import { notFound } from 'next/navigation';
import Image from 'next/image';
import { supabase } from '@/lib/supabase';
import { getActiveCampaign } from '@/lib/campaignApi';
import CampaignProducts from '@/components/CampaignProducts';

export const revalidate = 60;

export async function generateMetadata() {
  const c = await getActiveCampaign();
  return {
    title: c ? `${c.title} — رد ماركت` : 'الحملة الموسمية — رد ماركت',
    description: c?.description ?? 'عروض موسمية من متاجر رد ماركت',
  };
}

export default async function CampaignPage() {
  const campaign = await getActiveCampaign();
  if (!campaign) notFound();

  // تصنيفات الحملة بعدد عروض كل واحد
  const { data: cats } = await supabase.rpc('get_campaign_categories', {
    p_campaign_id: campaign.id,
  });

  const categories = (cats ?? []) as {
    id: string;
    name: string;
    product_count: number;
  }[];

  return (
    <main className="min-h-screen bg-gray-50">
      {/* ===== ترويسة الحملة ===== */}
      {campaign.banner_image ? (
        <div className="relative w-full aspect-[30/7] bg-gray-100">
          <Image
            src={campaign.banner_image}
            alt={campaign.title}
            fill
            sizes="(max-width: 768px) 100vw, 1100px"
            // عنصر LCP في هذه الصفحة
            priority
            fetchPriority="high"
            className="object-cover"
          />
        </div>
      ) : (
        <div
          className="w-full py-14 px-6 text-center"
          style={{
            background: 'linear-gradient(135deg, #D32027, #8E1010)',
          }}
        >
          <h1 className="text-3xl font-bold text-white">{campaign.title}</h1>
        </div>
      )}

      <div className="max-w-6xl mx-auto px-4">
        {/* ===== العروض ===== */}
        <div className="py-6">
          <CampaignProducts
            campaignId={campaign.id}
            categories={categories}
          />
        </div>
      </div>
    </main>
  );
}
