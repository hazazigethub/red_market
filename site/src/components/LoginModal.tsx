'use client';

import { useState } from 'react';
import Link from 'next/link';
import { supabaseBrowser, phoneToEmail } from '@/lib/supabase-client';

const BRAND = '#D32027';

export default function LoginModal({
  open,
  onClose,
  onSuccess,
}: {
  open: boolean;
  onClose: () => void;
  onSuccess?: () => void;
}) {
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const email = phoneToEmail(phone);
      const { error: authError } =
        await supabaseBrowser.auth.signInWithPassword({
          email,
          password: password.trim(),
        });

      if (authError) {
        setError(
          authError.message.includes('Invalid login')
            ? 'رقم الجوال أو كلمة المرور غير صحيحة'
            : 'تعذر تسجيل الدخول، حاول مجدداً'
        );
        return;
      }

      setPhone('');
      setPassword('');
      onSuccess?.();
      onClose();
    } catch {
      setError('تعذر الاتصال، تحقق من الشبكة');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-[100] flex items-end sm:items-center justify-center"
      role="dialog"
      aria-modal="true"
    >
      <div
        className="absolute inset-0 bg-black/50"
        onClick={onClose}
        aria-hidden
      />

      <div className="relative w-full sm:max-w-md bg-white rounded-t-2xl sm:rounded-2xl p-7 shadow-xl">
        <button
          onClick={onClose}
          aria-label="إغلاق"
          className="absolute top-4 left-4 w-8 h-8 rounded-full text-gray-500 hover:text-gray-700"
        >
          ✕
        </button>

        <h2
          className="text-xl font-bold text-center"
          style={{ color: BRAND }}
        >
          تسجيل الدخول
        </h2>
        <p className="text-center text-sm text-gray-500 mt-1.5">
          سجّل الدخول لإتمام هذا الإجراء
        </p>

        <form onSubmit={handleLogin} className="mt-6 space-y-3.5">
          <div>
            <label
              htmlFor="modal-phone"
              className="block text-sm mb-1.5 text-gray-700"
            >
              رقم الجوال
            </label>
            <input
              id="modal-phone"
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
              htmlFor="modal-password"
              className="block text-sm mb-1.5 text-gray-700"
            >
              كلمة المرور
            </label>
            <div className="relative">
              <input
                id="modal-password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
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

          <button
            type="submit"
            disabled={loading}
            className="w-full text-white font-bold py-3 rounded-lg disabled:opacity-60"
            style={{ backgroundColor: BRAND }}
          >
            {loading ? 'جاري الدخول...' : 'دخول'}
          </button>

          {error && (
            <p className="text-center text-sm text-red-600">{error}</p>
          )}
        </form>

        <p className="text-center text-sm text-gray-500 mt-5">
          ليس لديك حساب؟{' '}
          <Link
            href="/register"
            className="font-bold"
            style={{ color: BRAND }}
            onClick={onClose}
          >
            أنشئ حساباً
          </Link>
        </p>
      </div>
    </div>
  );
}
