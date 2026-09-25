import { getOrganizedExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtNum } from "@/lib/format";
import { ExhibitionFields } from "@/components/ExhibitionFields";
import { Flash } from "@/components/Flash";
import { Stat } from "@/components/ui";
import { setStatus, updateExhibition } from "../../actions";

type O = { visitors: number; booths: number; booths_published: number; applications_pending: number; leads: number; chats: number;
  live_streams: number; live_viewers: number; registrations: number; top_booths: { id: string; name: string; views_count: number; follows_count: number; leads: number }[] };

export default async function OrgOverview({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; ok?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  const e = await getOrganizedExhibition(id);
  const db = await expo();
  const [{ data }, { data: cats }, { data: subs }] = await Promise.all([
    db.rpc("organizer_overview", { p_exhibition: id }),
    db.from("exhibition_categories").select("id, name_ar").order("id"),
    db.rpc("exhibition_subscription_check", { p_exhibition: id }),
  ]);
  const uncovered = ((subs ?? []) as { store_name: string; booth_id: string | null; status: string }[])
    .filter((x) => x.booth_id && x.status !== "ok");
  const o = data as O;
  return (
    <div className="flex flex-col gap-6">
      <Flash error={sp.error} ok={sp.ok ? (sp.ok === "created" ? "تم إنشاء المعرض كمسودة." : "تم الحفظ.") : undefined} />
      {uncovered.length > 0 && (
        <p role="alert" className="rounded-[10px] border border-primary/30 bg-tint p-3 text-sm">
          اشتراك {uncovered.length === 1 ? "العارض" : `${uncovered.length} عارضين`} ({uncovered.map((x) => x.store_name).join("، ")}) لا يغطي فترة المعرض حتى نهايته.
          غالباً بسبب تغيير تاريخ نهاية المعرض. تواصل معهم لتجديد اشتراكاتهم.
        </p>
      )}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat label="الزوار" value={fmtNum(o.visitors)} />
        <Stat label="الأجنحة المنشورة" value={`${o.booths_published}/${o.booths}`} />
        <Stat label="طلبات معلقة" value={o.applications_pending} />
        <Stat label="العملاء المحتملون (إجمالي)" value={fmtNum(o.leads)} hint="بيانات العملاء خاصة بكل عارض" />
        <Stat label="محادثات" value={fmtNum(o.chats)} />
        <Stat label="تسجيلات الجلسات" value={fmtNum(o.registrations)} />
        <Stat label="بث مباشر الآن" value={o.live_streams} />
        <Stat label="مشاهدون الآن" value={fmtNum(o.live_viewers)} />
      </div>

      <section className="card flex flex-wrap items-center gap-3 p-5">
        <div className="me-auto"><h2 className="font-heading text-lg font-bold">حالة المعرض</h2>
          <p className="text-sm text-muted">ينتقل المعرض تلقائياً إلى «مباشر» عند موعد البدء، و«انتهى» عند النهاية، ويُؤرشف بعد 7 أيام.</p></div>
        {e.status === "draft" && <form action={setStatus.bind(null, id, "scheduled")}><button className="btn-primary">نشر المعرض</button></form>}
        {e.status === "scheduled" && <form action={setStatus.bind(null, id, "draft")}><button className="btn-ghost">إلغاء النشر</button></form>}
        {e.status === "scheduled" && <form action={setStatus.bind(null, id, "live")}><button className="btn-ink">ابدأ الآن</button></form>}
        {e.status === "live" && <form action={setStatus.bind(null, id, "ended")}><button className="btn-ink">إنهاء المعرض</button></form>}
      </section>

      {o.top_booths.length > 0 && (
        <section className="card overflow-x-auto">
          <h2 className="border-b border-line p-4 font-heading text-lg font-bold">الأجنحة الأكثر زيارة</h2>
          <table className="table-x"><thead><tr><th>الجناح</th><th>زيارات</th><th>متابعون</th><th>عملاء</th></tr></thead>
            <tbody>{o.top_booths.map((b) => <tr key={b.id}><td>{b.name}</td><td>{fmtNum(b.views_count)}</td><td>{b.follows_count}</td><td>{b.leads}</td></tr>)}</tbody></table>
        </section>
      )}

      <form action={updateExhibition.bind(null, id)} className="flex flex-col gap-5">
        <ExhibitionFields e={e} categories={cats ?? []} uploadPrefix={`exhibitions/${id}`} />
        <section className="card flex flex-col gap-3 p-5">
          <h2 className="font-heading text-lg font-bold">الإعدادات</h2>
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="applications_open" defaultChecked={e.applications_open} className="h-4 w-4 accent-[#C21815]" />استقبال طلبات مشاركة العارضين</label>
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="chat_enabled" defaultChecked={e.chat_enabled} className="h-4 w-4 accent-[#C21815]" />تفعيل المحادثات بين الزوار والعارضين</label>
        </section>
        <button className="btn-primary self-start">حفظ التغييرات</button>
      </form>
    </div>
  );
}
