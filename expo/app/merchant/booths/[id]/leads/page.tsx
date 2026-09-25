import Link from "next/link";
import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { LEAD_SOURCE, LEAD_STATUS, timeAgo } from "@/lib/format";
import type { Lead } from "@/lib/types";
import { EmptyState } from "@/components/ui";
import { InboxLive } from "@/components/client/InboxLive";
import { ExportLeadsButton } from "@/components/client/uploads";

export default async function Leads({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<{ status?: string; source?: string; q?: string; view?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const b = await getStaffBooth(id);
  const db = await expo();
  let q = db.from("exhibition_leads").select("*").eq("booth_id", id).order("last_activity_at", { ascending: false }).limit(500);
  if (sp.status) q = q.eq("status", sp.status);
  if (sp.source) q = q.eq("source", sp.source);
  if (sp.q) q = q.or(`full_name.ilike.%${sp.q.replace(/[%,()]/g, "")}%,company.ilike.%${sp.q.replace(/[%,()]/g, "")}%,phone.ilike.%${sp.q.replace(/[%,()]/g, "")}%`);
  const { data } = await q;
  const leads = (data ?? []) as Lead[];
  const view = sp.view === "pipeline" ? "pipeline" : "table";
  const link = (o: Record<string, string | undefined>) =>
    "?" + new URLSearchParams(Object.entries({ ...sp, ...o }).filter(([, v]) => v) as [string, string][]);

  return (
    <div className="flex flex-col gap-4">
      <InboxLive boothId={id} />
      <div className="flex flex-wrap items-center gap-2">
        <form className="flex flex-wrap gap-2">
          <input name="q" defaultValue={sp.q} className="input w-48" placeholder="اسم، شركة، جوال" />
          <select name="status" defaultValue={sp.status ?? ""} className="input w-36">
            <option value="">كل الحالات</option>{Object.entries(LEAD_STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          <select name="source" defaultValue={sp.source ?? ""} className="input w-40">
            <option value="">كل المصادر</option>{Object.entries(LEAD_SOURCE).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          <input type="hidden" name="view" value={view} />
          <button className="btn-ghost btn-sm">تصفية</button>
        </form>
        <div className="ms-auto flex gap-2">
          <Link href={link({ view: "table" })} className={view === "table" ? "btn-ink btn-sm" : "btn-ghost btn-sm"}>جدول</Link>
          <Link href={link({ view: "pipeline" })} className={view === "pipeline" ? "btn-ink btn-sm" : "btn-ghost btn-sm"}>مراحل</Link>
          {b.role !== "agent" && <ExportLeadsButton boothId={id} status={sp.status} />}
        </div>
      </div>

      {leads.length === 0 ? <EmptyState title="لا يوجد عملاء محتملون" body="يُسجَّل العميل عندما يرسل الزائر استفساراً، أو يبدأ محادثة، أو ينزّل كتالوجاً محمياً بعد موافقته." /> :
        view === "table" ? (
          <div className="card overflow-x-auto">
            <table className="table-x">
              <thead><tr><th>الاسم</th><th>التواصل</th><th>المصدر</th><th>الحالة</th><th>التفاعل</th><th>آخر نشاط</th></tr></thead>
              <tbody>
                {leads.map((l) => (
                  <tr key={l.id} className="hover:bg-bg/50">
                    <td><Link href={`/merchant/booths/${id}/leads/${l.id}`} className="font-semibold hover:text-primary">{l.full_name}</Link>
                      {l.company && <span className="block text-xs text-muted">{l.company}</span>}</td>
                    <td dir="ltr" className="text-right text-xs">{l.phone}<br />{l.email}</td>
                    <td><span className="badge">{LEAD_SOURCE[l.source]}</span></td>
                    <td><span className="badge">{LEAD_STATUS[l.status]}</span></td>
                    <td className="tabular-nums">{l.score}</td>
                    <td className="text-xs text-muted">{timeAgo(l.last_activity_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="grid gap-3 overflow-x-auto pb-2" style={{ gridTemplateColumns: "repeat(6, minmax(210px, 1fr))" }}>
            {Object.entries(LEAD_STATUS).map(([k, v]) => {
              const col = leads.filter((l) => l.status === k);
              return (
                <div key={k} className="flex flex-col gap-2 rounded-2xl bg-surface/60 p-2">
                  <p className="px-2 pt-1 text-sm font-bold">{v} <span className="text-muted">({col.length})</span></p>
                  {col.map((l) => (
                    <Link key={l.id} href={`/merchant/booths/${id}/leads/${l.id}`} className="card p-3 text-sm hover:border-ink">
                      <p className="font-semibold">{l.full_name}</p>
                      <p className="text-xs text-muted">{LEAD_SOURCE[l.source]} · {timeAgo(l.last_activity_at)}</p>
                    </Link>
                  ))}
                </div>
              );
            })}
          </div>
        )}
    </div>
  );
}
