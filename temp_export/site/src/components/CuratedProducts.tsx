'use client';

import { useEffect, useRef, useState } from 'react';
import ProductCard from '@/components/ProductCard';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { Product } from '@/lib/types';

const SHOW = 12;

/// أعلى عرض تفاعلاً لكل متجر احترافي — يتبدّل كل 5 ثوانٍ
export default function CuratedProducts() {
  const [pool, setPool] = useState<Product[]>([]);
  const [visible, setVisible] = useState<Product[]>([]);
  // انتهى الجلب — لإخفاء القسم نهائياً إن لم يوجد عرض
  const [done, setDone] = useState(false);
  const paused = useRef(false);

  useEffect(() => {
    async function load() {
      const { data } = await supabaseBrowser.rpc('get_curated_products');
      setPool((data as Product[]) ?? []);
      setDone(true);
    }
    load();
  }, []);

  useEffect(() => {
    if (pool.length === 0) return;

    function pick() {
      if (pool.length <= SHOW) {
        setVisible(pool);
        return;
      }
      const shuffled = [...pool].sort(() => Math.random() - 0.5);
      setVisible(shuffled.slice(0, SHOW));
    }

    pick();

    if (pool.length <= SHOW) return;

    const t = setInterval(() => {
      if (!paused.current) pick();
    }, 5000);

    return () => clearInterval(t);
  }, [pool]);

  // هيكل بأبعاد القسم — يحجز المساحة قبل وصول البيانات
  if (visible.length === 0) {
    if (done) return null;

    return (
      <section className="mt-5">
        <h2 className="text-base font-bold mb-3">عروض مختارة</h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <div
              key={i}
              className="bg-gray-50 border border-gray-100 rounded-none aspect-square"
            />
          ))}
        </div>
      </section>
    );
  }

  return (
    <section className="mt-5">
      <h2 className="text-base font-bold mb-3">عروض مختارة</h2>

      <div
        className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4"
        onMouseEnter={() => (paused.current = true)}
        onMouseLeave={() => (paused.current = false)}
      >
        {visible.map((p) => (
          <ProductCard key={p.id} product={p} />
        ))}
      </div>
    </section>
  );
}
