import Link from "next/link";
import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtNum, LEAD_SOURCE, LEAD_STATUS } from "@/lib/format";
import { Stat } from "@/components/ui";

type Stats = {
  booth_views: number; followers: number; likes: number; leads: number; chats: number; stream_peak: number;
  leads_by_status: Record<string, number>; leads_by_source: Record<string, number>;
  daily: { day: string; views: number; leads: number }[];
};

function Bars({ data, label }: { data: [string, number][]; label: (k: string) => string }) {
  const max = Math.max(1, ...data.map(([, v]) => v));
  return (
    <ul className="flex flex-col gap-2">
      {data.map(([k, v]) => (
        <li key={k} className="grid grid-cols-[120px_1fr_40px] items-center gap-3 text-sm">
          <span className="truncate text-muted">{label(k)}</span>
          <span className="h-2.5 overflow-hidden rounded-full bg-bg"><span className="block h-full rounded-full bg-primary" style={{ width: `${(v / max) * 100}%` }} /></span>
          <span className="text-left tabular-nums">{v}</span>
        </li>
      ))}
    </ul>
  );
}

export default async function Analytics({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ days?: string }> }) {
  const { id } = await params;
  const days = Number((await searchParams).days ?? 14) || 14;
  await getStaffBooth(id);
  const db = await expo();
  const { data } = await db.rpc("merchant_stats", { p_booth: id, p_days: days });
  const s = data as Stats;
  const maxDay = Math.max(1, ...s.daily.map((d) => d.views));
  const conv = s.booth_views ? ((s.leads / s.booth_views) * 100).toFixed(1) : "0";
  return (
    <div className="flex flex-col gap-6">
      <div className="flex gap-2">
        {[7, 14, 30].map((d) => <Link key={d} href={`?days=${d}`} className={d === days ? "btn-ink btn-sm" : "btn-ghost btn-sm"}>{d} يوم</Link>)}
      </div>
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-3">
        <Stat label="زيارات الجناح" value={fmtNum(s.booth_views)} />
        <Stat label="العملاء المحتملون" value={fmtNum(s.leads)} hint={`معدل التحويل ${conv}%`} />
        <Stat label="المحادثات" value={fmtNum(s.chats)} />
        <Stat label="المتابعون" value={fmtNum(s.followers)} />
        <Stat label="الإعجابات" value={fmtNum(s.likes)} />
        <Stat label="ذروة مشاهدي البث" value={fmtNum(s.stream_peak)} />
      </div>
      <section className="card p-5">
        <h2 className="mb-4 font-heading text-lg font-bold">الزيارات والعملاء يومياً</h2>
        <div className="flex h-48 items-end gap-1" role="img" aria-label="رسم بياني للزيارات اليومية">
          {s.daily.map((d) => (
            <div key={d.day} className="group relative flex flex-1 flex-col items-center justify-end gap-0.5" title={`${d.day}: ${d.views} زيارة، ${d.leads} عميل`}>
              <div className="w-full rounded-t bg-ink/80" style={{ height: `${(d.views / maxDay) * 100}%`, minHeight: d.views ? 2 : 0 }} />
              {d.leads > 0 && <span className="absolute -top-2 h-2 w-2 rounded-full bg-primary" />}
            </div>
          ))}
        </div>
        <div className="mt-2 flex justify-between text-xs text-muted"><span>{s.daily[0]?.day}</span><span>{s.daily.at(-1)?.day}</span></div>
        <p className="mt-2 text-xs text-muted">الأعمدة: الزيارات · النقطة الحمراء: يوم وصل فيه عميل محتمل. تُحدَّث الإحصاءات كل 15 دقيقة.</p>
      </section>
      <div className="grid gap-6 md:grid-cols-2">
        <section className="card p-5"><h2 className="mb-4 font-heading text-lg font-bold">العملاء حسب المرحلة</h2>
          <Bars data={Object.keys(LEAD_STATUS).map((k) => [k, s.leads_by_status[k] ?? 0])} label={(k) => LEAD_STATUS[k]} /></section>
        <section className="card p-5"><h2 className="mb-4 font-heading text-lg font-bold">مصادر العملاء</h2>
          <Bars data={Object.entries(s.leads_by_source)} label={(k) => LEAD_SOURCE[k] ?? k} /></section>
      </div>
    </div>
  );
}
