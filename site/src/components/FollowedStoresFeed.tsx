'use client';

import { useEffect, useState } from 'react';
import ProductCard from '@/components/ProductCard';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { Product } from '@/lib/types';

export default function FollowedStoresFeed() {
  const [products, setProducts] = useState<Product[]>([]);

  useEffect(() => {
    async function load() {
      const { data: auth } = await supabaseBrowser.auth.getUser();
      const u = auth.user;
      if (!u) return;

      // المتاجر المتابَعة
      const { data: follows } = await supabaseBrowser
        .from('merchant_followers')
        .select('merchant_id')
        .eq('user_id', u.id);

      const ids = (follows ?? [])
        .map((f) => f.merchant_id as string)
        .filter(Boolean);

      if (ids.length === 0) return;

      // أحدث عروضها
      const { data } = await supabaseBrowser
        .from('products')
        .select('*')
        .in('merchant_id', ids)
        .eq('is_available', true)
        .order('created_at', { ascending: false })
        .limit(12);

      setProducts((data as Product[]) ?? []);
    }

    load();
  }, []);

  if (products.length === 0) return null;

  return (
    <section className="mt-5">
      <h2 className="text-base font-bold mb-5">جديد متاجرك</h2>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
        {products.map((p) => (
          <ProductCard key={p.id} product={p} />
        ))}
      </div>
    </section>
  );
}
