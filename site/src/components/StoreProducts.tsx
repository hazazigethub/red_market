'use client';

import { useMemo, useState } from 'react';
import ProductCard from '@/components/ProductCard';
import type { Product } from '@/lib/types';

const BRAND = '#D32027';

export default function StoreProducts({ products }: { products: Product[] }) {
  const categories = useMemo(() => {
    const set = new Set<string>();
    products.forEach((p) => {
      const c = p.store_category?.trim();
      if (c) set.add(c);
    });
    return [...set];
  }, [products]);

  const [active, setActive] = useState<string>('الكل');

  const filtered = useMemo(() => {
    if (active === 'الكل') return products;
    return products.filter((p) => p.store_category?.trim() === active);
  }, [products, active]);

  if (products.length === 0) {
    return (
      <p className="text-gray-500 py-12 text-center">
        لا توجد عروض في هذا المتجر حالياً
      </p>
    );
  }

  const tabs = ['الكل', ...categories];

  return (
    <>
      {categories.length > 0 && (
        <div className="flex gap-2 overflow-x-auto pb-2 mb-6">
          {tabs.map((t) => {
            const on = t === active;
            return (
              <button
                key={t}
                onClick={() => setActive(t)}
                className={`shrink-0 px-4 py-1.5 rounded-lg text-xs whitespace-nowrap transition-colors ${
                  on
                    ? 'text-white font-bold'
                    : 'border border-gray-200 bg-white text-gray-700 hover:border-red-300'
                }`}
                style={on ? { backgroundColor: BRAND } : undefined}
              >
                {t}
              </button>
            );
          })}
        </div>
      )}

      {filtered.length === 0 ? (
        <p className="text-gray-500 py-12 text-center">
          لا توجد عروض في هذا القسم
        </p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
          {filtered.map((p) => (
            <ProductCard key={p.id} product={p} />
          ))}
        </div>
      )}
    </>
  );
}
