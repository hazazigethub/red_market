import { getExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import type { Sponsor } from "@/lib/types";
import { SponsorWall } from "@/components/cards";
import { EmptyState } from "@/components/ui";

export const metadata = { title: "الرعاة" };

export default async function Sponsors({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const e = await getExhibition(slug);
  const db = await expo();
  const [{ data }, { data: booths }] = await Promise.all([
    db.from("sponsors").select("*").eq("exhibition_id", e.id).order("sort_order"),
    db.from("booths").select("id, slug").eq("exhibition_id", e.id),
  ]);
  const boothSlugs = Object.fromEntries((booths ?? []).map((b) => [b.id, b.slug]));
  return (
    <div className="container-x py-8">
      <h1 className="section-title mb-6">الرعاة والشركاء</h1>
      {(data?.length ?? 0) === 0 ? <EmptyState title="لم يُعلن عن الرعاة بعد" />
        : <SponsorWall sponsors={data as Sponsor[]} boothSlugs={boothSlugs} exhibitionSlug={slug} />}
    </div>
  );
}
