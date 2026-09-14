'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      // يجلب بريد المصادقة المرتبط بالجوال — حقيقياً كان أو مولّداً
      const digits = phone.replace(/\D/g, '');
      let email: string | null = null;

      const { data: found } = await supabaseBrowser.rpc('get_login_email', {
        p_phone: digits,
      });

      email = (found as string | null) ?? null;

      if (!email) {
        setError('لا يوجد حساب بهذا الرقم');
        return;
      }

      const { error: authError } = await supabaseBrowser.auth.signInWithPassword(
        {
          email,
          password: password.trim(),
        }
      );

      if (authError) {
        setError(
          authError.message.includes('Invalid login')
            ? 'رقم الجوال أو كلمة المرور غير صحيحة'
            : 'تعذر تسجيل الدخول، حاول مجدداً'
        );
        return;
      }

      router.push('/');
      router.refresh();
    } catch {
      setError('تعذر الاتصال، تحقق من الشبكة');
    } finally {
      setLoading(false);
    }
  }

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
          <h1
            className="text-2xl font-bold mt-5"
            style={{ color: BRAND }}
          >
            أهلاً بعودتك
          </h1>
          <p className="text-sm text-gray-500 mt-2">
            سجّل دخولك لمتابعة متاجرك المفضلة
          </p>
        </div>

        <form onSubmit={handleLogin} className="mt-8 space-y-4">
          <div>
            <label
              htmlFor="login-phone"
              className="block text-sm mb-1.5 text-gray-700"
            >
              رقم الجوال
            </label>
            <input
              id="login-phone"
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
              placeholder="05xxxxxxxx"
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400"
            />
          </div>

          <div>
            <label
              htmlFor="login-password"
              className="block text-sm mb-1.5 text-gray-700"
            >
              كلمة المرور
            </label>
            <div className="relative">
              <input
                id="login-password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 pl-11 outline-none focus:border-red-400"
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                aria-label={
                  showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور'
                }
                // مساحة لمس 44×44 — والأيقونة داخلها تبقى بحجمها
                className="absolute left-1 top-1/2 -translate-y-1/2 w-11 h-11 flex items-center justify-center text-gray-500 hover:text-gray-600"
              >
                {/* ظاهر ⇒ عين · مخفي ⇒ عين مشطوبة */}
                {showPassword ? (
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
                )}
              </button>
            </div>
          </div>

          <div className="text-left">
            <Link
              href="/forgot-password"
              className="text-xs text-gray-500 hover:text-gray-700"
            >
              نسيت كلمة المرور؟
            </Link>
          </div>


          <button
            type="submit"
            disabled={loading}
            className="w-full text-white font-bold py-3 rounded-lg disabled:opacity-60 hover:opacity-90 transition-opacity"
            style={{ backgroundColor: BRAND }}
          >
            {loading ? 'جاري الدخول...' : 'دخول'}
          </button>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3">
              <p className="text-center text-sm text-red-600">{error}</p>
            </div>
          )}
        </form>

        <p className="text-center text-sm text-gray-500 mt-6">
          ليس لديك حساب؟{' '}
          <Link href="/register" className="font-bold" style={{ color: BRAND }}>
            أنشئ حساباً
          </Link>
        </p>
      </div>
    </main>
  );
}
