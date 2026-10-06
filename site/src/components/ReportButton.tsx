'use client';

// زر الإبلاغ — نفس أسباب التطبيق ونفس طريقة الحفظ (جدول reports، يتطلب تسجيل الدخول)
import { useEffect, useState } from 'react';
import {
  Flag,
  X,
  Check,
  CircleDollarSign,
  Link2Off,
  Gavel,
  ShieldAlert,
  type LucideIcon,
} from 'lucide-react';
import { supabaseBrowser } from '@/lib/supabase-client';
import LoginModal from '@/components/LoginModal';

const BRAND = '#D32027';

type Reason = { title: string; hint: string; icon: LucideIcon; color: string };

const REASONS: Record<'product' | 'merchant', Reason[]> = {
  product: [
    { title: 'السعر مختلف', hint: 'السعر المعروض غير مطابق للحقيقة', icon: CircleDollarSign, color: '#16a34a' },
    { title: 'رابط عرض مختلف', hint: 'الرابط يوجه لعرض أو صفحة أخرى', icon: Link2Off, color: '#2563eb' },
    { title: 'عرض مخالف', hint: 'محتوى ينتهك سياسة المنصة', icon: Gavel, color: '#dc2626' },
  ],
  merchant: [
    { title: 'رابط المتجر مختلف', hint: 'الرابط لا يوجه للمتجر الصحيح', icon: Link2Off, color: '#4f46e5' },
    { title: 'اشتباه احتيال', hint: 'نشاط مريب أو محاولة خداع', icon: ShieldAlert, color: BRAND },
  ],
};

export default function ReportButton({
  targetId,
  targetType,
  variant = 'icon',
}: {
  targetId: string;
  targetType: 'product' | 'merchant';
  /** icon: زر دائري بجانب المشاركة · link: نص صغير أسفل التفاصيل */
  variant?: 'icon' | 'link';
}) {
  const [open, setOpen] = useState(false);
  const [showLogin, setShowLogin] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);
  const [details, setDetails] = useState('');
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  const title = targetType === 'product' ? 'إبلاغ عن محتوى' : 'إبلاغ عن المتجر';

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && close();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  function reset() {
    setSelected(null);
    setDetails('');
    setDone(false);
    setError('');
  }

  function close() {
    if (busy) return;
    setOpen(false);
    reset();
  }

  async function start() {
    const { data } = await supabaseBrowser.auth.getUser();
    if (!data.user) {
      setShowLogin(true);
      return;
    }
    reset();
    setOpen(true);
  }

  async function submit() {
    const extra = details.trim();
    const reason = selected ? (extra ? `${selected} — ${extra}` : selected) : extra;
    if (!reason) {
      setError('اختر سبباً أو اكتب التفاصيل');
      return;
    }

    setBusy(true);
    setError('');
    try {
      const { data } = await supabaseBrowser.auth.getUser();
      if (!data.user) {
        setOpen(false);
        setShowLogin(true);
        return;
      }
      const { error: e } = await supabaseBrowser.from('reports').insert({
        reporter_id: data.user.id,
        target_id: targetId,
        target_type: targetType,
        reason,
        status: 'pending',
      });
      if (e) throw e;
      setDone(true);
      setTimeout(() => {
        setOpen(false);
        reset();
      }, 1600);
    } catch {
      setError('تعذّر إرسال البلاغ، حاول مرة أخرى');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      {variant === 'icon' ? (
        <button
          onClick={start}
          aria-label={title}
          title={title}
          className="w-12 h-12 rounded-full flex items-center justify-center text-gray-700 hover:bg-gray-100 transition-colors"
        >
          <Flag size={24} strokeWidth={1.7} />
        </button>
      ) : (
        <button
          onClick={start}
          className="inline-flex items-center gap-1.5 text-xs text-gray-500 hover:text-red-700 transition-colors"
        >
          <Flag size={14} />
          الإبلاغ عن هذا العرض
        </button>
      )}

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
          onClick={close}
          dir="rtl"
        >
          <div
            className="w-full max-w-md rounded-2xl bg-white p-5 shadow-xl"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-label={title}
          >
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-gray-900">{title}</h2>
              <button
                onClick={close}
                aria-label="إغلاق"
                className="w-9 h-9 rounded-full flex items-center justify-center text-gray-500 hover:bg-gray-100"
              >
                <X size={20} />
              </button>
            </div>

            {done ? (
              <div className="py-8 text-center">
                <div className="mx-auto mb-3 w-14 h-14 rounded-full bg-green-600 flex items-center justify-center text-white">
                  <Check size={28} />
                </div>
                <p className="font-bold text-gray-900">تم استلام بلاغك بنجاح</p>
                <p className="mt-1 text-sm text-gray-500">سيراجعه فريق رد ماركت</p>
              </div>
            ) : (
              <>
                <div className="space-y-2">
                  {REASONS[targetType].map((r) => {
                    const Icon = r.icon;
                    const active = selected === r.title;
                    return (
                      <button
                        key={r.title}
                        onClick={() => setSelected(active ? null : r.title)}
                        className="w-full flex items-center gap-3 rounded-xl border p-3 text-right transition-colors"
                        style={{
                          borderColor: active ? BRAND : '#EDEFF3',
                          backgroundColor: active ? 'rgba(211,32,39,0.04)' : '#fff',
                        }}
                      >
                        <span
                          className="w-10 h-10 shrink-0 rounded-xl flex items-center justify-center"
                          style={{ backgroundColor: `${r.color}1a`, color: r.color }}
                        >
                          <Icon size={20} />
                        </span>
                        <span className="flex-1">
                          <span className="block text-sm font-bold text-gray-900">{r.title}</span>
                          <span className="block text-xs text-gray-500">{r.hint}</span>
                        </span>
                        <span
                          className="w-5 h-5 shrink-0 rounded-full border-2 flex items-center justify-center"
                          style={{ borderColor: active ? BRAND : '#d1d5db' }}
                        >
                          {active && (
                            <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: BRAND }} />
                          )}
                        </span>
                      </button>
                    );
                  })}
                </div>

                <textarea
                  value={details}
                  onChange={(e) => setDetails(e.target.value)}
                  rows={2}
                  maxLength={500}
                  placeholder="سبب آخر أو تفاصيل إضافية..."
                  className="mt-3 w-full rounded-xl border border-[#EDEFF3] bg-[#F7F8FA] p-3 text-sm outline-none focus:border-[#D32027]"
                />

                {error && <p className="mt-2 text-sm text-red-700">{error}</p>}

                <button
                  onClick={submit}
                  disabled={busy}
                  className="mt-4 w-full h-11 rounded-xl text-white font-bold disabled:opacity-60"
                  style={{ backgroundColor: BRAND }}
                >
                  {busy ? 'جارٍ الإرسال...' : 'إرسال البلاغ'}
                </button>
              </>
            )}
          </div>
        </div>
      )}

      <LoginModal
        open={showLogin}
        onClose={() => setShowLogin(false)}
        onSuccess={() => {
          setShowLogin(false);
          reset();
          setOpen(true);
        }}
      />
    </>
  );
}
