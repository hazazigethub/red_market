'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

export default function RegisterPage() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [gender, setGender] = useState<'male' | 'female'>('male');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [agreed, setAgreed] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // مرحلة التحقّق — تظهر بعد إنشاء الحساب
  const [stage, setStage] = useState<'form' | 'otp'>('form');
  const [otp, setOtp] = useState('');
  const [otpError, setOtpError] = useState<string | null>(null);
  const [verifying, setVerifying] = useState(false);
  const [resendIn, setResendIn] = useState(0);

  // البريد أو الجوال مسجّل — نقود المستخدم بدل أن نتركه
  const [taken, setTaken] = useState<'email' | 'phone' | null>(null);

  // مؤقّت إعادة الإرسال
  useEffect(() => {
    if (resendIn <= 0) return;
    const t = setTimeout(() => setResendIn((v) => v - 1), 1000);
    return () => clearTimeout(t);
  }, [resendIn]);

  async function handleRegister(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!agreed) {
      setError('يرجى الموافقة على الشروط والأحكام');
      return;
    }
    if (password.trim() !== confirm.trim()) {
      setError('كلمتا المرور غير متطابقتين');
      return;
    }
    if (password.trim().length < 6) {
      setError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (!/^[\w.\-+]+@[\w\-]+(\.[\w\-]+)+$/.test(email.trim())) {
      setError('بريد إلكتروني غير صحيح');
      return;
    }

    setLoading(true);
    setTaken(null);

    try {
      const clean = phone.replace(/\D/g, '');

      // فحص مسبق — فالتسجيل المكرّر يفشل صامتاً في Supabase
      const { data: avail } = await supabaseBrowser.rpc(
        'check_signup_availability',
        { p_email: email.trim().toLowerCase(), p_phone: clean }
      );

      if (avail?.email_taken) {
        setTaken('email');
        return;
      }
      if (avail?.phone_taken) {
        setTaken('phone');
        return;
      }

      // البيانات تُمرَّر للمشغّل — فلا جلسة قبل التأكيد
      const { error: authError } = await supabaseBrowser.auth.signUp({
        email: email.trim().toLowerCase(),
        password: password.trim(),
        options: {
          data: {
            role: 'customer',
            full_name: name.trim(),
            phone_number: clean,
            gender,
          },
        },
      });

      if (authError) {
        setError(
          authError.message.includes('already')
            ? 'هذا الرقم مسجّل مسبقاً'
            : 'تعذر إنشاء الحساب، حاول مجدداً'
        );
        return;
      }

      setStage('otp');
      setResendIn(60);
    } catch {
      setError('تعذر الاتصال، تحقق من الشبكة');
    } finally {
      setLoading(false);
    }
  }

  /// التحقّق من الرمز — ينشئ الجلسة عند نجاحه
  async function handleVerify(e: React.FormEvent) {
    e.preventDefault();
    setOtpError(null);

    const code = otp.replace(/\D/g, '');
    if (code.length !== 6) {
      setOtpError('أدخل الرمز المكوّن من ستة أرقام');
      return;
    }

    setVerifying(true);
    try {
      const { error: vErr } = await supabaseBrowser.auth.verifyOtp({
        email: email.trim().toLowerCase(),
        token: code,
        type: 'signup',
      });

      if (vErr) {
        setOtpError('الرمز غير صحيح أو منتهي الصلاحية');
        return;
      }

      // اختيار التصنيفات المفضّلة بعد التأكيد
      router.push('/interests');
      router.refresh();
    } catch {
      setOtpError('تعذر الاتصال، تحقق من الشبكة');
    } finally {
      setVerifying(false);
    }
  }

  /// إعادة إرسال الرمز
  async function handleResend() {
    if (resendIn > 0) return;
    setOtpError(null);
    try {
      const { error: rErr } = await supabaseBrowser.auth.resend({
        type: 'signup',
        email: email.trim().toLowerCase(),
      });
      if (rErr) {
        setOtpError('تعذر إعادة الإرسال، حاول بعد قليل');
        return;
      }
      setResendIn(60);
    } catch {
      setOtpError('تعذر الاتصال، تحقق من الشبكة');
    }
  }

  // ظاهر ⇒ عين · مخفي ⇒ عين مشطوبة
  const eyeIcon = showPassword ? (
    <svg
      className="w-5 h-5"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.7}
      viewBox="0 0 24 24"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  ) : (
    <svg
      className="w-5 h-5"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.7}
      viewBox="0 0 24 24"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24M1 1l22 22" />
    </svg>
  );

  // ===== الحساب مسجّل مسبقاً =====
  if (taken) {
    return (
      <main className="max-w-md mx-auto px-4 py-14">
        <div className="bg-white border border-gray-200 rounded-2xl p-8 text-center">
          <Image
            src="/logo.png"
            alt="رد ماركت"
            width={64}
            height={64}
            className="mx-auto object-contain"
          />

          <h1 className="text-xl font-bold mt-5" style={{ color: BRAND }}>
            {taken === 'email' ? 'هذا البريد مسجّل' : 'هذا الجوال مسجّل'}
          </h1>

          <p className="text-sm text-gray-600 mt-3 leading-7">
            {taken === 'email' ? (
              <>
                يوجد حساب على
                <br />
                <span className="font-bold text-gray-800" dir="ltr">
                  {email.trim().toLowerCase()}
                </span>
                <br />
                سجّل دخولك، أو استعد كلمة المرور إن نسيتها.
              </>
            ) : (
              <>
                رقم الجوال مرتبط بحساب آخر.
                <br />
                سجّل دخولك، أو استخدم رقماً مختلفاً.
              </>
            )}
          </p>

          <button
            onClick={() => router.push('/login')}
            className="w-full mt-6 py-3 rounded-lg text-white font-bold hover:opacity-90 transition-opacity"
            style={{ backgroundColor: BRAND }}
          >
            تسجيل الدخول
          </button>

          <button
            onClick={() => router.push('/forgot-password')}
            className="w-full mt-3 py-2.5 rounded-lg border border-gray-300 font-bold text-gray-700 hover:bg-gray-50 transition-colors"
          >
            نسيت كلمة المرور
          </button>

          <button
            onClick={() => setTaken(null)}
            className="mt-4 text-sm text-gray-500 hover:text-gray-700"
          >
            تعديل البيانات
          </button>
        </div>
      </main>
    );
  }

  // ===== شاشة التحقّق =====
  if (stage === 'otp') {
    return (
      <main className="max-w-md mx-auto px-4 py-14">
        <div className="bg-white border border-gray-200 rounded-2xl p-8 text-center">
          <Image
            src="/logo.png"
            alt="رد ماركت"
            width={64}
            height={64}
            className="mx-auto object-contain"
          />

          <h1 className="text-2xl font-bold mt-5" style={{ color: BRAND }}>
            تأكيد بريدك
          </h1>

          <p className="text-sm text-gray-600 mt-3 leading-7">
            أرسلنا رمزاً من ستة أرقام إلى
            <br />
            <span className="font-bold text-gray-800" dir="ltr">
              {email.trim().toLowerCase()}
            </span>
          </p>

          <form onSubmit={handleVerify} className="mt-7">
            <input
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
              dir="ltr"
              placeholder="000000"
              className="w-full text-center tracking-[0.5em] text-2xl font-bold border border-gray-300 rounded-xl px-4 py-3 outline-none focus:border-red-400"
            />

            {otpError && (
              <p className="text-red-600 text-sm mt-3">{otpError}</p>
            )}

            <button
              type="submit"
              disabled={verifying}
              className="w-full mt-5 py-3 rounded-lg text-white font-bold disabled:opacity-60 hover:opacity-90 transition-opacity"
              style={{ backgroundColor: BRAND }}
            >
              {verifying ? 'جارٍ التحقّق...' : 'تأكيد'}
            </button>
          </form>

          <button
            onClick={handleResend}
            disabled={resendIn > 0}
            className="mt-4 text-sm font-bold disabled:text-gray-400"
            style={{ color: resendIn > 0 ? undefined : BRAND }}
          >
            {resendIn > 0
              ? `إعادة الإرسال بعد ${resendIn} ثانية`
              : 'إعادة إرسال الرمز'}
          </button>

          <p className="text-xs text-gray-500 mt-5 leading-6">
            لم تجد الرسالة؟ تحقّق من مجلد البريد المزعج.
          </p>
        </div>
      </main>
    );
  }

  // ===== نموذج التسجيل =====
  return (
    <main className="max-w-md mx-auto px-4 py-14">
      <div className="bg-white border border-gray-200 rounded-2xl p-8">
        {/* ===== الشعار ===== */}
        <div className="text-center">
          <Image
            src="/logo.png"
            alt="رد ماركت"
            width={64}
            height={64}
            className="mx-auto object-contain"
          />
          <h1 className="text-2xl font-bold mt-5" style={{ color: BRAND }}>
            أنشئ حسابك
          </h1>
          <p className="text-sm text-gray-500 mt-2">
            احفظ عروضك المفضلة وتابع متاجرك
          </p>
        </div>

        <form onSubmit={handleRegister} className="mt-8 space-y-4">
          <div>
            <label className="block text-sm mb-1.5 text-gray-700">الاسم</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder="اسمك"
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400"
            />
          </div>

          {/* ===== الجنس ===== */}
          <div>
            <label className="block text-sm mb-1.5 text-gray-700">الجنس</label>
            <div className="grid grid-cols-2 gap-3">
              {(
                [
                  { v: 'male', label: 'ذكر', color: '#2563eb' },
                  { v: 'female', label: 'أنثى', color: '#db2777' },
                ] as const
              ).map((g) => {
                const on = gender === g.v;
                return (
                  <button
                    key={g.v}
                    type="button"
                    onClick={() => setGender(g.v)}
                    aria-pressed={on}
                    aria-label={g.label}
                    title={g.label}
                    className="flex flex-col items-center gap-1 py-3 rounded-xl border-2 transition-colors"
                    style={{
                      borderColor: on ? g.color : '#d1d5db',
                      backgroundColor: on ? `${g.color}1A` : 'transparent',
                      color: on ? g.color : '#9ca3af',
                    }}
                  >
                    <Image
                      src={g.v === 'male' ? '/man.svg' : '/woman.svg'}
                      alt=""
                      width={56}
                      height={56}
                      className="w-14 h-14"
                    />
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <label className="block text-sm mb-1.5 text-gray-700">
              رقم الجوال
            </label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
              placeholder="05xxxxxxxx"
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400"
            />
          </div>

          <div>
            <label className="block text-sm mb-1.5 text-gray-700">
              البريد الإلكتروني
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              dir="ltr"
              placeholder="name@example.com"
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400"
            />
            <p className="mt-1.5 text-xs text-gray-500">
              يُستخدم لاستعادة كلمة المرور — تأكد من صحته
            </p>
          </div>

          <div>
            <label className="block text-sm mb-1.5 text-gray-700">
              كلمة المرور
            </label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                placeholder="6 أحرف على الأقل"
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 pl-11 outline-none focus:border-red-400"
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                aria-label={
                  showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور'
                }
                className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-600"
              >
                {eyeIcon}
              </button>
            </div>
          </div>

          <div>
            <label className="block text-sm mb-1.5 text-gray-700">
              تأكيد كلمة المرور
            </label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                required
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 pl-12 outline-none focus:border-red-400"
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                aria-label={
                  showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور'
                }
                className="absolute left-1 top-1/2 -translate-y-1/2 w-11 h-11 flex items-center justify-center text-gray-500 hover:text-gray-700"
              >
                {eyeIcon}
              </button>
            </div>
          </div>

          {/* ===== الموافقة على الشروط ===== */}
          <label className="flex items-start gap-2.5 cursor-pointer pt-1">
            <input
              type="checkbox"
              checked={agreed}
              onChange={(e) => setAgreed(e.target.checked)}
              className="mt-0.5 w-4 h-4 accent-red-700 shrink-0"
            />
            <span className="text-sm text-gray-600 leading-6">
              أوافق على{' '}
              <Link
                href="/terms"
                target="_blank"
                className="font-bold underline"
                style={{ color: BRAND }}
              >
                الشروط والأحكام
              </Link>{' '}
              و{' '}
              <Link
                href="/privacy"
                target="_blank"
                className="font-bold underline"
                style={{ color: BRAND }}
              >
                سياسة الخصوصية
              </Link>
            </span>
          </label>

          <button
            type="submit"
            disabled={loading}
            className="w-full text-white font-bold py-3 rounded-lg disabled:opacity-60 hover:opacity-90 transition-opacity"
            style={{ backgroundColor: BRAND }}
          >
            {loading ? 'جاري الإنشاء...' : 'إنشاء الحساب'}
          </button>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3">
              <p className="text-center text-sm text-red-600">{error}</p>
            </div>
          )}
        </form>

        <p className="text-center text-sm text-gray-500 mt-6">
          لديك حساب؟{' '}
          <Link href="/login" className="font-bold" style={{ color: BRAND }}>
            سجّل الدخول
          </Link>
        </p>
      </div>
    </main>
  );
}
