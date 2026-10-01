"use client";
import { useEffect, useState } from "react";

function parts(ms: number) {
  const s = Math.max(0, Math.floor(ms / 1000));
  return { d: Math.floor(s / 86400), h: Math.floor((s % 86400) / 3600), m: Math.floor((s % 3600) / 60), s: s % 60 };
}

export function Countdown({ to, onDark = false, label = "الوقت المتبقي على البدء" }: { to: string; onDark?: boolean; label?: string }) {
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => {
    setNow(Date.now());
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);
  const p = parts(new Date(to).getTime() - (now ?? Date.now()));
  const cell = (v: number, l: string) => (
    <div className="flex min-w-14 flex-col items-center">
      <span className="font-heading text-3xl font-extrabold tabular-nums sm:text-4xl">{String(v).padStart(2, "0")}</span>
      <span className={`text-xs ${onDark ? "text-white/70" : "text-muted"}`}>{l}</span>
    </div>
  );
  return (
    <div className="flex gap-3" role="timer" aria-label={label} suppressHydrationWarning>
      {cell(p.d, "يوم")}{cell(p.h, "ساعة")}{cell(p.m, "دقيقة")}{cell(p.s, "ثانية")}
    </div>
  );
}

/** Compact countdown for small spaces: "2 ي 03:14:05" or "03:14:05". */
export function MiniCountdown({ to, className = "" }: { to: string; className?: string }) {
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => {
    setNow(Date.now());
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);
  const ms = new Date(to).getTime() - (now ?? Date.now());
  if (ms <= 0) return <span className={className}>يبدأ الآن</span>;
  const p = parts(ms);
  const hms = `${String(p.h).padStart(2, "0")}:${String(p.m).padStart(2, "0")}:${String(p.s).padStart(2, "0")}`;
  return (
    <span className={`tabular-nums ${className}`} dir="ltr" suppressHydrationWarning>
      {p.d > 0 ? `${hms} · ${p.d} ي` : hms}
    </span>
  );
}
