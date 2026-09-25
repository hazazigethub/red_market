const TZ = "Asia/Riyadh";

export function fmtDate(iso: string, tz = TZ) {
  return new Intl.DateTimeFormat("ar-SA-u-nu-latn-ca-gregory", {
    day: "numeric", month: "long", year: "numeric", timeZone: tz,
  }).format(new Date(iso));
}
export function fmtDay(iso: string, tz = TZ) {
  return new Intl.DateTimeFormat("ar-SA-u-nu-latn-ca-gregory", {
    weekday: "long", day: "numeric", month: "long", timeZone: tz,
  }).format(new Date(iso));
}
export function fmtTime(iso: string, tz = TZ) {
  return new Intl.DateTimeFormat("ar-SA-u-nu-latn", { hour: "numeric", minute: "2-digit", timeZone: tz })
    .format(new Date(iso));
}
export function fmtDateTime(iso: string, tz = TZ) {
  return `${fmtDate(iso, tz)} · ${fmtTime(iso, tz)}`;
}
export function fmtNum(n: number | null | undefined) {
  return new Intl.NumberFormat("en-US", { notation: (n ?? 0) >= 10000 ? "compact" : "standard" }).format(n ?? 0);
}
export function fmtMoney(n: number | null | undefined) {
  if (n == null) return "";
  return new Intl.NumberFormat("ar-SA-u-nu-latn", { style: "currency", currency: "SAR", maximumFractionDigits: 2 })
    .format(n);
}
export function timeAgo(iso: string) {
  const s = Math.round((Date.now() - new Date(iso).getTime()) / 1000);
  const rtf = new Intl.RelativeTimeFormat("ar-u-nu-latn", { numeric: "auto" });
  if (s < 60) return rtf.format(-s, "second");
  if (s < 3600) return rtf.format(-Math.round(s / 60), "minute");
  if (s < 86400) return rtf.format(-Math.round(s / 3600), "hour");
  return rtf.format(-Math.round(s / 86400), "day");
}
/** "2026-10-12T10:00" typed in Riyadh time -> ISO (Riyadh is UTC+3 all year). */
export function riyadhLocalToIso(v: string) {
  return new Date(`${v}:00+03:00`).toISOString();
}
/** ISO -> value for <input type="datetime-local"> in Riyadh time. */
export function isoToRiyadhLocal(iso: string) {
  const d = new Date(new Date(iso).getTime() + 3 * 3600 * 1000);
  return d.toISOString().slice(0, 16);
}
export function dayKey(iso: string, tz = TZ) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: tz }).format(new Date(iso));
}

export const EXHIBITION_STATUS: Record<string, string> = {
  draft: "مسودة", scheduled: "مجدول", live: "مباشر الآن", ended: "انتهى", archived: "مؤرشف",
};
export const LEAD_STATUS: Record<string, string> = {
  new: "جديد", contacted: "تم التواصل", qualified: "مؤهل", negotiation: "تفاوض", won: "تم البيع", lost: "لم يتم",
};
export const LEAD_SOURCE: Record<string, string> = {
  inquiry_form: "نموذج استفسار", chat: "محادثة", catalog_download: "تنزيل كتالوج",
  stream: "بث مباشر", product_interest: "اهتمام بمنتج", qr: "رمز QR",
};
export const SESSION_TYPE: Record<string, string> = {
  keynote: "كلمة رئيسية", panel: "جلسة حوارية", workshop: "ورشة عمل", talk: "محاضرة",
};
export const SPONSOR_TIER: Record<string, string> = {
  platinum: "الراعي البلاتيني", gold: "الراعي الذهبي", silver: "الراعي الفضي", partner: "الشركاء",
};
export const BOOTH_TIER: Record<string, string> = { standard: "أساسي", premium: "مميز", sponsor: "راعٍ" };
export const ROLE: Record<string, string> = { owner: "المالك", manager: "مدير", agent: "موظف مبيعات" };
