import Link from "next/link";
import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtNum, LEAD_STATUS, timeAgo } from "@/lib/format";
import { Stat } from "@/components/ui";

export default async function BoothOverview({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const b = await getStaffBooth(id);
  const db = await expo();
  const [{ data: stats }, { data: leads }, { count: products }, { count: media }] = await Promise.all([
    db.rpc("merchant_stats", { p_booth: id, p_days: 7 }),
    db.from("exhibition_leads").select("id, full_name, status, source, created_at").eq("booth_id", id).order("created_at", { ascending: false }).limit(6),
    db.from("booth_products").select("product_id", { count: "exact", head: true }).eq("booth_id", id),
    db.from("booth_media").select("id", { count: "exact", head: true }).eq("booth_id", id),
  ]);
  const s = (stats ?? {}) as { booth_views?: number; followers?: number; leads?: number; chats?: number };
  const checklist = [
    { ok: !!b.logo_path && !!b.cover_path, label: "الشعار وصورة الغلاف", href: "/edit" },
    { ok: !!b.about && b.about.length > 80, label: "نبذة وافية عن الجناح", href: "/edit" },
    { ok: (products ?? 0) >= 3, label: "3 منتجات على الأقل", href: "/products" },
    { ok: (media ?? 0) >= 1, label: "صور أو فيديو أو كتالوج", href: "/media" },
    { ok: b.status === "published", label: "نشر الجناح", href: "/edit" },
  ];
  const done = checklist.filter((c) => c.ok).length;
  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat label="زيارات الجناح" value={fmtNum(s.booth_views)} />
        <Stat label="العملاء المحتملون" value={fmtNum(s.leads)} />
        <Stat label="المحادثات" value={fmtNum(s.chats)} />
        <Stat label="المتابعون" value={fmtNum(s.followers)} />
      </div>
      {b.role !== "agent" && done < checklist.length && (
        <div className="card p-5">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="font-heading text-lg font-bold">جهّز جناحك</h2><span className="text-sm text-muted">{done} من {checklist.length}</span>
          </div>
          <div className="mb-4 h-2 overflow-hidden rounded-full bg-bg"><div className="h-full bg-primary" style={{ width: `${(done / checklist.length) * 100}%` }} /></div>
          <ul className="flex flex-col gap-2 text-sm">
            {checklist.map((c) => (
              <li key={c.label} className="flex items-center gap-2">
                <span className={c.ok ? "text-success" : "text-muted"}>{c.ok ? "✓" : "○"}</span>
                {c.ok ? <span className="text-muted line-through">{c.label}</span>
                  : <Link href={`/merchant/booths/${id}${c.href}`} className="font-medium hover:text-primary">{c.label}</Link>}
              </li>
            ))}
          </ul>
        </div>
      )}
      <div className="card">
        <div className="flex items-center justify-between border-b border-line p-4">
          <h2 className="font-heading text-lg font-bold">أحدث العملاء المحتملين</h2>
          <Link href={`/merchant/booths/${id}/leads`} className="text-sm font-semibold text-primary">الكل</Link>
        </div>
        {(leads?.length ?? 0) === 0 ? <p className="p-4 text-sm text-muted">لا يوجد عملاء بعد. سيظهرون هنا فور تواصل الزوار.</p> : (
          <ul className="divide-y divide-line">
            {leads!.map((l) => (
              <li key={l.id}><Link href={`/merchant/booths/${id}/leads/${l.id}`} className="flex items-center gap-3 p-4 hover:bg-bg/60">
                <span className="flex-1 font-medium">{l.full_name}</span><span className="badge">{LEAD_STATUS[l.status]}</span>
                <span className="text-xs text-muted">{timeAgo(l.created_at)}</span></Link></li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
