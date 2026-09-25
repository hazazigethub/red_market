import Link from "next/link";
import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtDateTime } from "@/lib/format";
import type { BoothProduct, LiveStream } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { LiveBadge } from "@/components/ui";
import { ChatPanel } from "@/components/client/ChatPanel";
import { StreamStudio } from "@/components/client/stream";
import { createStream, deleteStream, pinProduct } from "../../../actions";

const LABEL: Record<string, string> = { scheduled: "مجدول", live: "مباشر", ended: "انتهى", failed: "فشل" };

export default async function Studio({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<{ stream?: string; error?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const b = await getStaffBooth(id);
  const db = await expo();
  const [{ data }, { data: prods }] = await Promise.all([
    db.from("live_streams").select("*").eq("booth_id", id).order("created_at", { ascending: false }),
    db.rpc("booth_products_list", { p_booth: id }),
  ]);
  const streams = (data ?? []) as LiveStream[];
  const active = streams.find((s) => s.id === sp.stream);
  const canStream = ["scheduled", "live"].includes(b.exhibitions.status);

  if (active) {
    const { data: chat } = await db.from("exhibition_chats").select("id").eq("stream_id", active.id).maybeSingle();
    return (
      <div className="flex flex-col gap-4">
        <Link href={`/merchant/booths/${id}/studio`} className="text-sm text-muted">← كل البثوث</Link>
        <Flash error={sp.error} />
        <div className="grid gap-6 xl:grid-cols-[1fr_340px]">
          <div className="flex flex-col gap-4">
            <h2 className="font-heading text-xl font-bold">{active.title}</h2>
            <StreamStudio streamId={active.id} status={active.status} />
            <form action={pinProduct.bind(null, id, active.id)} className="card flex flex-wrap items-end gap-3 p-4">
              <div className="flex-1"><label className="label">المنتج المثبت أثناء البث</label>
                <select name="product_id" className="input" defaultValue={active.pinned_product_id ?? ""}>
                  <option value="">بدون</option>
                  {((prods ?? []) as BoothProduct[]).map((p) => <option key={p.product_id} value={p.product_id}>{p.name}</option>)}
                </select></div>
              <button className="btn-ghost">تثبيت</button>
            </form>
            <p className="text-xs text-muted">للبث من OBS: استخدم LiveKit Ingress (RTMP/WHIP) على نفس الغرفة. البث من المتصفح يكفي لمعظم العارضين.</p>
          </div>
          <div className="card flex h-[65vh] min-h-96 flex-col">
            <h3 className="border-b border-line p-4 font-heading font-bold">دردشة البث (إشراف)</h3>
            <div className="min-h-0 flex-1">{chat && <ChatPanel chatId={chat.id} meId={b.userId} canModerate compact />}</div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <Flash error={sp.error} />
      {canStream ? (
        <form action={createStream.bind(null, id)} className="card grid gap-4 p-5 sm:grid-cols-[1fr_220px_auto] sm:items-end">
          <div><label className="label" htmlFor="st">عنوان البث</label><input id="st" name="title" className="input" required placeholder="مثال: عرض مباشر لمنتجات الموسم" /></div>
          <div><label className="label" htmlFor="sa">الموعد (بتوقيت الرياض)</label><input id="sa" name="scheduled_at" type="datetime-local" className="input" /></div>
          <button className="btn-primary">إنشاء بث</button>
        </form>
      ) : <p className="card p-5 text-sm text-muted">البث متاح عندما يكون المعرض مجدولاً أو مباشراً.</p>}
      <ul className="card divide-y divide-line">
        {streams.length === 0 && <li className="p-4 text-sm text-muted">لا توجد بثوث.</li>}
        {streams.map((s) => (
          <li key={s.id} className="flex flex-wrap items-center gap-3 p-4">
            {s.status === "live" ? <LiveBadge /> : <span className="badge">{LABEL[s.status]}</span>}
            <div className="min-w-0 flex-1"><p className="font-medium">{s.title}</p>
              <p className="text-xs text-muted">{s.scheduled_at ? fmtDateTime(s.scheduled_at) : "بدون موعد"} · ذروة المشاهدين {s.peak_viewers}</p></div>
            {s.status !== "ended" && canStream && <Link href={`?stream=${s.id}`} className="btn-primary btn-sm">فتح الاستوديو</Link>}
            {s.status === "scheduled" && <form action={deleteStream.bind(null, id, s.id)}><button className="text-xs text-muted hover:text-primary">حذف</button></form>}
          </li>
        ))}
      </ul>
    </div>
  );
}
