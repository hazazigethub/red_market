"use client";
import { ChatPanel } from "@/components/client/ChatPanel";

/** Stream chat for organizers: delete messages and ban users (24h) straight from the message. */
export function ModeratedChat({ chatId, meId, ban }: {
  chatId: string; meId: string; ban: (userId: string, hours: number | null) => Promise<void>;
}) {
  return (
    <ChatPanel chatId={chatId} meId={meId} canModerate compact
      onModerateUser={async (uid, name) => {
        if (!confirm(`حظر ${name || "هذا المستخدم"} من المعرض لمدة 24 ساعة؟`)) return;
        try { await ban(uid, 24); alert("تم الحظر."); } catch { alert("تعذر الحظر."); }
      }} />
  );
}
