import Link from "next/link";
import { notFound } from "next/navigation";
import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtDateTime, LEAD_SOURCE, LEAD_STATUS, timeAgo } from "@/lib/format";
import type { Lead } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { ChatPanel } from "@/components/client/ChatPanel";
import { addNote, deleteNote, togglePinNote, updateLead } from "../../../../actions";

const ACT: Record<string, string> = { touch: "تفاعل", status_change: "تغيير الحالة", assigned: "إسناد", note_added: "ملاحظة", exported: "تصدير" };

export default async function LeadPage({ params, searchParams }: {
  params: Promise<{ id: string; leadId: string }>; searchParams: Promise<{ error?: string }>;
}) {
  const { id, leadId } = await params;
  const sp = await searchParams;
  const b = await getStaffBooth(id);
  const db = await expo();
  const [{ data: lead }, { data: notes }, { data: acts }, { data: team }] = await Promise.all([
    db.from("exhibition_leads").select("*").eq("id", leadId).eq("booth_id", id).maybeSingle(),
    db.from("lead_notes").select("*").eq("lead_id", leadId).order("is_pinned", { ascending: false }).order("created_at", { ascending: false }),
    db.from("lead_activities").select("*").eq("lead_id", leadId).order("created_at", { ascending: false }).limit(50),
    db.rpc("booth_team", { p_booth: id }),
  ]);
  if (!lead) notFound();
  const l = lead as Lead;
  const members = (team ?? []) as { user_id: string; full_name: string | null; email: string }[];
  const nameOf = (uid: string | null) => members.find((m) => m.user_id === uid)?.full_name ?? members.find((m) => m.user_id === uid)?.email ?? "—";

  return (
    <div className="flex flex-col gap-5">
      <Link href={`/merchant/booths/${id}/leads`} className="text-sm text-muted">← العملاء المحتملون</Link>
      <Flash error={sp.error} />
      <div className="grid gap-5 xl:grid-cols-[1fr_360px]">
        <div className="flex flex-col gap-5">
          <section className="card p-5">
            <div className="flex flex-wrap items-start gap-3">
              <div className="flex-1">
                <h2 className="font-heading text-2xl font-extrabold">{l.full_name}</h2>
                {l.company && <p className="text-muted">{l.company}</p>}
              </div>
              <span className="badge">{LEAD_SOURCE[l.source]}</span>
              <span className="badge">تفاعل {l.score}</span>
            </div>
            <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
              <div><dt className="text-muted">الجوال</dt><dd dir="ltr" className="text-right">{l.phone ? <a href={`tel:${l.phone}`} className="hover:text-primary">{l.phone}</a> : "—"}</dd></div>
              <div><dt className="text-muted">البريد</dt><dd dir="ltr" className="text-right">{l.email ? <a href={`mailto:${l.email}`} className="hover:text-primary">{l.email}</a> : "—"}</dd></div>
              <div><dt className="text-muted">أول تواصل</dt><dd>{fmtDateTime(l.created_at)}</dd></div>
              <div><dt className="text-muted">الموافقة على مشاركة البيانات</dt><dd>{fmtDateTime(l.consent_at)}</dd></div>
            </dl>
            {l.message && <p className="mt-4 whitespace-pre-line rounded-[10px] bg-bg p-3 text-sm">{l.message}</p>}
            {l.phone && (
              <a href={`https://wa.me/${l.phone.replace(/\D/g, "").replace(/^0/, "966")}`} target="_blank" rel="noopener" className="btn-ghost btn-sm mt-4">تواصل عبر واتساب</a>
            )}
          </section>

          <section className="card p-5">
            <h3 className="mb-3 font-heading text-lg font-bold">الملاحظات</h3>
            <form action={addNote.bind(null, id, leadId)} className="mb-4 flex flex-col gap-2">
              <textarea name="body" rows={3} className="input" required maxLength={5000} placeholder="اكتب ملاحظة داخلية (لا يراها العميل)" />
              <button className="btn-primary btn-sm self-start">إضافة ملاحظة</button>
            </form>
            <ul className="flex flex-col gap-3">
              {(notes ?? []).map((n) => (
                <li key={n.id} className={`rounded-[10px] border p-3 text-sm ${n.is_pinned ? "border-primary/40 bg-tint/40" : "border-line"}`}>
                  <p className="whitespace-pre-line">{n.body}</p>
                  <div className="mt-2 flex gap-3 text-xs text-muted">
                    <span>{nameOf(n.author_id)} · {timeAgo(n.created_at)}</span>
                    {n.author_id === b.userId && (
                      <>
                        <form action={togglePinNote.bind(null, id, leadId, n.id, !n.is_pinned)}><button className="hover:text-ink">{n.is_pinned ? "إلغاء التثبيت" : "تثبيت"}</button></form>
                        <form action={deleteNote.bind(null, id, leadId, n.id)}><button className="hover:text-primary">حذف</button></form>
                      </>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          </section>

          {l.chat_id && (
            <section className="card flex h-[420px] flex-col">
              <h3 className="border-b border-line p-4 font-heading text-lg font-bold">المحادثة</h3>
              <div className="min-h-0 flex-1"><ChatPanel chatId={l.chat_id} meId={b.userId} /></div>
            </section>
          )}
        </div>

        <aside className="flex flex-col gap-5">
          <form action={updateLead.bind(null, id, leadId)} className="card flex flex-col gap-3 p-5">
            <label className="label" htmlFor="ls">المرحلة</label>
            <select id="ls" name="status" className="input" defaultValue={l.status}>
              {Object.entries(LEAD_STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </select>
            {b.role !== "agent" && (
              <>
                <label className="label" htmlFor="la">مسند إلى</label>
                <select id="la" name="assigned_to" className="input" defaultValue={l.assigned_to ?? ""}>
                  <option value="">غير مسند</option>
                  {members.map((m) => <option key={m.user_id} value={m.user_id}>{m.full_name ?? m.email}</option>)}
                </select>
              </>
            )}
            <button className="btn-primary btn-sm">حفظ</button>
          </form>
          <section className="card p-5">
            <h3 className="mb-3 font-heading text-lg font-bold">السجل</h3>
            <ol className="flex flex-col gap-3 border-s-2 border-line ps-4 text-sm">
              {(acts ?? []).map((a) => (
                <li key={a.id}>
                  <p className="font-medium">{ACT[a.type] ?? a.type}
                    {a.type === "status_change" && `: ${LEAD_STATUS[a.data.from]} ← ${LEAD_STATUS[a.data.to]}`}
                    {a.type === "touch" && a.data.source && `: ${LEAD_SOURCE[a.data.source]}`}
                    {a.type === "assigned" && `: ${nameOf(a.data.to)}`}</p>
                  <p className="text-xs text-muted">{timeAgo(a.created_at)}</p>
                </li>
              ))}
            </ol>
          </section>
        </aside>
      </div>
    </div>
  );
}
