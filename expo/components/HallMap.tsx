import Link from "next/link";
import type { Booth, Hall } from "@/lib/types";

/** Slot "B-03" -> row 2, col 3. Rows are letters, columns numbers. Grid flows right-to-left (RTL). */
export function parseSlot(slot: string | null): { r: number; c: number } | null {
  const m = slot?.trim().toUpperCase().match(/^([A-Z])-?(\d{1,2})$/);
  return m ? { r: m[1].charCodeAt(0) - 64, c: Number(m[2]) } : null;
}

export function HallMap({ hall, booths, slug, liveBoothIds }: {
  hall: Hall; booths: Booth[]; slug: string; liveBoothIds: Set<string>;
}) {
  const cols = Math.min(Math.max(hall.map_layout?.cols ?? 6, 2), 12);
  const rows = Math.min(Math.max(hall.map_layout?.rows ?? 4, 1), 26);
  const bySlot = new Map<string, Booth>();
  booths.forEach((b) => { const p = parseSlot(b.map_slot); if (p) bySlot.set(`${p.r}-${p.c}`, b); });
  const cells = [];
  for (let r = 1; r <= rows; r++) {
    for (let c = 1; c <= cols; c++) {
      const b = bySlot.get(`${r}-${c}`);
      const code = `${String.fromCharCode(64 + r)}-${String(c).padStart(2, "0")}`;
      cells.push(b ? (
        <Link key={code} href={`/e/${slug}/b/${b.slug}`} title={b.name}
          className={`relative flex aspect-square flex-col justify-between rounded-lg border p-2 text-start transition-colors
            ${b.tier === "sponsor" ? "border-primary bg-tint" : b.tier === "premium" ? "border-ink bg-surface" : "border-line bg-surface"}
            hover:border-primary`}>
          <span className="text-[10px] text-muted">{code}</span>
          <span className="line-clamp-2 text-xs font-semibold leading-tight">{b.name}</span>
          {liveBoothIds.has(b.id) && <span className="absolute top-1.5 left-1.5 h-2 w-2 rounded-full bg-primary live-dot" aria-label="يبث الآن" />}
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
