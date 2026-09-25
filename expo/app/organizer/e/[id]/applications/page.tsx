import { getOrganizedExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { BOOTH_TIER, fmtDate, timeAgo } from "@/lib/format";
import type { Hall } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { EmptyState } from "@/components/ui";
import { reviewApplication } from "../../../actions";

export default async function Applications({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; all?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  await getOrganizedExhibition(id);
  const db = await expo();
  let q = db.from("booth_applications").select("*, store(name, logo_url)").eq("exhibition_id", id).order("created_at");
  if (!sp.all) q = q.eq("status", "pending");
  const [{ data: apps }, { data: halls }, { data: booths }, { data: subs }] = await Promise.all([
    q, db.from("exhibition_halls").select("*").eq("exhibition_id", id).order("sort_order"),
    db.from("booths").select("hall_id, map_slot").eq("exhibition_id", id),
    db.rpc("exhibition_subscription_check", { p_exhibition: id }),
  ]);
  const subOf = (storeId: string) =>
    ((subs ?? []) as { store_id: string; status: string; expires_at: string | null }[]).find((x) => x.store_id === storeId);
  const SUB: Record<string, string> = { ok: "الاشتراك يغطي المعرض", not_covering: "الاشتراك ينتهي قبل نهاية المعرض", expired: "الاشتراك منتهٍ", none: "غير مشترك" };
  const taken = new Set((booths ?? []).map((b) => `${b.hall_id}:${b.map_slot}`));
  const hallList = (halls ?? []) as Hall[];
  const STATUS: Record<string, string> = { pending: "قيد المراجعة", approved: "مقبول", rejected: "مرفوض", withdrawn: "مسحوب" };

  return (
    <div className="flex flex-col gap-4">
      <Flash error={sp.error} />
      <div className="flex gap-2">
        <a href="?" className={!sp.all ? "btn-ink btn-sm" : "btn-ghost btn-sm"}>المعلقة</a>
        <a href="?all=1" className={sp.all ? "btn-ink btn-sm" : "btn-ghost btn-sm"}>الكل</a>
      </div>
      {(apps?.length ?? 0) === 0 ? <EmptyState title="لا توجد طلبات" /> : apps!.map((a) => (
        <article key={a.id} className="card flex flex-col gap-4 p-5">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="me-auto font-heading text-lg font-bold">{(a.store as { name: string } | null)?.name ?? "متجر"}</h2>
            <span className="badge">طلب: {BOOTH_TIER[a.requested_tier]}</span>
            <span className="badge">{STATUS[a.status]}</span>
            {(() => { const sub = subOf(a.store_id); return sub && (
              <span className={sub.status === "ok" ? "badge" : "badge-live"}>
                {SUB[sub.status]}{sub.expires_at ? ` · حتى ${fmtDate(sub.expires_at)}` : ""}
              </span>); })()}
            <span className="text-xs text-muted">{timeAgo(a.created_at)}</span>
          </div>
          {a.message && <p className="rounded-[10px] bg-bg p-3 text-sm">{a.message}</p>}
          {a.status === "pending" && (
            <div className="grid gap-4 lg:grid-cols-2">
              <form action={reviewApplication.bind(null, id, a.id, true)} className="flex flex-wrap items-end gap-2">
                <div><label className="label">القاعة</label>
                  <select name="hall_id" className="input w-40">{hallList.map((h) => <option key={h.id} value={h.id}>{h.name}</option>)}</select></div>
                <div><label className="label">الموقع</label><input name="map_slot" className="input w-24" placeholder="A-01" pattern="[A-Za-z]-?\d{1,2}" dir="ltr" /></div>
                <div><label className="label">النوع</label>
                  <select name="tier" className="input w-28" defaultValue={a.requested_tier}>{Object.entries(BOOTH_TIER).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></div>
                <button className="btn-primary">قبول</button>
              </form>
              <form action={reviewApplication.bind(null, id, a.id, false)} className="flex items-end gap-2">
                <div className="flex-1"><label className="label">سبب الرفض (يصل للتاجر)</label><input name="note" className="input" /></div>
                <button className="btn-ghost">رفض</button>
              </form>
            </div>
          )}
        </article>
      ))}
      {taken.size > 0 && <p className="text-xs text-muted">المواقع المحجوزة: {[...taken].map((t) => t.split(":")[1]).filter((s) => s !== "null").join("، ")}</p>}
    </div>
  );
}
