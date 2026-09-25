"use client";
import { useRef, useState } from "react";
import { arabicError } from "@/lib/errors";
import { BOOTH_TIER, fmtDate } from "@/lib/format";
import { expoBrowser } from "@/lib/supabase/client";

type Check = { status: "ok" | "not_covering" | "expired" | "none"; expires_at?: string | null; exhibition_ends_at?: string };

function message(c: Check): { title: string; body: string } {
  if (c.status === "expired") {
    return {
      title: "انتهى اشتراكك",
      body: `انتهى اشتراك متجرك${c.expires_at ? ` بتاريخ ${fmtDate(c.expires_at)}` : ""}. جدّد اشتراكك في Red Market لتتمكن من التقديم على المعارض.`,
    };
  }
  if (c.status === "not_covering") {
    return {
      title: "اشتراكك لا يغطي فترة المعرض",
      body: `ينتهي اشتراك متجرك بتاريخ ${fmtDate(c.expires_at!)}، قبل نهاية هذا المعرض بتاريخ ${fmtDate(c.exhibition_ends_at!)}. جدّد اشتراكك لتتمكن من المشاركة.`,
    };
  }
  return {
    title: "الاشتراك مطلوب",
    body: "المشاركة في معارض Red Market متاحة للمتاجر المشتركة فقط. اشترك في إحدى باقات Red Market لتتمكن من التقديم على المعارض.",
  };
}

/** "Participate" button: checks the paid subscription at click time, then opens the form or a popup. */
export function ParticipateButton({ exhibitionId, merchantId, action }: {
  exhibitionId: string; merchantId: string; action: (form: FormData) => Promise<void>;
}) {
  const [state, setState] = useState<"idle" | "checking" | "form">("idle");
  const [popup, setPopup] = useState<{ title: string; body: string } | null>(null);
  const okRef = useRef<HTMLButtonElement>(null);

  async function click() {
    setState("checking");
    const { data, error } = await expoBrowser().rpc("check_participation", { p_exhibition: exhibitionId, p_merchant: merchantId });
    if (error) { setState("idle"); setPopup({ title: "تعذر التحقق", body: arabicError(error.message) }); return; }
    const c = data as Check;
    if (c.status === "ok") { setState("form"); return; }
    setState("idle");
    setPopup(message(c));
    setTimeout(() => okRef.current?.focus(), 0);
  }

  return (
    <>
      {state !== "form" ? (
        <button type="button" className="btn-primary btn-sm" disabled={state === "checking"} onClick={click}>
          {state === "checking" ? "جارٍ التحقق…" : "المشاركة في المعرض"}
        </button>
      ) : (
        <form action={action} className="mt-4 flex w-full flex-col gap-3 border-t border-line pt-4">
          <input type="hidden" name="exhibition_id" value={exhibitionId} />
          <input type="hidden" name="merchant_id" value={merchantId} />
          <div><label className="label" htmlFor={`tier-${exhibitionId}`}>نوع الجناح المطلوب</label>
            <select id={`tier-${exhibitionId}`} name="tier" className="input">
              {Object.entries(BOOTH_TIER).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </select></div>
          <div><label className="label" htmlFor={`msg-${exhibitionId}`}>رسالة للمنظم</label>
            <textarea id={`msg-${exhibitionId}`} name="message" rows={3} className="input" maxLength={2000} /></div>
          <div className="flex gap-2">
            <button className="btn-primary">إرسال الطلب</button>
            <button type="button" className="btn-ghost" onClick={() => setState("idle")}>إلغاء</button>
          </div>
        </form>
      )}

      {popup && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-ink/50 p-4" onClick={() => setPopup(null)}>
          <div role="alertdialog" aria-modal="true" aria-labelledby="sub-title" aria-describedby="sub-body"
            className="w-full max-w-md rounded-2xl bg-surface p-6 text-center shadow-2xl" onClick={(e) => e.stopPropagation()}
            onKeyDown={(e) => e.key === "Escape" && setPopup(null)}>
            <span className="mx-auto mb-4 grid h-12 w-12 place-items-center rounded-full bg-tint font-heading text-xl font-extrabold text-primary" aria-hidden>!</span>
            <h2 id="sub-title" className="font-heading text-xl font-extrabold">{popup.title}</h2>
            <p id="sub-body" className="mt-2 text-sm leading-7 text-muted">{popup.body}</p>
            <button ref={okRef} className="btn-primary mt-6 w-full" onClick={() => setPopup(null)}>حسناً</button>
          </div>
        </div>
      )}
    </>
  );
}
