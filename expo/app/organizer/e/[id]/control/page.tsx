import Link from "next/link";
import { getOrganizedExhibition } from "@/lib/queries";
import { expo, getUser } from "@/lib/supabase/server";
import { fmtDateTime, fmtNum } from "@/lib/format";
import { Flash } from "@/components/Flash";
import { LiveBadge } from "@/components/ui";
import { ModeratedChat } from "@/components/client/ModeratedChat";
import { announce, banUser, unban } from "../../../actions";

export default async function Control({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; ok?: string; chat?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  const e = await getOrganizedExhibition(id);
  const user = (await getUser())!;
  const db = await expo();
  const [{ data: streams }, { data: bans }] = await Promise.all([
    db.from("live_streams").select("id, title, status, current_viewers, peak_viewers, booth_id, session_id, exhibition_chats(id)")
      .eq("exhibition_id", id).in("status", ["live", "scheduled"]).order("status"),
    db.from("exhibition_bans").select("*").eq("exhibition_id", id).order("created_at", { ascending: false }),
  ]);
  type S = { id: string; title: string; status: string; current_viewers: number; peak_viewers: number; exhibition_chats: { id: string }[] };
  const list = (streams ?? []) as unknown as S[];
  const activeChat = sp.chat ?? list.find((s) => s.status === "live")?.exhibition_chats?.[0]?.id;
  const live = e.status === "live" || e.status === "scheduled";

  return (
    <div className="flex flex-col gap-6">
      <Flash error={sp.error} ok={sp.ok ? "تم إرسال الإعلان لكل الزوار المتصلين." : undefined} />
      <form action={announce.bind(null, id)} className="card flex flex-wrap items-end gap-3 p-5">
        <div className="min-w-60 flex-1"><label className="label" htmlFor="am">إعلان فوري لكل الزوار</label>
          <input id="am" name="message" className="input" required minLength={2} maxLength={280} placeholder="تبدأ الكلمة الرئيسية بعد 5 دقائق في القاعة A" disabled={!live} /></div>
        <button className="btn-primary" disabled={!live}>إرسال</button>
      </form>
      <div className="grid gap-6 xl:grid-cols-[1fr_380px]">
        <section className="card">
          <h2 className="border-b border-line p-4 font-heading text-lg font-bold">البثوث</h2>
          <ul className="divide-y divide-line">
            {list.length === 0 && <li className="p-4 text-sm text-muted">لا توجد بثوث نشطة أو مجدولة.</li>}
            {list.map((s) => (
              <li key={s.id} className="flex flex-wrap items-center gap-3 p-4">
                {s.status === "live" ? <LiveBadge /> : <span className="badge">مجدول</span>}
                <span className="flex-1 font-medium">{s.title}</span>
                <span className="text-sm text-muted">{fmtNum(s.current_viewers)} الآن · ذروة {fmtNum(s.peak_viewers)}</span>
                <Link href={`/e/${e.slug}/live/${s.id}`} target="_blank" className="btn-ghost btn-sm">مشاهدة</Link>
                {s.exhibition_chats?.[0] && <Link href={`?chat=${s.exhibition_chats[0].id}`} className="btn-ghost btn-sm">إشراف الدردشة</Link>}
              </li>
            ))}
          </ul>
        </section>
        <section className="card flex h-[60vh] min-h-96 flex-col">
          <h2 className="border-b border-line p-4 font-heading text-lg font-bold">إشراف الدردشة</h2>
          <div className="min-h-0 flex-1">
            {activeChat ? <ModeratedChat chatId={activeChat} meId={user.id} ban={banUser.bind(null, id)} />
              : <p className="p-4 text-sm text-muted">اختر بثاً للإشراف على دردشته.</p>}
          </div>
        </section>
      </div>
      <section className="card overflow-x-auto">
        <h2 className="border-b border-line p-4 font-heading text-lg font-bold">المستخدمون المحظورون</h2>
        {(bans?.length ?? 0) === 0 ? <p className="p-4 text-sm text-muted">لا يوجد.</p> : (
          <table className="table-x"><thead><tr><th>المستخدم</th><th>ينتهي</th><th></th></tr></thead>
            <tbody>{bans!.map((b) => (
              <tr key={b.user_id}><td className="font-mono text-xs" dir="ltr">{b.user_id.slice(0, 8)}…</td>
                <td>{b.expires_at ? fmtDateTime(b.expires_at) : "دائم"}</td>
                <td><form action={unban.bind(null, id, b.user_id)}><button className="text-sm text-muted hover:text-primary">رفع الحظر</button></form></td></tr>
            ))}</tbody></table>
        )}
      </section>
    </div>
  );
}
