import Link from "next/link";
import { getExhibition } from "@/lib/queries";
import { Announcements } from "@/components/client/Announcements";
import { Tracker } from "@/components/client/Tracker";

export default async function ExhibitionLayout({ children, params }: {
  children: React.ReactNode; params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const e = await getExhibition(slug);
  const nav = [
    ["", "الرئيسية"], ["/lobby", "اللوبي والأجنحة"], ["/sessions", "الجلسات"],
    ["/speakers", "المتحدثون"], ["/sponsors", "الرعاة"], ["/search", "بحث"],
  ];
  return (
    <>
      <Tracker exhibition_id={e.id} event="exhibition_view" recordVisit />
      <Announcements exhibitionId={e.id} />
      <div className="border-b border-line bg-surface">
        <nav className="container-x flex gap-6 overflow-x-auto py-3 text-sm font-medium" aria-label={e.title}>
          <span className="shrink-0 font-heading font-bold text-ink">{e.title}</span>
          {nav.map(([p, l]) => <Link key={p} href={`/e/${slug}${p}`} className="shrink-0 text-muted hover:text-primary">{l}</Link>)}
        </nav>
      </div>
      {children}
    </>
  );
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const e = await getExhibition(slug);
  return { title: e.title, description: e.description?.slice(0, 160) };
}
