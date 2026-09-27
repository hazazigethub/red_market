import Link from "next/link";
import type { Booth, Hall } from "@/lib/types";
import { publicUrl } from "@/lib/storage";
import { MiniCountdown } from "@/components/Countdown";

/** Slot "B-03" -> row 2, col 3. Rows are letters, columns numbers. Grid flows right-to-left (RTL). */
export function parseSlot(slot: string | null): { r: number; c: number } | null {
  const m = slot?.trim().toUpperCase().match(/^([A-Z])-?(\d{1,2})$/);
  return m ? { r: m[1].charCodeAt(0) - 64, c: Number(m[2]) } : null;
}

/** capacity: عدد مواقع هذه القاعة المحسوب من «عدد الأجنحة المتاحة» (فارغ = أعمدة × صفوف القاعة) */
export function HallMap({ hall, booths, slug, liveBoothIds, capacity, upcoming }: {
  hall: Hall; booths: Booth[]; slug: string; liveBoothIds: Set<string>; capacity?: number | null;
  /** booth id -> next scheduled stream time */
  upcoming?: Map<string, string>;
}) {
  const cols = Math.min(Math.max(hall.map_layout?.cols ?? 6, 2), 12);
  const rows = capacity
    ? Math.min(Math.max(Math.ceil(capacity / cols), 1), 26)
    : Math.min(Math.max(hall.map_layout?.rows ?? 4, 1), 26);
  const total = capacity ? Math.min(capacity, rows * cols) : rows * cols;
  const bySlot = new Map<string, Booth>();
  booths.forEach((b) => { const p = parseSlot(b.map_slot); if (p) bySlot.set(`${p.r}-${p.c}`, b); });
  const cells = [];
  for (let r = 1; r <= rows; r++) {
    for (let c = 1; c <= cols; c++) {
      if ((r - 1) * cols + c > total) break;
      const b = bySlot.get(`${r}-${c}`);
      const code = `${String.fromCharCode(64 + r)}-${String(c).padStart(2, "0")}`;
      const live = b ? liveBoothIds.has(b.id) : false;
      const next = b && !live ? upcoming?.get(b.id) : undefined;
      const logo = b ? publicUrl(b.logo_path) : null;
      cells.push(b ? (
        <Link key={code} href={`/e/${slug}/b/${b.slug}`} title={b.name}
          className={`relative flex aspect-square flex-col items-center justify-center gap-1.5 rounded-lg border p-2 text-center transition-colors
            ${live ? "border-2 border-primary bg-tint" : "border-line bg-surface"} hover:border-primary`}>
          <span className="absolute top-1.5 right-2 text-[10px] text-muted">{code}</span>
          {live && <span className="absolute top-2 left-2 h-2.5 w-2.5 rounded-full bg-primary live-dot" aria-label="يبث الآن" />}
          {logo
            ? <img src={logo} alt="" className="h-10 w-10 rounded-full object-cover sm:h-12 sm:w-12" />
            : <span className="grid h-10 w-10 place-items-center rounded-full bg-tint font-heading font-bold text-primary sm:h-12 sm:w-12">{b.name.slice(0, 1)}</span>}
          <span className="line-clamp-2 text-xs font-semibold leading-tight">{b.name}</span>
          {live && <span className="text-[10px] font-bold text-primary">بث مباشر الآن</span>}
          {next && (
            <span className="flex flex-col items-center text-[10px] leading-tight text-muted">
              <MiniCountdown to={next} className="font-bold text-ink" />
              <span>متبقٍ على البث</span>
            </span>
          )}
        </Link>
      ) : (
        <div key={code} className="grid aspect-square place-items-center rounded-lg border border-dashed border-line text-[10px] text-muted/60">{code}</div>
      ));
    }
  }
  return (
    <div className="overflow-x-auto">
      <div className="grid min-w-[520px] gap-2" style={{ gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))` }}>{cells}</div>
    </div>
  );
}
