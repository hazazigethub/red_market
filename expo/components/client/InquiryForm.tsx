"use client";
import { useState } from "react";
import { loginUrl } from "@/lib/env";
import { arabicError } from "@/lib/errors";
import { expoBrowser } from "@/lib/supabase/client";
import { ConsentBox } from "@/components/client/ConsentBox";

export function InquiryForm({ boothId, signedIn, defaultName }: { boothId: string; signedIn: boolean; defaultName?: string }) {
  const [consent, setConsent] = useState(false);
  const [state, setState] = useState<"idle" | "sending" | "sent">("idle");
  const [err, setErr] = useState<string | null>(null);

  if (!signedIn) {
    return (
      <a href={loginUrl(typeof location !== "undefined" ? location.pathname : "/")} className="btn-primary w-full">
        سجّل الدخول لإرسال استفسار
      </a>
    );
  }
  if (state === "sent") {
    return <p className="rounded-[10px] bg-tint p-4 text-sm">وصل استفسارك إلى العارض، وسيتواصل معك قريباً.</p>;
  }
  return (
    <form className="flex flex-col gap-3" onSubmit={async (e) => {
      e.preventDefault();
      const f = new FormData(e.currentTarget);
      if (!f.get("phone") && !f.get("email")) return setErr("أدخل رقم الجوال أو البريد الإلكتروني.");
      setErr(null); setState("sending");
      const { error } = await expoBrowser().rpc("capture_lead", {
        p_booth: boothId, p_source: "inquiry_form", p_consent: consent,
        p_full_name: f.get("name"), p_phone: f.get("phone"), p_email: f.get("email"),
        p_company: f.get("company"), p_message: f.get("message"),
      });
      if (error) { setErr(arabicError(error.message)); setState("idle"); return; }
      setState("sent");
    }}>
      <div><label className="label" htmlFor="iq-name">الاسم</label><input id="iq-name" name="name" className="input" defaultValue={defaultName} required /></div>
      <div className="grid grid-cols-2 gap-3">
        <div><label className="label" htmlFor="iq-phone">الجوال</label><input id="iq-phone" name="phone" className="input" inputMode="tel" dir="ltr" /></div>
        <div><label className="label" htmlFor="iq-email">البريد</label><input id="iq-email" name="email" type="email" className="input" dir="ltr" /></div>
      </div>
      <div><label className="label" htmlFor="iq-company">الشركة (اختياري)</label><input id="iq-company" name="company" className="input" /></div>
      <div><label className="label" htmlFor="iq-msg">استفسارك</label><textarea id="iq-msg" name="message" rows={3} className="input" required maxLength={2000} /></div>
      <ConsentBox checked={consent} onChange={setConsent} />
      {err && <p className="text-sm text-primary" role="alert">{err}</p>}
      <button className="btn-primary" disabled={!consent || state === "sending"}>
        {state === "sending" ? "جارٍ الإرسال…" : "أرسل الاستفسار"}
      </button>
    </form>
  );
}
