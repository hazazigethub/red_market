import Link from "next/link";
import { getExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtTime } from "@/lib/format";
import type { Booth, Hall, Session } from "@/lib/types";
import { BoothCard } from "@/components/cards";
import { HallMap } from "@/components/HallMap";
import { EmptyState, LiveBadge } from "@/components/ui";
import { Tracker } from "@/components/client/Tracker";

export const metadata = { title: "اللوبي" };

export default async function Lobby({ params, searchParams }: {
  params: Promise<{ slug: string }>; searchParams: Promise<{ hall?: string; view?: string; q?: string }>;
}) {
  const { slug } = await params;
  const sp = await searchParams;
  const e = await getExhibition(slug);
  const db = await expo();
  const [{ data: halls }, { data: booths }, { data: streams }, { data: sessions }] = await Promise.all([
    db.from("exhibition_halls").select("*").eq("exhibition_id", e.id).order("sort_order"),
    db.from("booths").select("*").eq("exhibition_id", e.id).eq("status", "published")
      .order("tier", { ascending: false }).order("name"),
    db.from("live_streams").select("id, title, booth_id").eq("exhibition_id", e.id).eq("status", "live"),
    db.from("exhibition_sessions").select("*").eq("exhibition_id", e.id).in("status", ["scheduled", "live"])
      .gte("ends_at", new Date().toISOString()).order("starts_at").limit(4),
  ]);
  const hallList = (halls ?? []) as Hall[];
  const hall = hallList.find((h) => h.id === sp.hall) ?? hallList[0];
  const view = sp.view === "list" || !hall ? "list" : "map";
  const q = sp.q?.trim().toLowerCase();
  let list = (booths ?? []) as Booth[];
  if (hall && view === "map") list = list.filter((b) => b.hall_id === hall.id);
  if (q) list = list.filter((b) => `${b.name} ${b.tagline ?? ""}`.toLowerCase().includes(q));
  const liveIds = new Set((streams ?? []).map((s) => s.booth_id as string));
  const qs = (o: Record<string, string | undefined>) =>
    "?" + new URLSearchParams(Object.entries({ hall: hall?.id, view, q: sp.q, ...o }).filter(([, v]) => v) as [string, string][]);

  return (
    <div className="container-x grid gap-8 py-8 lg:grid-cols-[1fr_300px]">
      <Tracker exhibition_id={e.id} event="lobby_view" />
      <div className="flex min-w-0 flex-col gap-5">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="section-title me-auto">الأجنحة</h1>
          <form className="w-full sm:w-64" action="">
            {hall && <input type="hidden" name="hall" value={hall.id} />}
            <input type="hidden" name="view" value={view} />
            <label className="sr-only" htmlFor="lq">تصفية الأجنحة</label>
            <input id="lq" name="q" defaultValue={sp.q} className="input" placeholder="تصفية بالاسم" />
          </form>
          {hallList.length > 0 && (
            <div className="flex rounded-[10px] border border-line bg-surface p-1 text-sm">
              <Link href={qs({ view: "map" })} className={`rounded-lg px-3 py-1.5 ${view === "map" ? "bg-ink text-bg" : ""}`}>الخريطة</Link>
              <Link href={qs({ view: "list" })} className={`rounded-lg px-3 py-1.5 ${view === "list" ? "bg-ink text-bg" : ""}`}>القائمة</Link>
            </div>
          )}
        </div>

        {view === "map" && hallList.length > 1 && (
          <div className="flex gap-2 overflow-x-auto">
            {hallList.map((h) => (
              <Link key={h.id} href={qs({ hall: h.id })} className={h.id === hall?.id ? "btn-ink btn-sm" : "btn-ghost btn-sm"}>{h.name}</Link>
            ))}
          </div>
        )}

        {view === "map" && hall ? (
          <div className="card p-4">
            <HallMap hall={hall} booths={list} slug={slug} liveBoothIds={liveIds} />
            <p className="mt-3 text-xs text-muted">الأجنحة المحددة بالأحمر للرعاة، والنقطة الحمراء تعني أن الجناح يبث الآن.</p>
          </div>
        ) : list.length ? (
          <div className="grid grid-cols-2 gap-4 md:grid-cols-3">
            {list.map((b) => <BoothCard key={b.id} b={b} slug={slug} live={liveIds.has(b.id)} />)}
          </div>
        ) : (
          <EmptyState title="لا توجد أجنحة مطابقة" body={e.status === "scheduled" ? "العارضون يجهزون أجنحتهم، عد قريباً." : undefined} />
        )}
      </div>

      <aside className="flex flex-col gap-5">
        <div className="card p-5">
          <h2 className="mb-3 font-heading text-lg font-bold">مباشر الآن</h2>
          {(streams?.length ?? 0) === 0 ? <p className="text-sm text-muted">لا يوجد بث حالياً.</p> : (
            <ul className="flex flex-col gap-2">
              {streams!.map((s) => (
                <li key={s.id}><Link href={`/e/${slug}/live/${s.id}`} className="flex items-center gap-2 text-sm hover:text-primary"><LiveBadge /><span className="truncate">{s.title}</span></Link></li>
              ))}
            </ul>
          )}
        </div>
        <div className="card p-5">
          <h2 className="mb-3 font-heading text-lg font-bold">التالي في الأجندة</h2>
          {(sessions?.length ?? 0) === 0 ? <p className="text-sm text-muted">لا توجد جلسات قادمة.</p> : (
            <ul className="flex flex-col gap-3">
              {(sessions as Session[]).map((s) => (
                <li key={s.id} className="text-sm">
                  <span className="font-semibold tabular-nums">{fmtTime(s.starts_at, e.timezone)}</span>
                  <p className="text-muted">{s.title}</p>
                </li>
              ))}
            </ul>
          )}
          <Link href={`/e/${slug}/sessions`} className="mt-3 inline-block text-sm font-semibold text-primary">الأجندة كاملة</Link>
        </div>
      </aside>
    </div>
  );
}
