const MAP: Record<string, string> = {
  AUTH_REQUIRED: "سجّل الدخول بحساب Red Market للمتابعة.",
  CONSENT_REQUIRED: "يلزم موافقتك على مشاركة بيانات التواصل مع العارض.",
  BANNED: "تم تقييد حسابك في هذا المعرض.",
  CHAT_CLOSED: "المحادثة غير متاحة حالياً في هذا المعرض.",
  OWN_BOOTH: "لا يمكنك مراسلة جناحك.",
  RATE_LIMITED: "انتظر لحظة قبل إرسال رسالة أخرى.",
  SESSION_FULL: "اكتمل العدد في هذه الجلسة.",
  SESSION_CLOSED: "انتهى التسجيل في هذه الجلسة.",
  PRODUCT_NOT_IN_STORE: "المنتج لا يتبع متجرك.",
  ORGANIZER_NOT_VERIFIED: "لا يمكن نشر المعرض قبل توثيق حساب المنظم من إدارة المنصة.",
  INVALID_STATUS_TRANSITION: "لا يمكن الانتقال إلى هذه الحالة الآن.",
  USER_NOT_FOUND: "لا يوجد حساب Red Market بهذا البريد.",
  LAST_OWNER: "يجب أن يبقى للجناح مالك واحد على الأقل.",
  ALREADY_REVIEWED: "تمت مراجعة هذا الطلب مسبقاً.",
  APPLICATIONS_CLOSED: "التقديم على هذا المعرض مغلق.",
  ALREADY_APPLIED: "لديك طلب مشاركة سابق في هذا المعرض.",
  STORE_SUSPENDED: "مشاركة متجرك في المعارض موقوفة من إدارة المنصة.",
  STORE_UNAVAILABLE: "المتجر غير متاح في Red Market حالياً.",
  SUBSCRIPTION_REQUIRED: "المشاركة في المعارض متاحة للمتاجر المشتركة فقط.",
  SUBSCRIPTION_EXPIRED: "انتهى اشتراك المتجر. يلزم تجديده للمشاركة.",
  SUBSCRIPTION_NOT_COVERING: "اشتراك المتجر ينتهي قبل نهاية المعرض، فلا يمكن قبوله حتى يجدّد.",
  EXHIBITION_FULL: "اكتمل عدد الأجنحة في هذا المعرض.",
  FORBIDDEN: "ليست لديك صلاحية لهذا الإجراء.",
  "row-level security": "ليست لديك صلاحية لهذا الإجراء.",
  duplicate: "هذا العنصر موجود مسبقاً.",
};

export function arabicError(message: string | undefined | null): string {
  if (!message) return "حدث خطأ غير متوقع. حاول مرة أخرى.";
  for (const [k, v] of Object.entries(MAP)) if (message.includes(k)) return v;
  return "حدث خطأ غير متوقع. حاول مرة أخرى.";
}
