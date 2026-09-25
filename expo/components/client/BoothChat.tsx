"use client";
import { useState } from "react";
import { loginUrl } from "@/lib/env";
import { arabicError } from "@/lib/errors";
import { expoBrowser } from "@/lib/supabase/client";
import { ChatPanel } from "@/components/client/ChatPanel";
import { ConsentBox } from "@/components/client/ConsentBox";

export function BoothChat({ boothId, boothName, exhibitionId, meId, existingChatId, hasConsent, enabled, label = "محادثة العارض" }: {
  boothId: string; boothName: string; exhibitionId: string; meId: string | null; existingChatId: string | null;
  hasConsent: boolean; enabled: boolean; label?: string;
}) {
  const [open, setOpen] = useState(false);
  const [chatId, setChatId] = useState<string | null>(existingChatId);
  const [consent, setConsent] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (!enabled) return null;

  async function start() {
    setBusy(true); setErr(null);
    const db = expoBrowser();
    if (consent && !hasConsent) await db.rpc("set_contact_consent", { p_exhibition: exhibitionId, p_consent: true });
    const { data, error } = await db.rpc("start_booth_chat", { p_booth: boothId });
    setBusy(false);
    if (error) return setErr(arabicError(error.message));
    setChatId(data as string);
  }

  return (
    <>
      <button className="btn-primary" onClick={() => (meId ? setOpen(true) : (location.href = loginUrl(location.pathname)))}>{label}</button>
      {open && (
        <div className="fixed inset-0 z-50 flex justify-end bg-ink/40" onClick={() => setOpen(false)}>
          {/* drawer slides from the left edge in RTL */}
          <aside role="dialog" aria-modal="true" aria-label={`محادثة ${boothName}`}
            className="me-auto flex h-full w-full max-w-md flex-col bg-surface shadow-2xl sm:m-3 sm:h-[calc(100%-1.5rem)] sm:rounded-2xl"
            onClick={(e) => e.stopPropagation()}>
            <header className="flex items-center justify-between border-b border-line p-4">
              <div>
                <p className="font-heading font-bold">{boothName}</p>
                <p className="text-xs text-muted">عادةً يرد فريق الجناح خلال دقائق أثناء المعرض</p>
              </div>
              <button className="btn-ghost btn-sm" onClick={() => setOpen(false)} aria-label="إغلاق">إغلاق</button>
            </header>
            {chatId ? (
              <div className="min-h-0 flex-1"><ChatPanel chatId={chatId} meId={meId} /></div>
            ) : (
              <div className="flex flex-col gap-3 p-4">
                <p className="text-sm">ابدأ محادثة مباشرة مع فريق {boothName}.</p>
                {!hasConsent && <ConsentBox checked={consent} onChange={setConsent} />}
                {err && <p className="text-sm text-primary">{err}</p>}
                <button className="btn-primary" disabled={busy} onClick={start}>{busy ? "…" : "ابدأ المحادثة"}</button>
              </div>
            )}
          </aside>
        </div>
      )}
    </>
  );
}
