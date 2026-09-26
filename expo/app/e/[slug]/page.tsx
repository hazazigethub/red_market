import Link from "next/link";
import { getExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtDate, fmtDateTime, fmtTime, SESSION_TYPE } from "@/lib/format";
import type { Booth, Session, Sponsor } from "@/lib/types";
import { BoothCard, SponsorWall } from "@/components/cards";
import { Countdown } from "@/components/Countdown";
import { Cover, LiveBadge, Logo, SectionHead } from "@/components/ui";

export default async function Landing({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const e = await getExhibition(slug);
  const db = await expo();
  const [{ data: booths }, { data: sessions }, { data: sponsors }, { data: streams }, { count: boothCount }] = await Promise.all([
    db.from("booths").select("*").eq("exhibition_id", e.id).eq("status", "published")
      .order("tier", { ascending: false }).order("views_count", { ascending: false }).limit(8),
    db.from("exhibition_sessions").select("*").eq("exhibition_id", e.id).neq("status", "cancelled")
      .gte("ends_at", new Date().toISOString()).order("starts_at").limit(5),
    db.from("sponsors").select("*").eq("exhibition_id", e.id).order("sort_order"),
    db.from("live_streams").select("id, title, booth_id, current_viewers").eq("exhibition_id", e.id).eq("status", "live").limit(6),
    db.from("booths").select("id", { count: "exact", head: true }).eq("exhibition_id", e.id).eq("status", "published"),
  ]);
  const liveIds = new Set((streams ?? []).map((s) => s.booth_id));
  const isOver = e.status === "ended" || e.status === "archived";

  return (
    <>
      <section className="relative bg-ink text-bg">
        <div className="absolute inset-0 opacity-45"><Cover path={e.cover_path} alt="" /></div>
        <div className="absolute inset-0 bg-gradient-to-t from-ink via-ink/70 to-ink/20" aria-hidden />
        <div className="container-x relative flex min-h-[420px] flex-col justify-end gap-5 pb-10 pt-24">
          <div className="flex items-center gap-4">
            <Logo path={e.logo_path} name={e.title} size={72} className="border-white/20" />
            <div>
              {e.status === "live" && <LiveBadge label="المعرض مباشر الآن" />}
              {isOver && <span className="badge bg-white/10 text-bg">انتهى المعرض · المحتوى متاح للتصفح</span>}
              <h1 className="mt-2 text-3xl font-extrabold sm:text-5xl">{e.title}</h1>
            </div>
          </div>
          <p className="text-white/80">
            {fmtDate(e.starts_at, e.timezone)} — {fmtDate(e.ends_at, e.timezone)}
            {e.location_type !== "virtual" && e.venue ? ` · ${e.venue}` : " · افتراضي"}{e.city ? `، ${e.city}` : ""}
          </p>
          {e.status === "scheduled" && <Countdown to={e.starts_at} onDark />}
          <div className="flex flex-wrap gap-3">
            <Link href={`/e/${slug}/lobby`} className="btn-primary">{e.status === "live" ? "ادخل المعرض الآن" : "تصفح الأجنحة"}</Link>
            {(sessions?.length ?? 0) > 0 && (
              <Link href={`/e/${slug}/sessions`} className="btn border border-white/30 text-bg hover:border-white">الجلسات</Link>
            )}
          </div>
          <form action={`/e/${slug}/search`} className="mt-2 max-w-xl">
            <label htmlFor="q" className="sr-only">ابحث في المعرض</label>
            <input id="q" name="q" className="input border-white/20 bg-white/95" placeholder="ابحث عن عارض، منتج، جلسة أو متحدث" />
          </form>
        </div>
      </section>

      <div className="container-x flex flex-col gap-14 py-12">
        {e.description && (
          <section className="grid gap-8 lg:grid-cols-3">
            <div className="lg:col-span-2">
              <h2 className="section-title mb-3">عن المعرض</h2>
              <p className="whitespace-pre-line text-muted">{e.description}</p>
            </div>
            <div className="card grid grid-cols-2 gap-4 p-5 text-center">
              <div><p className="font-heading text-3xl font-extrabold">{boothCount ?? 0}</p><p className="text-sm text-muted">عارض</p></div>
              <div><p className="font-heading text-3xl font-extrabold">{sessions?.length ?? 0}+</p><p className="text-sm text-muted">جلسة</p></div>
            </div>
          </section>
        )}

        {(streams?.length ?? 0) > 0 && (
          <section>
            <SectionHead title="يبث الآن" />
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {streams!.map((s) => (
                <Link key={s.id} href={`/e/${slug}/live/${s.id}`} className="card flex items-center gap-3 p-4 hover:border-ink">
                  <LiveBadge /><span className="truncate font-semibold">{s.title}</span>
                </Link>
              ))}
            </div>
          </section>
        )}

        {(booths?.length ?? 0) > 0 && (
          <section>
            <SectionHead title="أجنحة مميزة" href={`/e/${slug}/lobby`} />
            <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
              {(booths as Booth[]).map((b) => <BoothCard key={b.id} b={b} slug={slug} live={liveIds.has(b.id)} />)}
            </div>
          </section>
        )}

        {(sessions?.length ?? 0) > 0 && (
          <section>
            <SectionHead title="الجلسات القادمة" href={`/e/${slug}/sessions`} linkLabel="كل الجلسات" />
            <ol className="card divide-y divide-line">
              {(sessions as Session[]).map((s) => (
                <li key={s.id} className="flex flex-col gap-1 p-4 sm:flex-row sm:items-center sm:gap-6">
                  <span className="w-40 shrink-0 text-sm font-semibold tabular-nums">{fmtTime(s.starts_at, e.timezone)}</span>
                  <div className="flex-1">
                    <p className="font-semibold">{s.title}</p>
                    <p className="text-xs text-muted">{SESSION_TYPE[s.type]} · {fmtDateTime(s.starts_at, e.timezone)}</p>
                  </div>
                  {s.status === "live" && <LiveBadge />}
                </li>
              ))}
            </ol>
          </section>
        )}

        {(sponsors?.length ?? 0) > 0 && (
          <section>
            <SectionHead title="الرعاة" href={`/e/${slug}/sponsors`} />
            <SponsorWall sponsors={sponsors as Sponsor[]} exhibitionSlug={slug} compact />
          </section>
        )}
      </div>
    </>
  );
}
