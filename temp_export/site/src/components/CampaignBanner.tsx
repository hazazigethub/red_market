import Link from 'next/link';
import Image from 'next/image';
import type { Campaign } from '@/lib/campaignApi';

/// بنر الحملة الموسمية — ثابت بنسبة 30:7
export default function CampaignBanner({
  campaign,
}: {
  campaign: Campaign | null;
}) {
  if (!campaign || !campaign.banner_image) return null;

  return (
    <Link
      href="/campaign"
      className="block relative w-full aspect-[30/7] overflow-hidden bg-gray-100"
    >
      <Image
        src={campaign.banner_image}
        alt={campaign.title}
        fill
        // البنر داخل حاوية محدودة — لا بعرض الشاشة كاملاً
        sizes="(max-width: 768px) 400px, 1100px"
        quality={70}
        // عنصر LCP على الجوال — يُحمَّل بأولوية بلا تأجيل
        priority
        fetchPriority="high"
        className="object-cover"
      />
    </Link>
  );
}
