'use client';

import { useEffect, useState } from 'react';
import ProductCard from '@/components/ProductCard';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { Product } from '@/lib/types';

const KEY = 'recently_viewed_ids';

export default function RecentlyViewed() {
  const [products, setProducts] = useState<Product[]>([]);

  useEffect(() => {
    async function load() {
      let ids: string[] = [];

      // 1) المستخدم المسجّل: من قاعدة البيانات
      const { data: auth } = await supabaseBrowser.auth.getUser();
      const u = auth.user;

      if (u) {
        const { data: rows } = await supabaseBrowser
          .from('user_recently_viewed')
          .select('product_id, visited_at')
          .eq('user_id', u.id)
          .order('visited_at', { ascending: false })
          .limit(10);
        ids = (rows ?? [])
          .map((r) => r.product_id as string)
          .filter(Boolean);
      }

      // 2) احتياطي: التخزين المحلي
      if (ids.length === 0) {
        try {
          const raw = localStorage.getItem(KEY);
          ids = raw ? (JSON.parse(raw) as string[]).slice(0, 10) : [];
        } catch {
          ids = [];
        }
      }

      if (ids.length === 0) return;

      const { data } = await supabaseBrowser
        .from('products')
        .select('*')
        .in('id', ids)
        .eq('is_available', true);

      const list = (data as Product[]) ?? [];

      // ترتيب حسب ترتيب الزيارة
      const byId = new Map(list.map((p) => [p.id, p]));
      const sorted = ids
        .map((id) => byId.get(id))
        .filter(Boolean) as Product[];

      setProducts(sorted);
    }

    load();
  }, []);

  if (products.length === 0) return null;

  return (
    <section className="mt-5">
      <h2 className="text-base font-bold mb-5">شاهدتها مؤخراً</h2>
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
        {products.map((p) => (
          <ProductCard key={p.id} product={p} />
        ))}
      </div>
    </section>
  );
}
