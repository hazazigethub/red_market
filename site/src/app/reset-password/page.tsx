'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabaseBrowser } from '@/lib/supabase-client';
import { Eye, EyeOff } from 'lucide-react';

const BRAND = '#D32027';

export default function ResetPasswordPage() {
  const router = useRouter();

  const [ready, setReady] = useState(false);
  const [valid, setValid] = useState(false);
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  // الرابط يضع الرمز في hash — نقرؤه بأنفسنا بدل انتظار الـ SDK
  useEffect(() => {
    let active = true;

    async function init() {
      const hash = window.location.hash.replace(/^#/, '');
      const params = new URLSearchParams(hash);

      // خطأ صريح في الرابط
      if (params.get('error')) {
        if (active) {
          setValid(false);
          setReady(true);
        }
        return;
      }

      const accessToken = params.get('access_token');
      const refreshToken = params.get('refresh_token');

      // نبني الجلسة من الرمز مباشرة — لا نعتمد على التقاط تلقائي
      if (accessToken && refreshToken) {
        const { error } = await supabaseBrowser.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });

        if (active) {
          setValid(!error);
          setReady(true);
        }
        return;
      }

      // لا رمز في الرابط: قد تكون هناك جلسة قائمة
      const { data } = await supabaseBrowser.auth.getSession();
      if (active) {
        setValid(!!data.session);
        setReady(true);
      }
    }

    void init();

    return () => {
      active = false;
    };
  }, []);

  async function submit() {
    if (busy) return;
    setError(null);

    if (password.length < 6) {
      setError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (password !== confirm) {
      setError('كلمتا المرور غير متطابقتين');
      return;
    }

    setBusy(true);
    try {
      const { error } = await supabaseBrowser.auth.updateUser({ password });
      if (error) {
        console.error('updateUser error:', error);

        const msg = error.message || '';
        if (msg.includes('should be different')) {
          setError('كلمة المرور الجديدة مطابقة للقديمة — اختر غيرها');
        } else if (msg.includes('session') || msg.includes('JWT')) {
          setError('انتهت صلاحية الجلسة — اطلب رابطاً جديداً');
        } else if (msg.includes('at least')) {
          setError('كلمة المرور قصيرة جداً');
        } else {
          setError(msg);
        }
        setBusy(false);
        return;
      }
      setDone(true);
      await supabaseBrowser.auth.signOut();
    } catch {
      setError('حدث خطأ غير متوقع');
      setBusy(false);
    }
  }

  if (!ready) {
    return (
      <main className="min-h-[60vh] flex items-center justify-center">
        <p className="text-sm text-gray-500">جاري التحقق...</p>
      </main>
    );
  }

  if (done) {
    return (
      <main className="min-h-[60vh] flex items-center justify-center px-4">
        <div className="w-full max-w-sm text-center border border-gray-200 rounded-2xl p-8">
          <div
            className="w-14 h-14 rounded-full mx-auto flex items-center justify-center text-white text-2xl"
            style={{ backgroundColor: BRAND }}
          >
            ✓
          </div>
          <h1 className="mt-5 text-lg font-bold">تم تغيير كلمة المرور</h1>
          <p className="mt-2 text-sm text-gray-500 leading-7">
            يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة
          </p>
          <button
            onClick={() => router.push('/login')}
            className="mt-6 w-full py-3 rounded-lg text-white font-bold hover:opacity-90 transition-opacity"
            style={{ backgroundColor: BRAND }}
          >
            تسجيل الدخول
          </button>
          <button
            onClick={() => router.push('/')}
            className="mt-3 w-full py-2.5 rounded-lg border border-gray-300 font-bold text-gray-700 hover:bg-gray-50 transition-colors"
          >
            العودة للرئيسية
          </button>
        </div>
      </main>
    );
  }

  if (!valid) {
    return (
      <main className="min-h-[60vh] flex items-center justify-center px-4">
        <div className="w-full max-w-sm text-center border border-gray-200 rounded-2xl p-8">
          <h1 className="text-lg font-bold">الرابط غير صالح</h1>
          <p className="mt-2 text-sm text-gray-500 leading-7">
            انتهت صلاحية رابط الاستعادة أو استُخدم من قبل. اطلب رابطاً جديداً.
          </p>
          <button
            onClick={() => router.push('/forgot-password')}
            className="mt-6 w-full py-3 rounded-lg text-white font-bold hover:opacity-90 transition-opacity"
            style={{ backgroundColor: BRAND }}
          >
            طلب رابط جديد
          </button>
          <button
            onClick={() => router.push('/')}
            className="mt-3 w-full py-2.5 rounded-lg border border-gray-300 font-bold text-gray-700 hover:bg-gray-50 transition-colors"
          >
            العودة للرئيسية
          </button>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-[60vh] flex items-center justify-center px-4">
      <div className="w-full max-w-sm border border-gray-200 rounded-2xl p-8">
        <h1 className="text-lg font-bold text-center">
          تعيين كلمة مرور جديدة
        </h1>
        <p className="mt-2 text-sm text-gray-500 text-center leading-7">
          اختر كلمة مرور قوية لا تقل عن 6 أحرف
        </p>

        <div className="mt-6">
          <label className="block text-sm font-bold mb-2">
            كلمة المرور الجديدة
          </label>
          <div className="relative">
            <input
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              dir="ltr"
              placeholder="********"
              className="w-full px-4 py-3 pl-12 rounded-xl bg-gray-50 border border-gray-300 focus:outline-none focus:border-red-600"
            />
            <button
              type="button"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور'}
              className="absolute left-1 top-1/2 -translate-y-1/2 w-11 h-11 flex items-center justify-center text-gray-500 hover:text-gray-700"
            >
              {showPassword ? <Eye size={18} /> : <EyeOff size={18} />}
            </button>
          </div>
        </div>

        <div className="mt-4">
          <label className="block text-sm font-bold mb-2">
            تأكيد كلمة المرور
          </label>
          <div className="relative">
            <input
              type={showPassword ? 'text' : 'password'}
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              dir="ltr"
              placeholder="********"
              className="w-full px-4 py-3 pl-12 rounded-xl bg-gray-50 border border-gray-300 focus:outline-none focus:border-red-600"
            />
            <button
              type="button"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور'}
              className="absolute left-1 top-1/2 -translate-y-1/2 w-11 h-11 flex items-center justify-center text-gray-500 hover:text-gray-700"
            >
              {showPassword ? <Eye size={18} /> : <EyeOff size={18} />}
            </button>
          </div>
        </div>

        {error && (
          <p className="mt-4 text-sm text-red-600 text-center leading-6">
            {error}
          </p>
        )}

        <button
          onClick={submit}
          disabled={busy}
          className="mt-6 w-full py-3.5 rounded-lg text-white font-bold disabled:opacity-60"
          style={{ backgroundColor: BRAND }}
        >
          {busy ? 'جاري الحفظ...' : 'حفظ كلمة المرور'}
        </button>
      </div>
    </main>
  );
}
