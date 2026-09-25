"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabaseBrowser } from "@/lib/supabase/client";

/** Reached from the password-reset email (via /auth/callback, which opens a recovery session). */
export default function ResetPassword() {
  const router = useRouter();
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  return (
    <div className="container-x max-w-md py-16">
      <form className="card flex flex-col gap-4 p-6 sm:p-8" onSubmit={async (e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        const password = String(f.get("password"));
        if (password.length < 8) return setErr("استخدم 8 أحرف على الأقل.");
        if (password !== String(f.get("confirm"))) return setErr("كلمتا المرور غير متطابقتين.");
        setBusy(true); setErr(null);
        const { error } = await supabaseBrowser().auth.updateUser({ password });
        setBusy(false);
        if (error) return setErr("انتهت صلاحية الرابط. اطلب رابطاً جديداً من صفحة الدخول.");
        router.replace("/me");
        router.refresh();
      }}>
        <h1 className="font-heading text-2xl font-extrabold">كلمة مرور جديدة</h1>
        <div><label className="label" htmlFor="p1">كلمة المرور</label><input id="p1" name="password" type="password" className="input" dir="ltr" required autoComplete="new-password" /></div>
        <div><label className="label" htmlFor="p2">تأكيدها</label><input id="p2" name="confirm" type="password" className="input" dir="ltr" required autoComplete="new-password" /></div>
        {err && <p role="alert" className="text-sm text-primary">{err}</p>}
        <button className="btn-primary" disabled={busy}>{busy ? "…" : "حفظ"}</button>
      </form>
    </div>
  );
}
