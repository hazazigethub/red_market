'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';
const MIN_PICK = 5;

type Cat = { id: string; name: string | null };

export default function InterestsPage() {
  const router = useRouter();

  const [cats, setCats] = useState<Cat[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [ready, setReady] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;

    (async () => {
      const { data: auth } = await supabaseBrowser.auth.getUser();
      const u = auth.user;

      if (!u) {
        router.replace('/login');
        return;
      }

      const [profRes, catRes] = await Promise.all([
        supabaseBrowser
          .from('profiles')
          .select('preferred_categories')
          .eq('id', u.id)
          .maybeSingle(),
        supabaseBrowser
          .from('store_categories')
          .select('id, name')
          .eq('is_visible', true)
          .order('name'),
      ]);

      if (!alive) return;

      setSelected((profRes.data?.preferred_categories as string[]) ?? []);
      setCats((catRes.data as Cat[]) ?? []);
      setReady(true);
    })();

    return () => {
      alive = false;
    };
  }, [router]);

  const toggle = useCallback((id: string) => {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
    );
  }, []);

  async function save() {
    if (saving) return;
    setSaving(true);
    setError(null);

    try {
      const { data: auth } = await supabaseBrowser.auth.getUser();
      const u = auth.user;
      if (!u) {
        router.replace('/login');
        return;
      }

      const { error: upErr } = await supabaseBrowser
        .from('profiles')
        .update({ preferred_categories: selected })
        .eq('id', u.id);

      if (upErr) {
        setError('تعذر الحفظ، حاول مجدداً');
        return;
      }

      router.push('/');
      router.refresh();
    } catch {
      setError('تعذر الاتصال، تحقق من الشبكة');
    } finally {
      setSaving(false);
    }
  }

  const picked = selected.length;
  const isReady = picked >= MIN_PICK;
  const ratio = Math.min(picked / MIN_PICK, 1) * 100;

  if (!ready) {
    return (
      <main className="min-h-[60vh] flex items-center justify-center">
        <p className="text-sm text-gray-500">جاري التحميل...</p>
      </main>
    );
  }

  return (
    <main className="max-w-2xl mx-auto px-4 py-12">
      <div className="text-center">
        <Image
          src="/logo.png"
          alt="رد ماركت"
          width={64}
          height={64}
          className="mx-auto object-contain"
        />

        <h1 className="text-2xl font-bold mt-5">ما الذي يهمّك؟</h1>

        <p className="text-sm text-gray-600 mt-3 leading-7">
          اختر خمسة تصنيفات على الأقل، لنعرض لك ما يناسبك
        </p>
      </div>

      {/* شريط التقدّم */}
      <div className="flex items-center gap-3 mt-8">
        <div className="flex-1 h-1.5 rounded-full bg-gray-200 overflow-hidden">
          <div
            className="h-full rounded-full transition-all duration-300"
            style={{ width: `${ratio}%`, backgroundColor: BRAND }}
          />
        </div>
        <span
          className="text-xs font-bold shrink-0"
          style={{ color: isReady ? BRAND : '#9CA3AF' }}
        >
          {picked} / {MIN_PICK}
        </span>
      </div>

      {cats.length === 0 ? (
        <p className="text-center text-sm text-gray-500 mt-12">
          تعذّر جلب التصنيفات، حاول لاحقاً
        </p>
      ) : (
        <div className="flex flex-wrap gap-2.5 mt-7">
          {cats.map((c) => {
            const on = selected.includes(c.id);
            return (
              <button
                key={c.id}
                type="button"
                onClick={() => toggle(c.id)}
                aria-pressed={on}
                className={`flex items-center gap-1.5 px-4 py-2.5 rounded-xl border text-sm transition-colors ${
                  on
                    ? 'bg-red-50 font-bold'
                    : 'border-gray-200 text-gray-700 hover:border-red-300'
                }`}
                style={
                  on ? { borderColor: BRAND, color: BRAND } : undefined
                }
              >
                {on && (
                  <svg
                    className="w-3.5 h-3.5"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={3}
                    viewBox="0 0 24 24"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <path d="M20 6L9 17l-5-5" />
                  </svg>
                )}
                {c.name}
              </button>
            );
          })}
        </div>
      )}

      {error && (
        <p className="text-center text-sm text-red-600 mt-6">{error}</p>
      )}

      <button
        onClick={save}
        disabled={!isReady || saving}
        className="w-full mt-10 py-3.5 rounded-lg font-bold text-white transition-opacity disabled:cursor-not-allowed"
        style={{
          backgroundColor: isReady && !saving ? BRAND : '#E5E7EB',
          color: isReady && !saving ? '#fff' : '#9CA3AF',
        }}
      >
        {saving
          ? 'جاري الحفظ...'
          : isReady
            ? 'متابعة'
            : `اختر ${MIN_PICK} على الأقل`}
      </button>

      <button
        onClick={() => router.push('/')}
        className="w-full mt-3 py-2.5 text-sm text-gray-500 hover:text-gray-700 transition-colors"
      >
        تخطّي الآن
      </button>
    </main>
  );
}
