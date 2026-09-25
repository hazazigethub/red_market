import Link from "next/link";
import { getStaffBooth } from "@/lib/queries";
import { Logo, StatusBadge } from "@/components/ui";

export default async function BoothAdminLayout({ children, params }: { children: React.ReactNode; params: Promise<{ id: string }> }) {
  const { id } = await params;
  const b = await getStaffBooth(id);
  const canManage = b.role !== "agent";
  const nav: [string, string, boolean][] = [
    ["", "نظرة عامة", true], ["/edit", "بناء الجناح", canManage], ["/products", "المنتجات", canManage], ["/media", "الوسائط", canManage],
    ["/studio", "البث المباشر", canManage], ["/inbox", "المحادثات", true], ["/leads", "العملاء المحتملون", true],
    ["/notes", "الملاحظات", true], ["/analytics", "التحليلات", true], ["/team", "الفريق", true],
  ];
  return (
    <div className="container-x py-6">
      <div className="mb-5 flex flex-wrap items-center gap-4">
        <Logo path={b.logo_path} name={b.name} size={52} />
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h1 className="truncate font-heading text-2xl font-extrabold">{b.name}</h1>
            <span className="badge">{b.status === "published" ? "منشور" : b.status === "hidden" ? "مخفي" : "مسودة"}</span>
          </div>
          <p className="text-sm text-muted">{b.exhibitions.title}</p>
        </div>
        <StatusBadge status={b.exhibitions.status} />
        <Link href={`/e/${b.exhibitions.slug}/b/${b.slug}`} target="_blank" className="btn-ghost btn-sm">عرض الجناح كزائر</Link>
      </div>
      <div className="grid gap-6 lg:grid-cols-[210px_1fr]">
        <nav className="flex gap-1 overflow-x-auto lg:flex-col" aria-label="إدارة الجناح">
          <Link href="/merchant" className="shrink-0 rounded-lg px-3 py-2 text-sm text-muted hover:bg-surface">← كل الأجنحة</Link>
          {nav.filter(([, , show]) => show).map(([p, l]) => (
            <Link key={p} href={`/merchant/booths/${id}${p}`} className="shrink-0 rounded-lg px-3 py-2 text-sm font-medium hover:bg-surface">{l}</Link>
          ))}
        </nav>
        <div className="min-w-0">{children}</div>
      </div>
    </div>
  );
}
