import Link from "next/link";
import { BOOTH_TIER, fmtDate, SPONSOR_TIER } from "@/lib/format";
import { thumb } from "@/lib/storage";
import type { Booth, Exhibition, Sponsor } from "@/lib/types";
import { Cover, LiveBadge, Logo, StatusBadge } from "@/components/ui";

export function ExhibitionCard({ e }: { e: Exhibition }) {
  return (
    <Link href={`/e/${e.slug}`} className="card group overflow-hidden hover:border-ink">
      <div className="relative aspect-[16/9] overflow-hidden">
        <Cover path={e.cover_path} alt={e.title} />
        <div className="absolute top-3 right-3"><StatusBadge status={e.status} /></div>
      </div>
      <div className="flex items-start gap-3 p-4">
        <Logo path={e.logo_path} name={e.title} size={44} />
        <div className="min-w-0">
          <h3 className="truncate font-heading text-lg font-bold group-hover:text-primary">{e.title}</h3>
          <p className="text-sm text-muted">{fmtDate(e.starts_at, e.timezone)}{e.city ? ` · ${e.city}` : ""}</p>
        </div>
      </div>
    </Link>
  );
}

export function BoothCard({ b, slug, live = false }: { b: Booth; slug: string; live?: boolean }) {
  return (
    <Link href={`/e/${slug}/b/${b.slug}`} className="card group flex flex-col overflow-hidden hover:border-ink">
      <div className="relative h-24 overflow-hidden"><Cover path={b.cover_path} alt="" /></div>
      <div className="-mt-7 flex flex-1 flex-col gap-2 px-4 pb-4">
        <Logo path={b.logo_path} name={b.name} size={56} className="shadow-sm" />
        <div className="flex items-center gap-2">
          <h3 className="truncate font-heading font-bold group-hover:text-primary">{b.name}</h3>
          {b.tier !== "standard" && <span className="badge">{BOOTH_TIER[b.tier]}</span>}
        </div>
        {b.tagline && <p className="line-clamp-2 text-sm text-muted">{b.tagline}</p>}
        <div className="mt-auto flex items-center gap-2 pt-1 text-xs text-muted">
          {live && <LiveBadge />}
          {b.map_slot && <span>الجناح {b.map_slot}</span>}
        </div>
      </div>
    </Link>
  );
}

export function SponsorWall({ sponsors, boothSlugs, exhibitionSlug, compact = false }: {
  sponsors: Sponsor[]; boothSlugs?: Record<string, string>; exhibitionSlug: string; compact?: boolean;
}) {
  const tiers = ["platinum", "gold", "silver", "partner"] as const;
  const size = { platinum: "h-24", gold: "h-20", silver: "h-16", partner: "h-14" };
  return (
    <div className="flex flex-col gap-6">
      {tiers.map((t) => {
        const list = sponsors.filter((s) => s.tier === t);
        if (!list.length) return null;
        return (
          <div key={t}>
            {!compact && <h3 className="mb-3 text-sm font-semibold text-muted">{SPONSOR_TIER[t]}</h3>}
            <div className="flex flex-wrap gap-3">
              {list.map((s) => {
                const href = s.booth_id && boothSlugs?.[s.booth_id]
                  ? `/e/${exhibitionSlug}/b/${boothSlugs[s.booth_id]}` : s.website_url ?? "#";
                const src = thumb(s.logo_path, 400);
                return (
                  <a key={s.id} href={href} target={href.startsWith("http") ? "_blank" : undefined} rel="noopener"
                    className={`card grid ${size[t]} min-w-32 place-items-center px-5 hover:border-ink`} title={s.name}>
                    {src
                      // eslint-disable-next-line @next/next/no-img-element
                      ? <img src={src} alt={s.name} className="max-h-[70%] max-w-40 object-contain" />
                      : <span className="font-heading font-bold">{s.name}</span>}
                  </a>
                );
              })}
            </div>
          </div>
        );
      })}
    </div>
  );
}
