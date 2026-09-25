"use client";
export const CONSENT_TEXT =
  "أوافق على مشاركة اسمي ووسائل التواصل الخاصة بي مع هذا العارض للتواصل معي بخصوص استفساري، وفق نظام حماية البيانات الشخصية.";

export function ConsentBox({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="flex cursor-pointer items-start gap-2.5 rounded-[10px] bg-bg p-3 text-xs leading-relaxed text-muted">
      <input type="checkbox" className="mt-0.5 h-4 w-4 accent-[#C21815]" checked={checked}
        onChange={(e) => onChange(e.target.checked)} />
      <span>{CONSENT_TEXT}</span>
    </label>
  );
}
