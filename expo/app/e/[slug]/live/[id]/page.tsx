import Link from "next/link";
import { notFound } from "next/navigation";
import { getExhibition } from "@/lib/queries";
import { expo, getUser } from "@/lib/supabase/server";
import { productUrl } from "@/lib/env";
import { fmtDateTime, fmtMoney } from "@/lib/format";
import { recordingUrl } from "@/lib/storage";
import type { BoothProduct, LiveStream } from "@/lib/types";
import { LiveBadge, Logo } from "@/components/ui";
import { ChatPanel } from "@/components/client/ChatPanel";
import { LikeButton, ShareButton } from "@/components/client/engage";
import { StreamPlayer, ViewerCount } from "@/components/client/stream";
import { TrackedLink, Tracker } from "@/components/client/Tracker";

export default async function LivePage({ params }: { params: Promise<{ slug: string; id: string }> }) {
  const { slug, id } = await params;
  const e = await getExhibition(slug);
  const user = await getUser();
  const db = await expo();
  const { data } = await db.from("live_streams")
    .select("*, booths(id, slug, name, logo_path), exhibition_sessions(id, title)")
    .eq("id", id).eq("exhibition_id", e.id).maybeSingle();
  if (!data) notFound();
  const s = data as LiveStream & {
    booths: { id: string; slug: string; name: string; logo_path: string | null } | null;
    exhibition_sessions: { id: string; title: string } | null;
  };
  const [{ data: chat }, { data: liked }, prods] = await Promise.all([
    db.from("exhibition_chats").select("id, status").eq("stream_id", s.id).maybeSingle(),
    user ? db.from("exhibition_likes").select("user_id").eq("target_type", "stream").eq("target_id", s.id).eq("user_id", user.id).maybeSingle()
      : Promise.resolve({ data: null }),
    s.booths ? db.rpc("booth_products_list", { p_booth: s.booths.id }) : Promise.resolve({ data: [] }),
  ]);
  const products = (prods.data ?? []) as BoothProduct[];
  const pinned = products.find((p) => p.product_id === s.pinned_product_id) ?? products.find((p) => p.is_highlighted);
  const canModerate = user ? (await db.rpc("can_publish_stream", { p_stream: s.id })).data === true : false;

  return (
    <div className="container-x grid gap-6 py-6 lg:grid-cols-[1fr_380px]">
      <Tracker exhibition_id={e.id} stream_id={s.id} booth_id={s.booths?.id} event="stream_join" />
      <div className="flex min-w-0 flex-col gap-4">
        <StreamPlayer streamId={s.id} exhibitionId={e.id} status={s.status} recordingUrl={recordingUrl(s.recording_path)} />
        <div className="flex flex-wrap items-center gap-3">
          {s.status === "live" && <LiveBadge />}
          <h1 className="text-2xl font-extrabold">{s.title}</h1>
          {s.status === "live" && <ViewerCount streamId={s.id} fallback={s.current_viewers} />}
          <div className="ms-auto flex gap-2">
            <LikeButton type="stream" id={s.id} initial={!!liked} count={s.likes_count} signedIn={!!user} />
            <ShareButton title={s.title} exhibitionId={e.id} boothId={s.booths?.id} />
          </div>
        </div>
        {s.booths && (
          <Link href={`/e/${slug}/b/${s.booths.slug}`} className="card flex items-center gap-3 p-4 hover:border-ink">
            <Logo path={s.booths.logo_path} name={s.booths.name} size={48} />
            <div><p className="font-semibold">{s.booths.name}</p><p className="text-sm text-muted">زر الجناح</p></div>
          </Link>
        )}
        {s.exhibition_sessions && <p className="text-sm text-muted">جلسة: {s.exhibition_sessions.title}</p>}
        {s.started_at && <p className="text-xs text-muted">بدأ {fmtDateTime(s.started_at, e.timezone)}</p>}
        {pinned && (
          <TrackedLink href={productUrl(pinned)} target="_blank" rel="noopener" className="card flex items-center gap-4 border-primary p-3"
            ev={{ exhibition_id: e.id, booth_id: s.booths?.id, stream_id: s.id, event: "product_buy_click", props: { product_id: pinned.product_id } }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            {pinned.image_url && <img src={pinned.image_url} alt="" className="h-16 w-16 rounded-lg object-cover" />}
            <div className="flex-1"><p className="text-xs text-primary">المنتج المعروض</p><p className="font-semibold">{pinned.name}</p>
              <p className="text-sm font-bold">{fmtMoney(pinned.expo_price ?? pinned.price)}</p></div>
            <span className="btn-primary btn-sm">اشترِ الآن</span>
          </TrackedLink>
        )}
      </div>
      <aside className="card flex h-[70vh] min-h-[420px] flex-col lg:sticky lg:top-24">
        <h2 className="border-b border-line p-4 font-heading font-bold">الدردشة المباشرة</h2>
        <div className="min-h-0 flex-1">
          {chat ? (
            <ChatPanel chatId={chat.id} meId={user?.id ?? null} readOnly={chat.status !== "open"} canModerate={canModerate} compact
              placeholder={user ? "شارك في الدردشة…" : ""} />
          ) : <p className="p-4 text-sm text-muted">الدردشة غير متاحة.</p>}
        </div>
        {!user && <p className="border-t border-line p-3 text-center text-xs text-muted">سجّل الدخول للمشاركة في الدردشة.</p>}
      </aside>
    </div>
  );
}
