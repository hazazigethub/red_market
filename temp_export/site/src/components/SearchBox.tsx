'use client';

import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Search } from 'lucide-react';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

type Hit = {
  id: string;
  name: string | null;
  price: number | null;
  discount_price: number | null;
  image_url: string | null;
};

export default function SearchBox() {
  const router = useRouter();
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<Hit[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const boxRef = useRef<HTMLDivElement>(null);

  // إغلاق القائمة عند النقر خارجها
  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  // بحث فوري مع تأخير بسيط
  useEffect(() => {
    const term = q.trim();
    if (term.length < 2) {
      // التأجيل يمنع تعاقب الرسم
      queueMicrotask(() => setHits([]));
      return;
    }

    const t = setTimeout(async () => {
      setLoading(true);
      try {
        const { data } = await supabaseBrowser
          .from('products')
          .select('id, name, price, discount_price, image_url')
          .eq('is_available', true)
          .ilike('name', `%${term}%`)
          .limit(6);
        setHits((data as Hit[]) ?? []);
        setOpen(true);
      } finally {
        setLoading(false);
      }
    }, 350);

    return () => clearTimeout(t);
  }, [q]);

  function submit(e: React.FormEvent) {
    e.preventDefault();
    const term = q.trim();
    if (!term) return;
    setOpen(false);
    router.push(`/search?q=${encodeURIComponent(term)}`);
  }

  return (
    <div ref={boxRef} className="relative flex-1">
      <form onSubmit={submit}>
        <div className="relative h-[38px]">
          <Search
            size={20}
            className="absolute top-1/2 -translate-y-1/2 right-3.5 text-gray-500 pointer-events-none"
          />
          <input
            type="text"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onFocus={() => hits.length > 0 && setOpen(true)}
            placeholder="ابحث عن عرض..."
            // مطابق لحقل البحث في التطبيق: زوايا 15، إطار أحمر بشفافية 50٪، خلفية بيضاء
            // h-[38px] ثابت — فلا يتغيّر الارتفاع عند تبديل الخط
            className="w-full h-[38px] bg-white rounded-[15px] border-[1.2px] pr-10 pl-4 text-sm outline-none transition-all"
            style={{
              borderColor: 'rgba(211, 32, 39, 0.5)',
              boxShadow: '0 4px 10px rgba(0, 0, 0, 0.03)',
            }}
          />
        </div>
      </form>

      {open && q.trim().length >= 2 && (
        <div className="absolute top-full mt-2 right-0 left-0 bg-white border border-gray-200 rounded-xl shadow-lg overflow-hidden z-50">
          {loading && hits.length === 0 ? (
            <p className="text-center text-sm text-gray-500 py-6">
              جاري البحث...
            </p>
          ) : hits.length === 0 ? (
            <p className="text-center text-sm text-gray-500 py-6">
              لا توجد نتائج
            </p>
          ) : (
            <>
              <ul className="max-h-80 overflow-y-auto">
                {hits.map((h) => (
                  <li key={h.id}>
                    <Link prefetch={false}
                      href={`/offer/${h.id}`}
                      onClick={() => setOpen(false)}
                      className="flex items-center gap-3 px-3 py-2.5 hover:bg-gray-50 transition-colors"
                    >
                      <span className="w-10 h-10 rounded-lg overflow-hidden bg-gray-100 shrink-0">
                        {h.image_url && (
                          <img
                            src={h.image_url}
                            alt=""
                            className="w-full h-full object-cover"
                          />
                        )}
                      </span>
                      <span className="flex-1 text-xs text-gray-800 truncate">
                        {h.name ?? 'عرض'}
                      </span>
                      <span
                        className="text-xs font-bold whitespace-nowrap"
                        style={{ color: BRAND }}
                      >
                        {(h.discount_price ?? h.price ?? 0).toLocaleString(
                          'en-US'
                        )}{' '}
                        ر.س
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>

              <button
                onClick={submit}
                className="w-full text-center text-xs font-bold py-2.5 border-t border-gray-100 hover:bg-gray-50 transition-colors"
                style={{ color: BRAND }}
              >
                عرض جميع النتائج
              </button>
            </>
          )}
        </div>
      )}
    </div>
  );
}
