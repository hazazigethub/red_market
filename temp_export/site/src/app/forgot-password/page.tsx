'use client';

import { useState } from 'react';
import Link from 'next/link';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

export default function ForgotPasswordPage() {
  const [phone, setPhone] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sentTo, setSentTo] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const digits = phone.replace(/\D/g, '');

      // يجلب بريد المصادقة المرتبط بالجوال
      const { data: found } = await supabaseBrowser.rpc('get_login_email', {
        p_phone: digits,
      });

      const email = (found as string | null) ?? null;

      if (!email) {
        setError('لا يوجد حساب بهذا الرقم');
        return;
      }

      const origin =
        typeof window !== 'undefined' ? window.location.origin : '';

      const { error: resetError } =
        await supabaseBrowser.auth.resetPasswordForEmail(email, {
          redirectTo: `${origin}/reset-password`,
        });

      if (resetError) {
        setError('تعذر إرسال الرابط، حاول بعد قليل');
        return;
      }

      setSentTo(email);
    } catch {
      setError('حدث خطأ غير متوقع');
    } finally {
      setLoading(false);
    }
  }

  if (sentTo) {
    return (
      <main className="min-h-[60vh] flex items-center justify-center px-4">
        <div className="w-full max-w-sm text-center border border-gray-200 rounded-2xl p-8">
          <div
            className="w-14 h-14 rounded-full mx-auto flex items-center justify-center text-white text-2xl"
            style={{ backgroundColor: BRAND }}
          >
            ✓
          </div>
          <h1 className="mt-5 text-lg font-bold">أُرسل الرابط</h1>
          <p className="mt-2 text-sm text-gray-500 leading-7">
            راجع بريدك <span className="font-bold">{sentTo}</span> واضغط رابط
            الاستعادة. تحقّق من مجلد الرسائل غير المرغوبة إن لم تجده.
          </p>
          <Link
            href="/login"
            className="mt-6 block w-full py-3 rounded-lg text-white font-bold"
            style={{ backgroundColor: BRAND }}
          >
            العودة لتسجيل الدخول
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-[60vh] flex items-center justify-center px-4">
      <div className="w-full max-w-sm border border-gray-200 rounded-2xl p-8">
        <h1 className="text-lg font-bold text-center">استعادة كلمة المرور</h1>
        <p className="mt-2 text-sm text-gray-500 text-center leading-7">
          أدخل رقم جوالك المسجّل وسنرسل رابط الاستعادة إلى بريدك
        </p>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <div>
            <label className="block text-sm mb-1.5 text-gray-700">
              رقم الجوال
            </label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
              dir="ltr"
              placeholder="05xxxxxxxx"
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full text-white font-bold py-3 rounded-lg disabled:opacity-60 hover:opacity-90 transition-opacity"
            style={{ backgroundColor: BRAND }}
          >
            {loading ? 'جاري الإرسال...' : 'إرسال رابط الاستعادة'}
          </button>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3">
              <p className="text-center text-sm text-red-600">{error}</p>
            </div>
          )}
        </form>

        <p className="text-center text-sm text-gray-500 mt-6">
          <Link href="/login" style={{ color: BRAND }}>
            العودة لتسجيل الدخول
          </Link>
        </p>
      </div>
    </main>
  );
}
