import { Countdown } from "@/components/Countdown";
import { fmtNum } from "@/lib/format";

/** Hero timing: countdown to the start (upcoming) or to the end in red (running now). */
export function HeroTiming({ status, startsAt, endsAt }: { status: string; startsAt: string; endsAt: string }) {
  if (status === "scheduled") return <Countdown to={startsAt} onDark />;
  if (status === "live") {
    return (
      <div className="flex flex-wrap items-center gap-4">
        <span className="font-heading text-lg font-extrabold text-primary">ينتهي في</span>
        <Countdown to={endsAt} onDark label="الوقت المتبقي على نهاية المعرض" />
      </div>
    );
  }
  return null;
}

/** Exhibitors + visits on the exhibition banner. */
export function HeroStats({ stats }: { stats: { exhibitors?: number; visits?: number } | null }) {
  if (!stats) return null;
  return (
    <div className="flex flex-wrap gap-6 text-sm">
      <p><span className="font-heading text-2xl font-extrabold">{fmtNum(stats.exhibitors ?? 0)}</span> <span className="text-white/70">عارض</span></p>
      <p><span className="font-heading text-2xl font-extrabold">{fmtNum(stats.visits ?? 0)}</span> <span className="text-white/70">زيارة</span></p>
    </div>
  );
}
