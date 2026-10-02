'use client';

import { useEffect, useRef, useState } from 'react';
import ProductCard from '@/components/ProductCard';
import type { Product } from '@/lib/types';

/// يعرض مجموعة عشوائية من العروض وتتبدّل كل 5 ثوانٍ
export default function RotatingProducts({
  products,
  show,
}: {
  products: Product[];
  show: number;
}) {
  const [visible, setVisible] = useState<Product[]>(() =>
    products.slice(0, show)
  );
  const paused = useRef(false);

  useEffect(() => {
    function pick() {
      if (products.length <= show) {
        setVisible(products);
        return;
      }
      const shuffled = [...products].sort(() => Math.random() - 0.5);
      setVisible(shuffled.slice(0, show));
    }

    pick();

    if (products.length <= show) return;

    const t = setInterval(() => {
      if (!paused.current) pick();
    }, 5000);

    return () => clearInterval(t);
  }, [products, show]);

  if (visible.length === 0) return null;

  return (
    <div
      className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4"
      onMouseEnter={() => (paused.current = true)}
      onMouseLeave={() => (paused.current = false)}
    >
      {visible.map((p) => (
        <ProductCard key={p.id} product={p} />
      ))}
    </div>
  );
}
