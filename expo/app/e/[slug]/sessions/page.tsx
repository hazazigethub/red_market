import Link from "next/link";
import { getExhibition } from "@/lib/queries";
import { expo, getUser } from "@/lib/supabase/server";
import { dayKey, fmtDay, fmtTime, SESSION_TYPE } from "@/lib/format";
import { thumb } from "@/lib/storage";
import type { Session } from "@/lib/types";
import { EmptyState, LiveBadge } from "@/components/ui";
import { RegisterButton } from "@/components/client/engage";

export const metadata = { title: "الجلسات" };

type Row = Session & {
  session_speakers: { role: string; speakers: { id: string; full_name: string; photo_path: string | null; job_title: string | null } }[];
  live_streams: { id: string; status: string; recording_path: string | null }[];
};

export default async function Sessions({ params, searchParams }: {
  params: Promise<{ slug: string }>; searchParams: Promise<{ day?: string }>;
}) {
  const { slug } = await params;
  const sp = await searchParams;
  const e = await getExhibition(slug);
  const user = await getUser();
  const db = await expo();
  const [{ data }, { data: regs }] = await Promise.all([
    db.from("exhibition_sessions")
      .select("*, session_speakers(role, speakers(id, full_name, photo_path, job_title)), live_streams(id, status, recording_path)")
      .eq("exhibition_id", e.id).neq("status", "cancelled").order("starts_at"),
    user ? db.from("session_registrations").select("session_id").eq("user_id", user.id) : Promise.resolve({ data: [] }),
  ]);
  const rows = (data ?? []) as Row[];
  const mine = new Set((regs ?? []).map((r: { session_id: string }) => r.session_id));
  const days = [...new Set(rows.map((r) => dayKey(r.starts_at, e.timezone)))];
  const day = days.includes(sp.day ?? "") ? sp.day! : (days.find((d) => d >= dayKey(new Date().toISOString(), e.timezone)) ?? days[0]);
  const list = rows.filter((r) => dayKey(r.starts_at, e.timezone) === day);

  return (
    <div className="container-x py-8">
      <h1 className="section-title mb-5">الجلسات</h1>
      {rows.length === 0 ? <EmptyState title="لم تُعلن الجلسات بعد" /> : (
        <>
          <div className="mb-6 flex gap-2 overflow-x-auto">
            {days.map((d) => {
              const iso = rows.find((r) => dayKey(r.starts_at, e.timezone) === d)!.starts_at;
              return <Link key={d} href={`?day=${d}`} scroll={false} className={d === day ? "btn-ink btn-sm" : "btn-ghost btn-sm"}>{fmtDay(iso, e.timezone)}</Link>;
            })}
          </div>
          <ol className="flex flex-col gap-4">
            {list.map((s) => {
              const stream = s.live_streams?.[0];
              const full = s.capacity != null && s.registered_count >= s.capacity;
              return (
                <li key={s.id} id={s.id} className="card flex flex-col gap-4 p-5 sm:flex-row">
                  <div className="w-28 shrink-0">
                    <p className="font-heading text-xl font-extrabold tabular-nums">{fmtTime(s.starts_at, e.timezone)}</p>
                    <p className="text-xs text-muted">حتى {fmtTime(s.ends_at, e.timezone)}</p>
                  </div>
                  <div className="flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="badge">{SESSION_TYPE[s.type]}</span>
                      {s.status === "live" && <LiveBadge />}
                      {s.capacity && <span className="text-xs text-muted">{s.registered_count}/{s.capacity} مقعد</span>}
                    </div>
                    <h2 className="mt-2 font-heading text-lg font-bold">{s.title}</h2>
                    {s.description && <p className="mt-1 text-sm text-muted line-clamp-3">{s.description}</p>}
                    {s.session_speakers.length > 0 && (
                      <div className="mt-3 flex flex-wrap gap-3">
                        {s.session_speakers.map(({ speakers: sp, role }) => (
                          <Link key={sp.id} href={`/e/${slug}/speakers#${sp.id}`} className="flex items-center gap-2 text-sm hover:text-primary">
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            {sp.photo_path ? <img src={thumb(sp.photo_path, 80)!} alt="" className="h-8 w-8 rounded-full object-cover" />
                              : <span className="grid h-8 w-8 place-items-center rounded-full bg-ink text-xs text-bg">{sp.full_name[0]}</span>}
                            <span>{sp.full_name}{role === "moderator" ? " (مدير الجلسة)" : ""}</span>
                          </Link>
                        ))}
                      </div>
                    )}
                  </div>
                  <div className="flex shrink-0 flex-col items-start gap-2 sm:items-end">
                    {stream && (stream.status === "live" || stream.recording_path) && (
                      <Link href={`/e/${slug}/live/${stream.id}`} className="btn-primary btn-sm">{stream.status === "live" ? "شاهد مباشرة" : "شاهد التسجيل"}</Link>
                    )}
                    {s.status === "scheduled" && <RegisterButton sessionId={s.id} initial={mine.has(s.id)} full={full} signedIn={!!user} />}
                  </div>
                </li>
              );
            })}
          </ol>
        </>
      )}
    </div>
  );
}
