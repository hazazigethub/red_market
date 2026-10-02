'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import ProductCard from '@/components/ProductCard';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { Product } from '@/lib/types';

const BRAND = '#D32027';

type Row = {
  id: string;
  name: string;
  products: Product[];
};

/// خمسة تصنيفات فرعية عشوائية، كل واحد بـ 12 عرضاً
export default function CategoryRows() {
  const [rows, setRows] = useState<Row[]>([]);

  useEffect(() => {
    async function load() {
      const { data } = await supabaseBrowser.rpc('get_category_showcase');
      const list = ((data as Row[]) ?? []).filter(
        (r) => (r.products ?? []).length > 0
      );
      setRows(list);
    }
    load();
  }, []);

  if (rows.length === 0) return null;

  return (
    <>
      {rows.map((row) => (
        <section key={row.id} className="mt-5">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-base font-bold">{row.name}</h2>
            <Link prefetch={false}
              href={`/category-offers/${row.id}`}
              className="text-xs font-bold hover:opacity-80"
              style={{ color: BRAND }}
            >
              عرض الكل
            </Link>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
            {row.products.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      ))}
    </>
  );
}
