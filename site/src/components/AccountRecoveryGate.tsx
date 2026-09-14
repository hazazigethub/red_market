'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

/**
 * حارس يظهر شاشة استعادة الحساب لمن طلب الحذف
 * ولم تنقضِ مهلة الثلاثين يوماً.
 */
export default function AccountRecoveryGate() {
  const router = useRouter();
  const [scheduled, setScheduled] = useState<Date | null>(null);
  const [daysLeft, setDaysLeft] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function check(userId: string | null) {
      if (!userId) {
        if (active) setScheduled(null);
        return;
      }

      const { data } = await supabaseBrowser
        .from('profiles')
        .select('deletion_scheduled_at')
        .eq('id', userId)
        .maybeSingle();

      if (!active) return;

      const raw = data?.deletion_scheduled_at as string | null | undefined;
      if (!raw) {
        setScheduled(null);
        return;
      }

      const d = new Date(raw);
      const valid = Number.isNaN(d.getTime()) ? null : d;
      setScheduled(valid);

      // يُحتسب هنا لا أثناء الرسم — فـ Date.now دالة غير نقية
      setDaysLeft(
        valid
          ? Math.max(0, Math.ceil((valid.getTime() - Date.now()) / 86_400_000))
          : 0
      );
    }

    // فحص أولي عند التحميل
    supabaseBrowser.auth.getUser().then(({ data }) => {
      check(data.user?.id ?? null);
    });

    // إعادة الفحص عند كل تغيّر في الجلسة (دخول أو خروج)
    const { data: sub } = supabaseBrowser.auth.onAuthStateChange(
      (_event, session) => {
        check(session?.user?.id ?? null);
      }
    );

    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, []);

  if (!scheduled) return null;

  async function restore() {
    if (busy) return;
    setBusy(true);
    setError(null);

    try {
      const { data, error: rpcError } = await supabaseBrowser.rpc(
        'cancel_account_deletion'
      );

      if (rpcError) {
        setError('تعذرت الاستعادة، حاول مجدداً');
        return;
      }

      const res = data as { ok?: boolean; error?: string } | null;

      if (res?.ok) {
        setScheduled(null);
        router.refresh();
      } else {
        setError(res?.error ?? 'تعذرت الاستعادة');
      }
    } catch {
      setError('تعذر الاتصال، تحقق من الشبكة');
    } finally {
      setBusy(false);
    }
  }

  async function signOut() {
    await supabaseBrowser.auth.signOut();
    setScheduled(null);
    router.push('/');
    router.refresh();
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl max-w-md w-full p-7 max-h-[90vh] overflow-y-auto">
        <div className="text-center">
          <div className="w-16 h-16 rounded-full bg-orange-50 mx-auto flex items-center justify-center">
            <svg
              className="w-8 h-8"
              fill="none"
              stroke="#EA8C00"
              strokeWidth={1.7}
              viewBox="0 0 24 24"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 012 2v14a2 2 0 01-2 2H5a2 2 0 01-2-2V6a2 2 0 012-2z" />
              <path d="M9 15l6 4M15 15l-6 4" />
            </svg>
          </div>

          <h2 className="text-xl font-bold mt-5">حسابك مجدول للحذف</h2>
          <p className="text-sm text-gray-600 mt-2 leading-7">
            سيُحذف حسابك نهائياً في{' '}
            {scheduled.toLocaleDateString('ar-SA')}
          </p>
        </div>

        <div className="bg-orange-50 rounded-xl py-4 mt-5 text-center">
          <p className="text-3xl font-bold text-orange-500">{daysLeft}</p>
          <p className="text-xs text-gray-600 mt-0.5">
            {daysLeft === 1 ? 'يوم متبقٍ' : 'يوماً متبقياً'}
          </p>
        </div>

        <ul className="text-sm text-gray-600 leading-7 mt-5 space-y-1.5">
          <li>• حسابك موقوف حالياً</li>
          <li>• مفضلتك ومتابعاتك ما زالت محفوظة</li>
          <li>• يمكنك استعادة حسابك الآن ويعود كما كان</li>
          <li>• بعد انتهاء المدة يُحذف الحساب ولا يمكن استرجاعه</li>
        </ul>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-3 mt-4">
            <p className="text-center text-sm text-red-600">{error}</p>
          </div>
        )}

        <button
          onClick={restore}
          disabled={busy}
          className="w-full mt-6 text-white font-bold py-3.5 rounded-lg disabled:opacity-60 hover:opacity-90 transition-opacity"
          style={{ backgroundColor: BRAND }}
        >
          {busy ? 'جاري الاستعادة...' : 'استعادة حسابي'}
        </button>

        <button
          onClick={signOut}
          disabled={busy}
          className="w-full mt-2 text-gray-500 text-sm py-2 hover:text-gray-700 transition-colors"
        >
          متابعة الحذف والخروج
        </button>
      </div>
    </div>
  );
}
