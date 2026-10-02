'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import ProductCard from '@/components/ProductCard';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { Product, Merchant } from '@/lib/types';
import type { User } from '@supabase/supabase-js';

const BRAND = '#D32027';

type Tab = 'products' | 'stores';

export default function FavoritesPage() {
  const [user, setUser] = useState<User | null>(null);
  const [products, setProducts] = useState<Product[]>([]);
  const [stores, setStores] = useState<Merchant[]>([]);
  const [tab, setTab] = useState<Tab>('products');
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    async function load() {
      const { data } = await supabaseBrowser.auth.getUser();
      const u = data.user;
      setUser(u);

      if (!u) {
        setReady(true);
        return;
      }

      const [favRes, followRes] = await Promise.all([
        supabaseBrowser
          .from('favorites')
          .select('products(*)')
          .eq('user_id', u.id),
        supabaseBrowser
          .from('merchant_followers')
          .select('merchants(*)')
          .eq('user_id', u.id),
      ]);

      const prodList = (favRes.data ?? [])
        .map((r) => (r as unknown as { products: Product | null }).products)
        .filter(Boolean) as Product[];

      const storeList = (followRes.data ?? [])
        .map((r) => (r as unknown as { merchants: Merchant | null }).merchants)
        .filter(Boolean) as Merchant[];

      setProducts(prodList);
      setStores(storeList);
      setReady(true);
    }
    load();
  }, []);

  async function removeFav(productId: string) {
    if (!user || busy) return;
    setBusy(true);
    try {
      await supabaseBrowser
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('product_id', productId);
      setProducts((prev) => prev.filter((p) => p.id !== productId));
    } finally {
      setBusy(false);
    }
  }

  if (!ready) {
    return (
      <main className="max-w-6xl mx-auto px-4 py-16">
        <p className="text-center text-gray-500">جاري التحميل...</p>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="max-w-md mx-auto px-4 py-20 text-center">
        <h1 className="text-2xl font-bold mb-4">المفضلة</h1>
        <p className="text-gray-600 mb-6">
          سجّل الدخول لعرض ما حفظته وتابعته
        </p>
        <Link
          href="/login"
          className="inline-block px-8 py-3 rounded-lg text-white font-bold"
          style={{ backgroundColor: BRAND }}
        >
          تسجيل الدخول
        </Link>
      </main>
    );
  }

  const tabs: { key: Tab; label: string; count: number }[] = [
    { key: 'products', label: 'العروض', count: products.length },
    { key: 'stores', label: 'المتاجر', count: stores.length },
  ];

  return (
    <main className="max-w-6xl mx-auto px-4 py-10">
      <h1 className="text-2xl font-bold mb-6">المفضلة</h1>

      <div className="flex gap-2 mb-8">
        {tabs.map((t) => {
          const on = t.key === tab;
          return (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              className={`px-5 py-2 rounded-lg text-sm transition-colors ${
                on
                  ? 'text-white font-bold'
                  : 'border border-gray-200 bg-white text-gray-700 hover:border-red-300'
              }`}
              style={on ? { backgroundColor: BRAND } : undefined}
            >
              {t.label} ({t.count})
            </button>
          );
        })}
      </div>

      {tab === 'products' &&
        (products.length === 0 ? (
          <div className="text-center py-20">
            <p className="text-gray-500 mb-6">لم تضف أي عرض للمفضلة بعد</p>
            <Link
              href="/"
              className="inline-block px-8 py-3 rounded-lg text-white font-bold"
              style={{ backgroundColor: BRAND }}
            >
              تصفّح العروض
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            {products.map((p) => (
              <div key={p.id} className="relative">
                <ProductCard product={p} />
                <button
                  onClick={() => removeFav(p.id)}
                  disabled={busy}
                  aria-label="إزالة من المفضلة"
                  className="absolute top-2 left-2 w-8 h-8 rounded-full bg-white/90 border border-gray-200 text-gray-500 hover:text-red-600 hover:border-red-300 text-sm disabled:opacity-50 z-10"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
        ))}

      {tab === 'stores' &&
        (stores.length === 0 ? (
          <div className="text-center py-20">
            <p className="text-gray-500 mb-6">لم تتابع أي متجر بعد</p>
            <Link
              href="/"
              className="inline-block px-8 py-3 rounded-lg text-white font-bold"
              style={{ backgroundColor: BRAND }}
            >
              تصفّح المتاجر
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            {stores.map((m) => (
              <div
                key={m.id}
                className="border border-gray-200 rounded-xl p-5 text-center hover:shadow-md transition-shadow"
              >
                <Link href={`/store/${m.id}`} className="block group">
                  <div className="w-20 h-20 mx-auto rounded-full overflow-hidden bg-gray-100 border-2 border-gray-200 group-hover:border-red-400 transition-colors">
                    {m.logo_url ? (
                      <img
                        src={m.logo_url}
                        alt={m.store_name ?? ''}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-gray-300 text-xs">
                        متجر
                      </div>
                    )}
                  </div>

                  <p className="mt-3 text-sm font-bold text-gray-800 truncate">
                    {m.store_name ?? 'متجر'}
                  </p>
                </Link>
              </div>
            ))}
          </div>
        ))}
    </main>
  );
}
