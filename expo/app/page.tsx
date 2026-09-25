import Link from "next/link";
import { expo } from "@/lib/supabase/server";
import { fmtDate, fmtNum } from "@/lib/format";
import type { Exhibition } from "@/lib/types";
import { ExhibitionCard } from "@/components/cards";
import { Countdown } from "@/components/Countdown";
import { Cover, EmptyState, LiveBadge, Logo, SectionHead } from "@/components/ui";

export const dynamic = "force-dynamic";

export default async function Home() {
  const db = await expo();
  const [{ data: upcoming }, { data: past }, { data: live }] = await Promise.all([
    db.from("exhibitions").select("*").in("status", ["live", "scheduled"])
      .order("is_featured", { ascending: false }).order("starts_at").limit(24),
    db.from("exhibitions").select("*").in("status", ["ended", "archived"]).order("ends_at", { ascending: false }).limit(6),
    db.from("live_streams").select("id, title, current_viewers, exhibition_id, exhibitions(slug, title), booths(name, logo_path)")
      .eq("status", "live").order("current_viewers", { ascending: false }).limit(8),
  ]);
  const list = (upcoming ?? []) as Exhibition[];
  const hero = list.find((e) => e.status === "live") ?? list[0];
  const rest = list.filter((e) => e.id !== hero?.id);

  return (
    <>
      {hero ? (
        <section className="relative overflow-hidden bg-ink text-bg">
          <div className="absolute inset-0 opacity-40"><Cover path={hero.cover_path} alt="" /></div>
          <div className="absolute inset-0 bg-gradient-to-l from-ink via-ink/85 to-ink/40" aria-hidden />
          <div className="container-x relative flex min-h-[440px] flex-col justify-center gap-6 py-14">
            <div className="flex items-center gap-3">
              {hero.status === "live" ? <LiveBadge label="مباشر الآن" /> : <span className="badge bg-white/10 text-bg">المعرض القادم</span>}
              <span className="text-sm text-white/70">{fmtDate(hero.starts_at, hero.timezone)}{hero.city ? ` · ${hero.city}` : ""}</span>
            </div>
            <h1 className="max-w-3xl text-4xl font-extrabold sm:text-5xl">{hero.title}</h1>
            {hero.description && <p className="max-w-2xl text-lg text-white/80 line-clamp-3">{hero.description}</p>}
            {hero.status === "scheduled" && <Countdown to={hero.starts_at} onDark />}
            <div className="flex flex-wrap gap-3">
              <Link href={`/e/${hero.slug}${hero.status === "live" ? "/lobby" : ""}`} className="btn-primary">
                {hero.status === "live" ? "ادخل المعرض" : "تفاصيل المعرض"}
              </Link>
            </div>
          </div>
        </section>
      ) : (
        <section className="container-x py-16">
          <h1 className="text-4xl font-extrabold">المعارض الافتراضية من Red Market</h1>
          <p className="mt-3 text-lg text-muted">تسوّق، تعرّف على العلامات التجارية، وشاهد البث المباشر من أي مكان.</p>
        </section>
      )}

      <div className="container-x flex flex-col gap-16 py-12">
        {(live?.length ?? 0) > 0 && (
          <section>
            <SectionHead title="مباشر الآن" />
            <div className="flex gap-4 overflow-x-auto pb-2">
              {live!.map((s) => {
                const ex = s.exhibitions as unknown as { slug: string; title: string } | null;
                const booth = s.booths as unknown as { name: string; logo_path: string | null } | null;
                return (
                  <Link key={s.id} href={`/e/${ex?.slug}/live/${s.id}`} className="card flex w-72 shrink-0 gap-3 p-4 hover:border-ink">
                    <Logo path={booth?.logo_path} name={booth?.name ?? s.title} size={48} />
                    <div className="min-w-0">
                      <LiveBadge />
                      <p className="mt-1 truncate font-semibold">{s.title}</p>
                      <p className="truncate text-xs text-muted">{booth?.name ?? ex?.title} · {fmtNum(s.current_viewers)} مشاهد</p>
                    </div>
                  </Link>
                );
              })}
            </div>
          </section>
        )}

        <section>
          <SectionHead title="المعارض القادمة" />
          {rest.length ? (
            <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{rest.map((e) => <ExhibitionCard key={e.id} e={e} />)}</div>
          ) : (
            <EmptyState title="لا توجد معارض أخرى مجدولة حالياً" body="تابع Red Market لتصلك مواعيد المعارض القادمة." />
          )}
        </section>

        {(past?.length ?? 0) > 0 && (
          <section>
            <SectionHead title="معارض سابقة" />
            <p className="-mt-3 mb-5 text-sm text-muted">تصفح الأجنحة وشاهد تسجيلات الجلسات.</p>
            <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{(past as Exhibition[]).map((e) => <ExhibitionCard key={e.id} e={e} />)}</div>
          </section>
        )}
      </div>
    </>
  );
}
