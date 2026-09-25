"use client";
import { useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { arabicError } from "@/lib/errors";
import { fmtTime } from "@/lib/format";
import { expoBrowser } from "@/lib/supabase/client";
import type { Message } from "@/lib/types";
import { realtimeAuth } from "@/components/client/useSession";

export function ChatPanel({ chatId, meId, readOnly = false, canModerate = false, compact = false, placeholder = "اكتب رسالتك…", onModerateUser }: {
  chatId: string; meId: string | null; readOnly?: boolean; canModerate?: boolean; compact?: boolean;
  placeholder?: string; onModerateUser?: (userId: string, name: string) => void;
}) {
  const [msgs, setMsgs] = useState<Message[]>([]);
  const [text, setText] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let channel: RealtimeChannel | null = null;
    let alive = true;
    (async () => {
      const { data } = await expoBrowser().rpc("chat_messages", { p_chat: chatId, p_limit: 60 });
      if (alive && data) setMsgs((data as Message[]).reverse());
      const sb = await realtimeAuth();
      channel = sb.channel(`chat:${chatId}`, { config: { private: true } })
        .on("broadcast", { event: "message" }, ({ payload }) => {
          setMsgs((m) => (m.some((x) => x.id === payload.id) ? m : [...m.slice(-199), payload as Message]));
        })
        .on("broadcast", { event: "message_deleted" }, ({ payload }) => {
          setMsgs((m) => m.map((x) => (x.id === payload.id ? { ...x, body: "", deleted_at: new Date().toISOString() } : x)));
        })
        .subscribe();
    })();
    return () => { alive = false; channel?.unsubscribe(); };
  }, [chatId]);

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight });
  }, [msgs.length]);

  async function send() {
    const body = text.trim();
    if (!body || !meId) return;
    setSending(true); setErr(null);
    const { error } = await expoBrowser().from("exhibition_messages").insert({ chat_id: chatId, body });
    setSending(false);
    if (error) return setErr(arabicError(error.message));
    setText("");
  }

  async function remove(id: number) {
    const { error } = await expoBrowser().rpc("delete_message", { p_message: id });
    if (error) setErr(arabicError(error.message));
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div ref={listRef} className={`flex-1 space-y-3 overflow-y-auto p-4 ${compact ? "text-sm" : ""}`} aria-live="polite">
        {msgs.length === 0 && <p className="py-8 text-center text-sm text-muted">لا توجد رسائل بعد. ابدأ المحادثة.</p>}
        {msgs.map((m) => {
          const mine = m.sender_id === meId;
          return (
            <div key={m.id} className={`group flex flex-col ${mine ? "items-start" : "items-end"}`}>
              <div className={`max-w-[85%] rounded-2xl px-3.5 py-2 ${mine ? "bg-ink text-bg" : "bg-bg text-ink"}`}>
                {!mine && <p className="mb-0.5 text-xs font-semibold opacity-70">{m.sender_name ?? "مشارك"}</p>}
                <p className="whitespace-pre-wrap break-words">{m.deleted_at ? <em className="opacity-60">تم حذف الرسالة</em> : m.body}</p>
              </div>
              <div className="mt-0.5 flex gap-2 px-1 text-[11px] text-muted">
                <span>{fmtTime(m.created_at)}</span>
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
      ) : meId ? (
        <form className="flex gap-2 border-t border-line p-3" onSubmit={(e) => { e.preventDefault(); send(); }}>
          <input className="input" value={text} onChange={(e) => setText(e.target.value)} placeholder={placeholder} maxLength={2000} aria-label="الرسالة" />
          <button className="btn-primary" disabled={sending || !text.trim()}>إرسال</button>
        </form>
      ) : null}
      {err && <p className="px-3 pb-2 text-xs text-primary" role="alert">{err}</p>}
    </div>
  );
}
