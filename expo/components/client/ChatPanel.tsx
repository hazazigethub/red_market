"use client";
import { useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { arabicError } from "@/lib/errors";
import { functionsUrl, productUrl } from "@/lib/env";
import { fmtMoney, fmtTime } from "@/lib/format";
import { publicUrl } from "@/lib/storage";
import { expoBrowser } from "@/lib/supabase/client";
import type { Message } from "@/lib/types";
import { authHeaders, realtimeAuth } from "@/components/client/useSession";

type Att = Record<string, string | number | null | undefined>;
const att = (m: Message) => (m.attachments ?? {}) as Att;
const s = (v: unknown) => (v == null ? "" : String(v));

/** Download a catalog the exhibitor shared in the stream chat (open to everyone). */
async function downloadCatalog(m: Message) {
  const res = await fetch(`${functionsUrl}/expo-catalog`, {
    method: "POST", headers: await authHeaders(),
    body: JSON.stringify({ media_id: att(m).media_id, message_id: m.id }),
  });
  const data = await res.json().catch(() => ({}));
  if (data?.url) window.open(data.url, "_blank", "noopener");
}

/** Save the exhibitor's contact card as a phone contact (.vcf). */
function saveContact(a: Att) {
  const lines = ["BEGIN:VCARD", "VERSION:3.0", `FN:${s(a.name)}`, `ORG:${s(a.name)}`];
  if (a.phone) lines.push(`TEL;TYPE=CELL:${s(a.phone)}`);
  if (a.whatsapp && a.whatsapp !== a.phone) lines.push(`TEL;TYPE=WORK:${s(a.whatsapp)}`);
  if (a.email) lines.push(`EMAIL:${s(a.email)}`);
  if (a.website) lines.push(`URL:${s(a.website)}`);
  lines.push("END:VCARD");
  const url = URL.createObjectURL(new Blob([lines.join("\r\n")], { type: "text/vcard" }));
  const link = document.createElement("a");
  link.href = url; link.download = `${s(a.name) || "contact"}.vcf`; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** Product / catalog / contact card inside a message. */
function MessageCard({ m, dark }: { m: Message; dark: boolean }) {
  const a = att(m);
  const box = dark ? "bg-black/45 text-white border-white/15" : "bg-surface text-ink border-line";
  const btn = "mt-2 inline-flex h-8 items-center rounded-full bg-primary px-3.5 text-xs font-bold text-white";
  if (m.kind === "product_card") {
    const price = a.expo_price ?? a.price;
    return (
      <div className={`flex w-64 max-w-full gap-3 rounded-2xl border p-2.5 ${box}`}>
        {a.image_url ? <img src={s(a.image_url)} alt="" className="h-16 w-16 shrink-0 rounded-xl object-cover" /> : null}
        <div className="min-w-0">
          <p className="truncate text-sm font-bold">{s(a.name)}</p>
          {price != null && <p className="text-xs opacity-80">{fmtMoney(Number(price))}</p>}
          <a className={btn} href={productUrl({ url: s(a.url) || null, product_id: s(a.product_id) })} target="_blank" rel="noopener">اشترِ الآن</a>
        </div>
      </div>
    );
  }
  if (m.kind === "catalog") {
    return (
      <div className={`w-64 max-w-full rounded-2xl border p-3 ${box}`}>
        <p className="text-xs opacity-70">كتالوج</p>
        <p className="truncate text-sm font-bold">{s(a.title) || m.body || "كتالوج"}</p>
        <button className={btn} onClick={() => downloadCatalog(m)}>تنزيل</button>
      </div>
    );
  }
  if (m.kind === "contact_card") {
    const logo = publicUrl(s(a.logo_path) || null);
    return (
      <div className={`w-64 max-w-full rounded-2xl border p-3 ${box}`}>
        <div className="flex items-center gap-2.5">
          {logo ? <img src={logo} alt="" className="h-10 w-10 rounded-full object-cover" /> : null}
          <p className="truncate text-sm font-bold">{s(a.name)}</p>
        </div>
        <div className="mt-2 space-y-0.5 text-xs opacity-85" dir="ltr">
          {a.phone ? <a className="block text-right" href={`tel:${s(a.phone)}`}>{s(a.phone)}</a> : null}
          {a.email ? <a className="block text-right" href={`mailto:${s(a.email)}`}>{s(a.email)}</a> : null}
          {a.website ? <a className="block truncate text-right" href={s(a.website)} target="_blank" rel="noopener">{s(a.website)}</a> : null}
        </div>
        <div className="flex flex-wrap gap-2">
          <button className={btn} onClick={() => saveContact(a)}>حفظ جهة الاتصال</button>
          {a.whatsapp ? <a className={btn} href={`https://wa.me/${s(a.whatsapp).replace(/\D/g, "")}`} target="_blank" rel="noopener">واتساب</a> : null}
        </div>
      </div>
    );
  }
  return null;
}

/** overlay: فوق الفيديو (أسلوب TikTok للجوال) — خلفية شفافة ونص أبيض */
export function ChatPanel({ chatId, meId, readOnly = false, canModerate = false, compact = false, placeholder = "اكتب رسالتك…", onModerateUser, overlay = false, streamId }: {
  chatId: string; meId: string | null; readOnly?: boolean; canModerate?: boolean; compact?: boolean;
  placeholder?: string; onModerateUser?: (userId: string, name: string) => void; overlay?: boolean;
  /** stream chats: show likes as lines in the chat */
  streamId?: string;
}) {
  const [msgs, setMsgs] = useState<Message[]>([]);
  const [text, setText] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const [replyTo, setReplyTo] = useState<Message | null>(null);
  const [visitorsMuted, setVisitorsMuted] = useState(false);
  const listRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // likes appear as short lines in the stream chat (kept in the page only, not saved)
  useEffect(() => {
    if (!streamId) return;
    let n = 0;
    const onLike = (ev: Event) => {
      const d = (ev as CustomEvent<{ streamId: string; name: string | null }>).detail;
      if (d.streamId !== streamId) return;
      n += 1;
      const line: Message = {
        id: -Date.now() - n, chat_id: chatId, sender_id: "", sender_name: d.name ?? "زائر",
        kind: "system", body: `❤ ${d.name ?? "زائر"} أعجبه البث`, attachments: null,
        created_at: new Date().toISOString(), deleted_at: null,
      };
      setMsgs((m) => [...m.slice(-199), line]);
    };
    window.addEventListener("expo:stream-like", onLike);
    return () => window.removeEventListener("expo:stream-like", onLike);
  }, [streamId, chatId]);

  useEffect(() => {
    let channel: RealtimeChannel | null = null;
    let alive = true;
    (async () => {
      const sb = expoBrowser();
      const { data } = await sb.rpc("chat_messages", { p_chat: chatId, p_limit: 60 });
      if (alive && data) setMsgs((data as Message[]).reverse());
      const { data: chat } = await sb.from("exhibition_chats").select("visitors_muted").eq("id", chatId).maybeSingle();
      if (alive && chat) setVisitorsMuted(!!chat.visitors_muted);
      const rt = await realtimeAuth();
      channel = rt.channel(`chat:${chatId}`, { config: { private: true } })
        .on("broadcast", { event: "message" }, ({ payload }) => {
          setMsgs((m) => (m.some((x) => x.id === payload.id) ? m : [...m.slice(-199), payload as Message]));
        })
        .on("broadcast", { event: "message_deleted" }, ({ payload }) => {
          setMsgs((m) => m.map((x) => (x.id === payload.id ? { ...x, body: "", deleted_at: new Date().toISOString() } : x)));
        })
        .on("broadcast", { event: "settings" }, ({ payload }) => setVisitorsMuted(!!payload.visitors_muted))
        .subscribe();
    })();
    return () => { alive = false; channel?.unsubscribe(); };
  }, [chatId]);

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight });
  }, [msgs.length]);

  const canWrite = !readOnly && !!meId && (!visitorsMuted || canModerate);

  async function send() {
    const body = text.trim();
    if (!body || !meId) return;
    setSending(true); setErr(null);
    const { error } = await expoBrowser().from("exhibition_messages")
      .insert({ chat_id: chatId, body, reply_to: replyTo?.id ?? null });
    setSending(false);
    if (error) return setErr(arabicError(error.message));
    setText(""); setReplyTo(null);
  }

  async function remove(id: number) {
    const { error } = await expoBrowser().rpc("delete_message", { p_message: id });
    if (error) setErr(arabicError(error.message));
  }

  function reply(m: Message) {
    setReplyTo(m);
    inputRef.current?.focus();
  }

  const nameOf = (m: Message) => (m.sender_id === meId ? "أنت" : (m.sender_name ?? "مشارك"));
  const snippet = (t: string | null | undefined) => {
    const v = (t ?? "").trim();
    return v.length > 60 ? `${v.slice(0, 60)}…` : v;
  };

  const replyBar = replyTo && (
    <div className={`mx-3 mb-1 flex items-center gap-2 rounded-xl px-3 py-1.5 text-xs ${overlay ? "bg-black/45 text-white" : "bg-bg text-muted"}`}>
      <span className="min-w-0 flex-1 truncate">رداً على <b>{nameOf(replyTo)}</b>: {snippet(replyTo.body)}</span>
      <button type="button" aria-label="إلغاء الرد" onClick={() => setReplyTo(null)}>✕</button>
    </div>
  );

  const quote = (m: Message, dark: boolean) => m.reply_to && (
    <p className={`mb-1 border-r-2 pr-2 text-[11px] ${dark ? "border-white/60 text-white/75" : "border-primary/60 text-muted"}`}>
      <b>{m.reply_name ?? "مشارك"}</b>: {snippet(m.reply_body) || "رسالة محذوفة"}
    </p>
  );

  const mutedNote = visitorsMuted && !canModerate && !readOnly && meId;

  if (overlay) {
    return (
      <div className="flex h-full min-h-0 flex-col justify-end">
        <div ref={listRef}
          className="max-h-full space-y-1.5 overflow-y-auto px-3 pb-2 [mask-image:linear-gradient(to_bottom,transparent,black_25%)]"
          aria-live="polite">
          {msgs.filter((m) => !m.deleted_at).slice(-40).map((m) => (
            <div key={m.id} className="flex flex-col items-start" onClick={() => canWrite && m.kind === "text" && reply(m)}>
              {m.kind === "system" ? (
                <p className="w-fit rounded-full bg-primary/70 px-3 py-1 text-xs font-bold text-white">{m.body}</p>
              ) : m.kind === "text" ? (
                <p className="w-fit max-w-[85%] rounded-2xl bg-black/35 px-3 py-1.5 text-[13px] leading-6 text-white [text-shadow:0_1px_2px_rgba(0,0,0,.5)]">
                  {quote(m, true)}
                  <span className="font-bold opacity-80">{nameOf(m)}: </span>
                  <span className="whitespace-pre-wrap break-words">{m.body}</span>
                </p>
              ) : <MessageCard m={m} dark />}
            </div>
          ))}
        </div>
        {canWrite && replyBar}
        {canWrite && (
          <form className="flex gap-2 p-3 pt-1" onSubmit={(e) => { e.preventDefault(); send(); }}>
            <input ref={inputRef} className="h-10 w-full rounded-full border border-white/25 bg-black/35 px-4 text-sm text-white placeholder:text-white/60 focus:outline-none"
              value={text} onChange={(e) => setText(e.target.value)} placeholder={placeholder} maxLength={2000} aria-label="الرسالة" />
            <button className="h-10 shrink-0 rounded-full bg-primary px-4 text-sm font-bold text-white disabled:opacity-50"
              disabled={sending || !text.trim()}>إرسال</button>
          </form>
        )}
        {mutedNote && <p className="px-3 pb-3 text-xs text-white/80">الكتابة متوقفة من العارض.</p>}
        {err && <p className="px-3 pb-2 text-xs text-white" role="alert">{err}</p>}
      </div>
    );
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div ref={listRef} className={`flex-1 space-y-3 overflow-y-auto p-4 ${compact ? "text-sm" : ""}`} aria-live="polite">
        {msgs.length === 0 && <p className="py-8 text-center text-sm text-muted">لا توجد رسائل بعد. ابدأ المحادثة.</p>}
        {msgs.map((m) => {
          const mine = m.sender_id === meId;
          if (m.kind === "system") {
            return <p key={m.id} className="text-center text-xs font-semibold text-primary">{m.body}</p>;
          }
          return (
            <div key={m.id} className={`group flex flex-col ${mine ? "items-start" : "items-end"}`}>
              {m.kind !== "text" && !m.deleted_at ? <MessageCard m={m} dark={false} /> : (
                <div className={`max-w-[85%] rounded-2xl px-3.5 py-2 ${mine ? "bg-ink text-bg" : "bg-bg text-ink"}`}>
                  {!mine && <p className="mb-0.5 text-xs font-semibold opacity-70">{m.sender_name ?? "مشارك"}</p>}
                  {!m.deleted_at && quote(m, mine)}
                  <p className="whitespace-pre-wrap break-words">{m.deleted_at ? <em className="opacity-60">تم حذف الرسالة</em> : m.body}</p>
                </div>
              )}
              <div className="mt-0.5 flex gap-2 px-1 text-[11px] text-muted">
                <span>{fmtTime(m.created_at)}</span>
                {!m.deleted_at && canWrite && m.kind === "text" && (
                  <button className="opacity-0 group-hover:opacity-100 focus:opacity-100" onClick={() => reply(m)}>رد</button>
                )}
                {!m.deleted_at && (mine || canModerate) && (
                  <button className="opacity-0 group-hover:opacity-100 focus:opacity-100" onClick={() => remove(m.id)}>حذف</button>
                )}
                {canModerate && !mine && onModerateUser && (
                  <button className="opacity-0 group-hover:opacity-100 focus:opacity-100" onClick={() => onModerateUser(m.sender_id, m.sender_name ?? "")}>حظر</button>
                )}
              </div>
            </div>
          );
        })}
      </div>
      {readOnly ? (
        <p className="border-t border-line p-3 text-center text-xs text-muted">المحادثة للقراءة فقط.</p>
      ) : mutedNote ? (
        <p className="border-t border-line p-3 text-center text-xs text-muted">الكتابة متوقفة من العارض.</p>
      ) : canWrite ? (
        <div className="border-t border-line pt-2">
          {replyBar}
          <form className="flex gap-2 p-3 pt-1" onSubmit={(e) => { e.preventDefault(); send(); }}>
            <input ref={inputRef} className="input" value={text} onChange={(e) => setText(e.target.value)} placeholder={placeholder} maxLength={2000} aria-label="الرسالة" />
            <button className="btn-primary" disabled={sending || !text.trim()}>إرسال</button>
          </form>
        </div>
      ) : null}
      {err && <p className="px-3 pb-2 text-xs text-primary" role="alert">{err}</p>}
    </div>
  );
}
