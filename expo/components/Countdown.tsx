"use client";
import { useEffect, useState } from "react";

function parts(ms: number) {
  const s = Math.max(0, Math.floor(ms / 1000));
  return { d: Math.floor(s / 86400), h: Math.floor((s % 86400) / 3600), m: Math.floor((s % 3600) / 60), s: s % 60 };
}

export function Countdown({ to, onDark = false }: { to: string; onDark?: boolean }) {
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
    <div className="flex gap-3" role="timer" aria-label="الوقت المتبقي على البدء" suppressHydrationWarning>
      {cell(p.d, "يوم")}{cell(p.h, "ساعة")}{cell(p.m, "دقيقة")}{cell(p.s, "ثانية")}
    </div>
  );
}
