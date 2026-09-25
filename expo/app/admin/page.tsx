import Link from "next/link";
import { notFound } from "next/navigation";
import { expo } from "@/lib/supabase/server";
import { EXHIBITION_STATUS, fmtDate, fmtNum } from "@/lib/format";
import type { Exhibition } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { Stat, StatusBadge } from "@/components/ui";
import { forceStatus, setFeatured, setOrganizer, setStoreStatus } from "./actions";

export const metadata = { title: "إدارة المنصة" };

export default async function Admin({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const sp = await searchParams;
  const db = await expo();
  const { data: isAdmin } = await db.rpc("is_admin");
  if (!isAdmin) notFound();
  const [{ data: ov }, { data: orgs }, { data: ex }, { data: stores }] = await Promise.all([
    db.rpc("admin_overview"),
    db.from("organizers").select("*").order("is_verified").order("created_at", { ascending: false }),
    db.from("exhibitions").select("*, organizers(name)").order("starts_at", { ascending: false }).limit(200),
    db.from("store").select("id, name, status, suspended_reason, created_at, booths(count)").order("created_at", { ascending: false }).limit(500),
  ]);
  const o = ov as { exhibitions_by_status: Record<string, number>; organizers: number; booths: number; leads: number; live_streams: number; live_viewers: number; visitors_30d: number };
  return (
    <div className="container-x flex flex-col gap-8 py-8">
      <h1 className="section-title">إدارة المنصة</h1>
      <Flash error={sp.error} />
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat label="معارض مباشرة" value={o.exhibitions_by_status.live ?? 0} hint={`${o.exhibitions_by_status.scheduled ?? 0} مجدولة`} />
        <Stat label="بث مباشر الآن" value={o.live_streams} hint={`${fmtNum(o.live_viewers)} مشاهد`} />
        <Stat label="زوار آخر 30 يوماً" value={fmtNum(o.visitors_30d)} />
        <Stat label="العملاء المحتملون" value={fmtNum(o.leads)} hint={`${o.booths} جناح · ${o.organizers} منظم`} />
      </div>

      <section className="card overflow-x-auto">
        <h2 className="border-b border-line p-4 font-heading text-lg font-bold">المنظمون</h2>
        <table className="table-x">
          <thead><tr><th>الجهة</th><th>الحالة</th><th></th></tr></thead>
          <tbody>
            {(orgs ?? []).map((g) => (
              <tr key={g.id}>
                <td className="font-medium">{g.name}</td>
                <td>{g.is_suspended ? <span className="badge">موقوف</span> : g.is_verified ? <span className="badge">موثّق</span> : <span className="badge-live">بانتظار التوثيق</span>}</td>
                <td className="flex flex-wrap gap-2">
                  <form action={setOrganizer.bind(null, g.id, { is_verified: !g.is_verified })}><button className="btn-ghost btn-sm">{g.is_verified ? "إلغاء التوثيق" : "توثيق"}</button></form>
                  <form action={setOrganizer.bind(null, g.id, { is_suspended: !g.is_suspended })}><button className="btn-ghost btn-sm">{g.is_suspended ? "رفع الإيقاف" : "إيقاف"}</button></form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="card overflow-x-auto">
        <h2 className="border-b border-line p-4 font-heading text-lg font-bold">العارضون المسجلون في المعارض ({stores?.length ?? 0})</h2>
        {(stores?.length ?? 0) === 0 ? <p className="p-4 text-sm text-muted">لم يسجل أي عارض بعد. يُسجَّل التاجر تلقائياً عند أول طلب مشاركة.</p> : (
          <table className="table-x">
            <thead><tr><th>المتجر</th><th>الأجنحة</th><th>تاريخ التسجيل</th><th>الحالة</th></tr></thead>
            <tbody>
              {(stores as unknown as { id: string; name: string; status: string; suspended_reason: string | null; created_at: string; booths: { count: number }[] }[]).map((st) => (
                <tr key={st.id}>
                  <td className="font-medium">{st.name}</td>
                  <td>{st.booths?.[0]?.count ?? 0}</td>
                  <td className="text-muted">{fmtDate(st.created_at)}</td>
                  <td>
                    <form action={setStoreStatus.bind(null, st.id)} className="flex flex-wrap items-center gap-2">
                      {st.status === "active" ? (
                        <>
                          <span className="badge">نشط</span>
                          <input type="hidden" name="status" value="suspended" />
                          <input name="reason" className="input w-40" placeholder="سبب الإيقاف" />
                          <button className="btn-ghost btn-sm">إيقاف</button>
                        </>
                      ) : (
                        <>
                          <span className="badge-live">موقوف</span>
                          {st.suspended_reason && <span className="text-xs text-muted">{st.suspended_reason}</span>}
                          <input type="hidden" name="status" value="active" />
                          <button className="btn-ghost btn-sm">إعادة التفعيل</button>
                        </>
                      )}
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="card overflow-x-auto">
        <h2 className="border-b border-line p-4 font-heading text-lg font-bold">المعارض</h2>
        <table className="table-x">
          <thead><tr><th>المعرض</th><th>المنظم</th><th>البداية</th><th>الحالة</th><th>مميز</th><th>تغيير الحالة</th></tr></thead>
          <tbody>
            {((ex ?? []) as (Exhibition & { organizers: { name: string } })[]).map((e) => (
              <tr key={e.id}>
                <td><Link href={`/organizer/e/${e.id}`} className="font-medium hover:text-primary">{e.title}</Link></td>
                <td className="text-muted">{e.organizers?.name}</td>
                <td className="text-muted">{fmtDate(e.starts_at, e.timezone)}</td>
                <td><StatusBadge status={e.status} /></td>
                <td><form action={setFeatured.bind(null, e.id, !e.is_featured)}><button className="text-sm">{e.is_featured ? "★" : "☆"}</button></form></td>
                <td>
                  <form action={forceStatus.bind(null, e.id)} className="flex gap-2">
                    <select name="status" defaultValue={e.status} className="input w-28">
                      {Object.entries(EXHIBITION_STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
                    <button className="btn-ghost btn-sm">تطبيق</button>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
