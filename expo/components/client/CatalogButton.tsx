"use client";
import { useState } from "react";
import { functionsUrl, loginUrl } from "@/lib/env";
import { authHeaders } from "@/components/client/useSession";
import { ConsentBox } from "@/components/client/ConsentBox";

export function CatalogButton({ mediaId, title, gated, signedIn, hasConsent }: {
  mediaId: string; title: string; gated: boolean; signedIn: boolean; hasConsent: boolean;
}) {
  const [asking, setAsking] = useState(false);
  const [consent, setConsent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function download(withConsent: boolean) {
    setBusy(true); setErr(null);
    const res = await fetch(`${functionsUrl}/expo-catalog`, {
      method: "POST", headers: await authHeaders(), body: JSON.stringify({ media_id: mediaId, consent: withConsent }),
    });
    setBusy(false);
    if (res.status === 412) { setAsking(true); return; }
    if (!res.ok) { setErr("تعذر تنزيل الملف الآن."); return; }
    const { url } = await res.json();
    window.open(url, "_blank", "noopener");
    setAsking(false);
  }

  return (
    <div className="card flex flex-col gap-3 p-4">
      <div className="flex items-center gap-3">
        <span className="grid h-11 w-11 place-items-center rounded-lg bg-tint font-heading text-xs font-bold text-primary">PDF</span>
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{title}</p>
          {gated && <p className="text-xs text-muted">يتطلب مشاركة بيانات التواصل مع العارض</p>}
        </div>
        <button className="btn-ghost btn-sm" disabled={busy} onClick={() => {
          if (gated && !signedIn) { location.href = loginUrl(location.pathname); return; }
          if (gated && !hasConsent) { setAsking(true); return; }
          download(false);
        }}>{busy ? "…" : "تنزيل"}</button>
      </div>
      {asking && (
        <div className="flex flex-col gap-2">
          <ConsentBox checked={consent} onChange={setConsent} />
          <button className="btn-primary btn-sm" disabled={!consent || busy} onClick={() => download(true)}>موافق، نزّل الكتالوج</button>
        </div>
      )}
      {err && <p className="text-xs text-primary">{err}</p>}
    </div>
  );
}
