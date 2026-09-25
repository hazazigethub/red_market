import Link from "next/link";
import { getBoothBySlug, getExhibition } from "@/lib/queries";
import { expo, getUser } from "@/lib/supabase/server";
import { productUrl } from "@/lib/env";
import { fmtMoney, fmtNum } from "@/lib/format";
import { publicUrl, thumb } from "@/lib/storage";
import type { BoothMedia, BoothProduct, LiveStream } from "@/lib/types";
import { Cover, EmptyState, LiveBadge, Logo, Tabs } from "@/components/ui";
import { BoothChat } from "@/components/client/BoothChat";
import { CatalogButton } from "@/components/client/CatalogButton";
import { FollowButton, LikeButton, ShareButton } from "@/components/client/engage";
import { InquiryForm } from "@/components/client/InquiryForm";
import { TrackedLink, Tracker } from "@/components/client/Tracker";

export default async function BoothPage({ params, searchParams }: {
  params: Promise<{ slug: string; booth: string }>; searchParams: Promise<{ tab?: string }>;
}) {
  const { slug, booth: boothSlug } = await params;
  const { tab = "about" } = await searchParams;
  const e = await getExhibition(slug);
  const b = await getBoothBySlug(e.id, boothSlug);
  const user = await getUser();
  const db = await expo();
  const [{ data: products }, { data: media }, { data: streams }, eng] = await Promise.all([
    db.rpc("booth_products_list", { p_booth: b.id }),
    db.from("booth_media").select("*").eq("booth_id", b.id).order("sort_order"),
    db.from("live_streams").select("*").eq("booth_id", b.id).order("created_at", { ascending: false }).limit(10),
    user ? db.rpc("my_engagement", { p_booth: b.id }) : Promise.resolve({ data: null }),
  ]);
  const me = (eng.data ?? {}) as { following?: boolean; liked?: boolean; chat_id?: string | null; has_consent?: boolean };
  const prods = (products ?? []) as BoothProduct[];
  const all = (media ?? []) as BoothMedia[];
  const images = all.filter((m) => m.type === "image");
  const videos = all.filter((m) => m.type === "video");
  const catalogs = all.filter((m) => m.type === "catalog");
  const streamList = (streams ?? []) as LiveStream[];
  const live = streamList.find((s) => s.status === "live");
  const chatEnabled = e.chat_enabled && ["scheduled", "live", "ended"].includes(e.status);
  const base = `/e/${slug}/b/${b.slug}`;
  const tabs = [
    { key: "about", label: "نبذة", href: `${base}?tab=about` },
    { key: "products", label: "المنتجات", href: `${base}?tab=products`, count: prods.length },
    { key: "catalogs", label: "الكتالوجات", href: `${base}?tab=catalogs`, count: catalogs.length },
    { key: "gallery", label: "المعرض", href: `${base}?tab=gallery`, count: images.length },
    { key: "videos", label: "فيديو", href: `${base}?tab=videos`, count: videos.length + streamList.filter((s) => s.recording_path).length },
  ];

  return (
    <>
      <Tracker exhibition_id={e.id} booth_id={b.id} event="booth_view" />
      <div className="relative h-48 bg-ink sm:h-64"><Cover path={b.cover_path} alt="" /></div>
      <div className="container-x">
        <div className="-mt-12 flex flex-col gap-4 sm:flex-row sm:items-end">
          <Logo path={b.logo_path} name={b.name} size={104} className="border-4 border-bg shadow-md" />
          <div className="min-w-0 flex-1 pb-1">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-3xl font-extrabold">{b.name}</h1>
              {live && <Link href={`/e/${slug}/live/${live.id}`}><LiveBadge label="يبث الآن" /></Link>}
            </div>
            {b.tagline && <p className="text-muted">{b.tagline}</p>}
            <p className="mt-1 text-xs text-muted">{fmtNum(b.follows_count)} متابع{b.map_slot ? ` · الجناح ${b.map_slot}` : ""}</p>
          </div>
          <div className="flex flex-wrap gap-2 pb-1">
            <BoothChat boothId={b.id} boothName={b.name} exhibitionId={e.id} meId={user?.id ?? null}
              existingChatId={me.chat_id ?? null} hasConsent={!!me.has_consent} enabled={chatEnabled} />
            <FollowButton boothId={b.id} initial={!!me.following} count={b.follows_count} signedIn={!!user} />
            <LikeButton type="booth" id={b.id} initial={!!me.liked} count={b.likes_count} signedIn={!!user} />
            <ShareButton title={b.name} exhibitionId={e.id} boothId={b.id} />
          </div>
        </div>

        <div className="mt-8 grid gap-8 lg:grid-cols-[1fr_340px]">
          <div className="min-w-0">
            <Tabs items={tabs} active={tab} />
            <div className="py-6">
              {tab === "about" && (
                <div className="flex flex-col gap-6">
                  {live && (
                    <Link href={`/e/${slug}/live/${live.id}`} className="card flex items-center gap-4 border-primary p-4">
                      <LiveBadge /><span className="font-semibold">{live.title}</span><span className="ms-auto text-sm text-primary">شاهد الآن</span>
                    </Link>
                  )}
                  {b.about ? <p className="whitespace-pre-line leading-8">{b.about}</p> : <p className="text-muted">لم يضف العارض نبذة بعد.</p>}
                  {prods.some((p) => p.is_highlighted) && (
                    <div>
                      <h2 className="mb-3 font-heading text-lg font-bold">منتجات مميزة</h2>
                      <ProductGrid products={prods.filter((p) => p.is_highlighted).slice(0, 4)} exhibitionId={e.id} boothId={b.id} />
                    </div>
                  )}
                </div>
              )}
              {tab === "products" && (prods.length ? <ProductGrid products={prods} exhibitionId={e.id} boothId={b.id} />
                : <EmptyState title="لا توجد منتجات معروضة بعد" />)}
              {tab === "catalogs" && (catalogs.length ? (
                <div className="grid gap-3 sm:grid-cols-2">
                  {catalogs.map((c) => <CatalogButton key={c.id} mediaId={c.id} title={c.title ?? "كتالوج"} gated={c.is_gated}
                    signedIn={!!user} hasConsent={!!me.has_consent} />)}
                </div>
              ) : <EmptyState title="لا توجد كتالوجات" />)}
              {tab === "gallery" && (images.length ? (
                <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
                  {images.map((m) => (
                    <a key={m.id} href={publicUrl(m.storage_path)!} target="_blank" rel="noopener" className="overflow-hidden rounded-xl border border-line">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={thumb(m.storage_path, 800)!} alt={m.title ?? ""} loading="lazy" className="aspect-[4/3] w-full object-cover" />
                    </a>
                  ))}
                </div>
              ) : <EmptyState title="لا توجد صور" />)}
              {tab === "videos" && (
                <div className="grid gap-4 md:grid-cols-2">
                  {videos.map((v) => (
                    <figure key={v.id} className="card overflow-hidden">
                      <video src={publicUrl(v.storage_path)!} controls preload="metadata" className="aspect-video w-full bg-ink" />
                      {v.title && <figcaption className="p-3 text-sm font-semibold">{v.title}</figcaption>}
                    </figure>
                  ))}
                  {streamList.filter((s) => s.recording_path).map((s) => (
                    <Link key={s.id} href={`/e/${slug}/live/${s.id}`} className="card flex items-center gap-3 p-4 hover:border-ink">
                      <span className="badge">تسجيل بث</span><span className="truncate font-semibold">{s.title}</span>
                    </Link>
                  ))}
                  {!videos.length && !streamList.some((s) => s.recording_path) && <EmptyState title="لا توجد فيديوهات" />}
                </div>
              )}
            </div>
          </div>

          <aside className="flex flex-col gap-5 lg:sticky lg:top-24 lg:self-start">
            <div className="card p-5">
              <h2 className="mb-4 font-heading text-lg font-bold">أرسل استفساراً</h2>
              <InquiryForm boothId={b.id} signedIn={!!user} defaultName={(user?.user_metadata?.full_name as string) ?? ""} />
            </div>
            {(b.contact.website || b.contact.whatsapp || b.contact.email || b.contact.phone) && (
              <div className="card flex flex-col gap-2 p-5 text-sm">
                <h2 className="mb-1 font-heading text-lg font-bold">تواصل</h2>
                {b.contact.whatsapp && <a className="hover:text-primary" href={`https://wa.me/${b.contact.whatsapp.replace(/\D/g, "")}`} target="_blank" rel="noopener">واتساب</a>}
                {b.contact.phone && <a className="hover:text-primary" href={`tel:${b.contact.phone}`} dir="ltr">{b.contact.phone}</a>}
                {b.contact.email && <a className="hover:text-primary" href={`mailto:${b.contact.email}`} dir="ltr">{b.contact.email}</a>}
                {b.contact.website && <a className="hover:text-primary" href={b.contact.website} target="_blank" rel="noopener" dir="ltr">{b.contact.website.replace(/^https?:\/\//, "")}</a>}
              </div>
            )}
          </aside>
        </div>
      </div>
    </>
  );
}

function ProductGrid({ products, exhibitionId, boothId }: { products: BoothProduct[]; exhibitionId: string; boothId: string }) {
  return (
    <div className="grid grid-cols-2 gap-4 md:grid-cols-3">
      {products.map((p) => (
        <TrackedLink key={p.product_id} href={productUrl(p)} target="_blank" rel="noopener" className="card group overflow-hidden hover:border-ink"
          ev={{ exhibition_id: exhibitionId, booth_id: boothId, event: "product_buy_click", props: { product_id: p.product_id } }}>
          <div className="relative aspect-square bg-bg">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            {p.image_url && <img src={p.image_url} alt={p.name} loading="lazy" className="h-full w-full object-cover" />}
            {p.expo_badge && <span className="badge-live absolute top-2 right-2">{p.expo_badge}</span>}
          </div>
          <div className="p-3">
            <p className="line-clamp-2 text-sm font-semibold group-hover:text-primary">{p.name}</p>
            <p className="mt-1 text-sm">
              {p.expo_price != null && p.price != null && p.expo_price < p.price ? (
                <><span className="font-bold text-primary">{fmtMoney(p.expo_price)}</span> <s className="text-xs text-muted">{fmtMoney(p.price)}</s></>
              ) : <span className="font-bold">{fmtMoney(p.expo_price ?? p.price)}</span>}
            </p>
            <span className="mt-2 inline-block text-xs font-semibold text-primary">اشترِ من Red Market ←</span>
          </div>
        </TrackedLink>
      ))}
    </div>
  );
}
