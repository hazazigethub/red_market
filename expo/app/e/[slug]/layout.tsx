import { NavLink } from "@/components/client/NavLink";
import { getExhibition } from "@/lib/queries";
import { Announcements } from "@/components/client/Announcements";
import { Tracker } from "@/components/client/Tracker";

export default async function ExhibitionLayout({ children, params }: {
  children: React.ReactNode; params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const e = await getExhibition(slug);
  const base = `/e/${slug}`;
  const nav: { href: string; label: string; exact?: boolean; also?: string[] }[] = [
    { href: base, label: "الرئيسية", exact: true },
    { href: `${base}/lobby`, label: "اللوبي والأجنحة", also: [`${base}/b`, `${base}/live`] },
    { href: `${base}/sessions`, label: "الجلسات" },
    { href: `${base}/speakers`, label: "المتحدثون" },
    { href: `${base}/sponsors`, label: "الرعاة" },
    { href: `${base}/search`, label: "بحث" },
  ];
  return (
    <>
      <Tracker exhibition_id={e.id} event="exhibition_view" recordVisit />
      <Announcements exhibitionId={e.id} />
      <div className="border-b border-line bg-surface">
        <nav className="container-x flex gap-6 overflow-x-auto py-3 text-sm font-medium" aria-label={e.title}>
          <span className="shrink-0 font-heading font-bold text-ink">{e.title}</span>
          {nav.map((n) => (
            <NavLink key={n.href} href={n.href} exact={n.exact} also={n.also}
              className="shrink-0 border-b-2 pb-1"
              activeClassName="border-primary font-semibold text-primary"
              inactiveClassName="border-transparent text-muted hover:text-primary">{n.label}</NavLink>
          ))}
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
