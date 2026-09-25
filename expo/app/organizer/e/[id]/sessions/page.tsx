import Link from "next/link";
import { getOrganizedExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtDateTime, isoToRiyadhLocal, SESSION_TYPE } from "@/lib/format";
import type { Hall, Session, Speaker } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { LiveBadge } from "@/components/ui";
import { cancelSession, createSessionStream, saveSession } from "../../../actions";

type Row = Session & { session_speakers: { speaker_id: string; role: string }[]; live_streams: { id: string; status: string }[] };

function SessionForm({ exId, s, speakers, halls }: { exId: string; s?: Row; speakers: Speaker[]; halls: Hall[] }) {
  const chosen = new Map((s?.session_speakers ?? []).map((x) => [x.speaker_id, x.role]));
  return (
    <form action={saveSession.bind(null, exId, s?.id ?? null)} className="flex flex-col gap-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="sm:col-span-2"><label className="label">العنوان</label><input name="title" className="input" required defaultValue={s?.title} /></div>
        <div><label className="label">النوع</label><select name="type" className="input" defaultValue={s?.type ?? "talk"}>
          {Object.entries(SESSION_TYPE).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></div>
        <div><label className="label">القاعة</label><select name="hall_id" className="input" defaultValue={s?.hall_id ?? ""}>
          <option value="">—</option>{halls.map((h) => <option key={h.id} value={h.id}>{h.name}</option>)}</select></div>
        <div><label className="label">البداية</label><input name="starts_at" type="datetime-local" className="input" required defaultValue={s ? isoToRiyadhLocal(s.starts_at) : ""} /></div>
        <div><label className="label">النهاية</label><input name="ends_at" type="datetime-local" className="input" required defaultValue={s ? isoToRiyadhLocal(s.ends_at) : ""} /></div>
        <div><label className="label">السعة (اختياري)</label><input name="capacity" type="number" min={1} className="input" defaultValue={s?.capacity ?? ""} /></div>
        <div className="sm:col-span-2"><label className="label">الوصف</label><textarea name="description" rows={3} className="input" defaultValue={s?.description ?? ""} /></div>
      </div>
      {speakers.length > 0 && (
        <fieldset><legend className="label">المتحدثون</legend>
          <div className="grid gap-2 sm:grid-cols-2">
            {speakers.map((sp) => (
              <div key={sp.id} className="flex items-center gap-3 text-sm">
                <label className="flex flex-1 items-center gap-2"><input type="checkbox" name="speaker_ids" value={sp.id} defaultChecked={chosen.has(sp.id)} className="h-4 w-4 accent-[#C21815]" />{sp.full_name}</label>
                <label className="flex items-center gap-1 text-xs text-muted"><input type="checkbox" name={`moderator_${sp.id}`} defaultChecked={chosen.get(sp.id) === "moderator"} />مدير الجلسة</label>
              </div>
            ))}
          </div>
        </fieldset>
      )}
      <button className="btn-primary self-start">{s ? "حفظ" : "إضافة الجلسة"}</button>
    </form>
  );
}

export default async function OrgSessions({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; ok?: string; edit?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  const e = await getOrganizedExhibition(id);
  const db = await expo();
  const [{ data }, { data: speakers }, { data: halls }] = await Promise.all([
    db.from("exhibition_sessions").select("*, session_speakers(speaker_id, role), live_streams(id, status)").eq("exhibition_id", id).order("starts_at"),
    db.from("speakers").select("*").eq("exhibition_id", id).order("sort_order"),
    db.from("exhibition_halls").select("*").eq("exhibition_id", id).order("sort_order"),
  ]);
  const rows = (data ?? []) as Row[];
  const editing = rows.find((r) => r.id === sp.edit);
  return (
    <div className="flex flex-col gap-6">
      <Flash error={sp.error} ok={sp.ok ? "تم حفظ الجلسة." : undefined} />
      <section className="card p-5">
        <h2 className="mb-4 font-heading text-lg font-bold">{editing ? "تعديل جلسة" : "جلسة جديدة"}</h2>
        <SessionForm key={editing?.id ?? "new"} exId={id} s={editing} speakers={(speakers ?? []) as Speaker[]} halls={(halls ?? []) as Hall[]} />
      </section>
      <ul className="card divide-y divide-line">
        {rows.length === 0 && <li className="p-4 text-sm text-muted">لا توجد جلسات.</li>}
        {rows.map((s) => {
          const stream = s.live_streams?.[0];
          return (
            <li key={s.id} className="flex flex-wrap items-center gap-3 p-4">
              <div className="min-w-0 flex-1">
                <p className="font-semibold">{s.title} {s.status === "cancelled" && <span className="badge">ملغاة</span>}</p>
                <p className="text-xs text-muted">{SESSION_TYPE[s.type]} · {fmtDateTime(s.starts_at, e.timezone)} · {s.registered_count} مسجل · {s.session_speakers.length} متحدث</p>
              </div>
              {stream?.status === "live" && <LiveBadge />}
              <Link href={`?edit=${s.id}`} className="btn-ghost btn-sm">تعديل</Link>
              {s.status !== "cancelled" && (stream
                ? <Link href={`/organizer/e/${id}/studio/${stream.id}`} className="btn-primary btn-sm">الاستوديو</Link>
                : <form action={createSessionStream.bind(null, id, s.id, s.title)}><button className="btn-primary btn-sm">إنشاء بث</button></form>)}
              {s.status === "scheduled" && <form action={cancelSession.bind(null, id, s.id)}><button className="text-xs text-muted hover:text-primary">إلغاء</button></form>}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
