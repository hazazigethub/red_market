import Link from "next/link";
import { getOrganizedExhibition } from "@/lib/queries";
import { StatusBadge } from "@/components/ui";

export default async function OrgExLayout({ children, params }: { children: React.ReactNode; params: Promise<{ id: string }> }) {
  const { id } = await params;
  const e = await getOrganizedExhibition(id);
  const nav: [string, string][] = [["", "نظرة عامة"], ["/applications", "طلبات العارضين"], ["/halls", "القاعات والأجنحة"],
    ["/sessions", "الجلسات"], ["/speakers", "المتحدثون"], ["/sponsors", "الرعاة"], ["/control", "غرفة التحكم"]];
  return (
    <div className="container-x py-6">
      <div className="mb-5 flex flex-wrap items-center gap-3">
        <h1 className="me-auto font-heading text-2xl font-extrabold">{e.title}</h1>
        <StatusBadge status={e.status} />
        <Link href={`/e/${e.slug}`} target="_blank" className="btn-ghost btn-sm">عرض كزائر</Link>
      </div>
      <div className="grid gap-6 lg:grid-cols-[200px_1fr]">
        <nav className="flex gap-1 overflow-x-auto lg:flex-col" aria-label="إدارة المعرض">
          <Link href="/organizer" className="shrink-0 rounded-lg px-3 py-2 text-sm text-muted hover:bg-surface">← كل المعارض</Link>
          {nav.map(([p, l]) => <Link key={p} href={`/organizer/e/${id}${p}`} className="shrink-0 rounded-lg px-3 py-2 text-sm font-medium hover:bg-surface">{l}</Link>)}
        </nav>
        <div className="min-w-0">{children}</div>
      </div>
    </div>
  );
}
