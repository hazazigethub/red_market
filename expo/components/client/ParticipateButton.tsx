"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { arabicError } from "@/lib/errors";
import { fmtDate } from "@/lib/format";
import { expoBrowser } from "@/lib/supabase/client";

type Check = { status: "ok" | "not_covering" | "expired" | "none" | "full" | "joined"; expires_at?: string | null; exhibition_ends_at?: string };

function message(c: Check): { title: string; body: string } {
  if (c.status === "full") {
    return {
      title: "اكتمل عدد الأجنحة",
      body: "اكتمل عدد الأجنحة المتاحة في هذا المعرض. تابع معارض Red Market القادمة للمشاركة فيها.",
    };
  }
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

/** "Participate" button: checks subscription + capacity at click time, shows the price,
 *  then pays (free / 100% code) and creates the booth immediately. */
export function ParticipateButton({ exhibitionId, merchantId }: { exhibitionId: string; merchantId: string }) {
  const router = useRouter();
  const [checking, setChecking] = useState(false);
  const [popup, setPopup] = useState<{ title: string; body: string } | null>(null);
  const [offer, setOffer] = useState<{ free: boolean; fee: number } | null>(null);
  const [code, setCode] = useState("");
  const [joining, setJoining] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const okRef = useRef<HTMLButtonElement>(null);

  async function click() {
    setChecking(true);
    const { data, error } = await expoBrowser().rpc("check_participation", { p_exhibition: exhibitionId, p_merchant: merchantId });
    setChecking(false);
    if (error) { setPopup({ title: "تعذر التحقق", body: arabicError(error.message) }); return; }
    const c = data as Check & { free?: boolean; fee?: number };
    if (c.status === "joined") {
      setPopup({ title: "أنت مشارك في هذا المعرض", body: "جناحك جاهز. ادخل «أجنحتي» لإكمال بنائه." });
      return;
    }
    if (c.status === "ok") { setErr(null); setCode(""); setOffer({ free: !!c.free, fee: Number(c.fee ?? 0) }); return; }
    setPopup(message(c));
    setTimeout(() => okRef.current?.focus(), 0);
  }

  async function join() {
    setJoining(true); setErr(null);
    const { data, error } = await expoBrowser().rpc("join_exhibition", {
      p_exhibition: exhibitionId, p_merchant: merchantId, p_promo_code: code.trim() || null,
    });
    setJoining(false);
    if (error) { setErr(arabicError(error.message)); return; }
    router.push(`/merchant/booths/${(data as { booth_id: string }).booth_id}/edit`);
  }

  return (
    <>
      <button type="button" className="btn-primary btn-sm" disabled={checking} onClick={click}>
        {checking ? "جارٍ التحقق…" : "المشاركة في المعرض"}
      </button>

      {offer && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-ink/50 p-4" onClick={() => !joining && setOffer(null)}>
          <div role="dialog" aria-modal="true" aria-labelledby="join-title"
            className="w-full max-w-md rounded-2xl bg-surface p-6 shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <h2 id="join-title" className="font-heading text-xl font-extrabold">المشاركة في المعرض</h2>
            {offer.free ? (
              <p className="mt-3 rounded-[10px] bg-tint p-3 text-sm leading-7">
                مشاركتك <b>مجانية</b> ضمن باقتك الاحترافية السنوية.
              </p>
            ) : (
              <>
                <p className="mt-3 text-sm text-muted">رسوم المشاركة</p>
                <p className="font-heading text-3xl font-extrabold">{offer.fee} <span className="text-base">ريال</span></p>
                <label className="label mt-4" htmlFor={`code-${exhibitionId}`}>كود الدفع</label>
                <input id={`code-${exhibitionId}`} className="input" dir="ltr" value={code}
                  onChange={(e) => setCode(e.target.value)} autoComplete="off" />
              </>
            )}
            {err && <p role="alert" className="mt-3 text-sm text-primary">{err}</p>}
            <div className="mt-6 flex gap-2">
              <button className="btn-primary flex-1" disabled={joining || (!offer.free && offer.fee > 0 && !code.trim())} onClick={join}>
                {joining ? "جارٍ التسجيل…" : "تأكيد المشاركة"}
              </button>
              <button className="btn-ghost" disabled={joining} onClick={() => setOffer(null)}>إلغاء</button>
            </div>
          </div>
        </div>
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
