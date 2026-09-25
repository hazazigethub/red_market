"use client";
import { Suspense, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { env } from "@/lib/env";
import { supabaseBrowser } from "@/lib/supabase/client";

type Mode = "signin" | "signup" | "forgot";

const AUTH_ERRORS: Record<string, string> = {
  "Invalid login credentials": "البريد أو كلمة المرور غير صحيحة.",
  "Email not confirmed": "لم يتم تأكيد بريدك بعد. افتح رسالة التأكيد في بريدك.",
  "User already registered": "هذا البريد مسجل مسبقاً. سجّل الدخول بدلاً من ذلك.",
  "Password should be at least": "كلمة المرور قصيرة. استخدم 8 أحرف على الأقل.",
  "rate limit": "محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.",
};
const authError = (m: string) =>
  Object.entries(AUTH_ERRORS).find(([k]) => m.includes(k))?.[1] ?? "تعذر إكمال العملية. حاول مرة أخرى.";

function safeNext(v: string | null) {
  return v && v.startsWith("/") && !v.startsWith("//") ? v : "/";
}

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));
  const [mode, setMode] = useState<Mode>("signin");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(params.get("expired") ? "انتهت صلاحية الرابط. سجّل الدخول أو اطلب رابطاً جديداً." : null);
  const [notice, setNotice] = useState<string | null>(null);

  if (env.authMode === "redmarket") {
    return (
      <p className="card p-5">تسجيل الدخول يتم عبر <a className="font-semibold text-primary" href={env.redmarketUrl}>Red Market</a>.</p>
    );
  }

  const callback = (to: string) => `${location.origin}/auth/callback?next=${encodeURIComponent(to)}`;

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const email = String(f.get("email") ?? "").trim();
    const password = String(f.get("password") ?? "");
    const sb = supabaseBrowser();
    setBusy(true); setErr(null); setNotice(null);
    try {
      if (mode === "signin") {
        const { error } = await sb.auth.signInWithPassword({ email, password });
        if (error) throw error;
        router.replace(next);
        router.refresh();
        return;
      }
      if (mode === "signup") {
        if (password.length < 8) throw new Error("Password should be at least");
        if (password !== String(f.get("confirm"))) { setErr("كلمتا المرور غير متطابقتين."); return; }
        // Keys match Red Market's public.handle_new_user(): full_name, phone_number.
        // "role" is never sent, so Expo sign-ups are always created as customers.
        const fullName = String(f.get("name") ?? "").trim();
        const phone = String(f.get("phone") ?? "").replace(/[\s-]/g, "");
        const { data, error } = await sb.auth.signUp({
          email, password,
          options: {
            data: { full_name: fullName, ...(phone ? { phone_number: phone } : {}), signup_source: "expo" },
            emailRedirectTo: callback(next),
          },
        });
        if (error) throw error;
        if (data.session) { router.replace(next); router.refresh(); return; }
        setNotice("أرسلنا رسالة تأكيد إلى بريدك. افتحها لتفعيل حسابك، ثم سجّل الدخول.");
        setMode("signin");
        return;
      }
      const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: callback("/auth/reset") });
      if (error) throw error;
      setNotice("إن كان البريد مسجلاً فستصلك رسالة لتعيين كلمة مرور جديدة.");
    } catch (x) {
      setErr(authError((x as Error).message));
    } finally {
      setBusy(false);
    }
  }

  const title = { signin: "تسجيل الدخول", signup: "إنشاء حساب", forgot: "استعادة كلمة المرور" }[mode];

  return (
    <div className="card flex flex-col gap-5 p-6 sm:p-8">
      <div>
        <h1 className="font-heading text-2xl font-extrabold">{title}</h1>
        <p className="mt-1 text-sm text-muted">
          {mode === "forgot" ? "أدخل بريدك وسنرسل لك رابط التعيين." : "بحساب Red Market نفسه. حساب واحد للتطبيق والمعارض."}
        </p>
      </div>

      {mode !== "forgot" && (
        <div className="grid grid-cols-2 rounded-[10px] bg-bg p-1 text-sm font-semibold" role="tablist">
          {(["signin", "signup"] as const).map((m) => (
            <button key={m} type="button" role="tab" aria-selected={mode === m}
              className={`rounded-lg py-2 ${mode === m ? "bg-surface shadow-sm" : "text-muted"}`}
              onClick={() => { setMode(m); setErr(null); setNotice(null); }}>
              {m === "signin" ? "دخول" : "حساب جديد"}
            </button>
          ))}
        </div>
      )}

      {notice && <p role="status" className="rounded-[10px] border border-success/30 bg-success/10 p-3 text-sm text-success">{notice}</p>}

      <form onSubmit={submit} className="flex flex-col gap-4" key={mode}>
        {mode === "signup" && (
          <>
            <div><label className="label" htmlFor="name">الاسم</label>
              <input id="name" name="name" className="input" required minLength={2} autoComplete="name" /></div>
            <div><label className="label" htmlFor="phone">رقم الجوال (اختياري)</label>
              <input id="phone" name="phone" type="tel" inputMode="tel" className="input" dir="ltr" placeholder="05XXXXXXXX"
                pattern="^(\+?966|0)?5\d{8}$" title="رقم جوال سعودي مثل 05XXXXXXXX" autoComplete="tel" />
              <p className="mt-1 text-xs text-muted">يسهّل على العارضين التواصل معك عند إرسال استفسار.</p></div>
          </>
        )}
        <div><label className="label" htmlFor="email">البريد الإلكتروني</label>
          <input id="email" name="email" type="email" className="input" required dir="ltr" autoComplete="email" /></div>
        {mode !== "forgot" && (
          <div>
            <div className="flex items-center justify-between">
              <label className="label" htmlFor="password">كلمة المرور</label>
              {mode === "signin" && (
                <button type="button" className="mb-1.5 text-xs text-muted hover:text-primary"
                  onClick={() => { setMode("forgot"); setErr(null); setNotice(null); }}>نسيت كلمة المرور؟</button>
              )}
            </div>
            <input id="password" name="password" type="password" className="input" required dir="ltr"
              minLength={mode === "signup" ? 8 : undefined} autoComplete={mode === "signup" ? "new-password" : "current-password"} />
          </div>
        )}
        {mode === "signup" && (
          <>
            <div><label className="label" htmlFor="confirm">تأكيد كلمة المرور</label>
              <input id="confirm" name="confirm" type="password" className="input" required dir="ltr" autoComplete="new-password" /></div>
            <label className="flex items-start gap-2 text-xs text-muted">
              <input type="checkbox" required className="mt-0.5 h-4 w-4 accent-[#C21815]" />
              <span>أوافق على شروط الاستخدام وسياسة الخصوصية في Red Market.</span>
            </label>
          </>
        )}
        {err && <p role="alert" className="text-sm text-primary">{err}</p>}
        <button className="btn-primary" disabled={busy}>
          {busy ? "…" : mode === "signin" ? "دخول" : mode === "signup" ? "إنشاء الحساب" : "أرسل الرابط"}
        </button>
        {mode === "forgot" && (
          <button type="button" className="text-sm text-muted hover:text-ink" onClick={() => setMode("signin")}>العودة لتسجيل الدخول</button>
        )}
      </form>
    </div>
  );
}

export default function LoginPage() {
  return (
    <div className="container-x flex max-w-md flex-col gap-4 py-12 sm:py-16">
      <Suspense fallback={<div className="card h-96" />}>
        <LoginForm />
      </Suspense>
      <p className="text-center text-xs text-muted">
        <Link href="/" className="hover:text-ink">العودة للمعارض</Link>
      </p>
    </div>
  );
}
