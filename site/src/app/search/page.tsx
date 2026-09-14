'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import ProductCard from '@/components/ProductCard';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { Product, Merchant } from '@/lib/types';

const BRAND = '#D32027';

type Sort = 'newest' | 'price_asc' | 'price_desc';

type StoreCategory = { id: string; name: string | null };

export default function SearchPage() {
  const [query, setQuery] = useState('');
  const [minPrice, setMinPrice] = useState('');
  const [maxPrice, setMaxPrice] = useState('');
  const [sort, setSort] = useState<Sort>('newest');

  const [products, setProducts] = useState<Product[]>([]);
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [suggestions, setSuggestions] = useState<StoreCategory[]>([]);
  const [featured, setFeatured] = useState<Product[]>([]);

  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  // اقتراحات تُحمّل مرة واحدة لعرضها عند غياب النتائج
  useEffect(() => {
    async function loadSuggestions() {
      const [catRes, featRes] = await Promise.all([
        supabaseBrowser
          .from('store_categories')
          .select('id, name')
          .eq('is_visible', true)
          .limit(10),
        supabaseBrowser.rpc('search_products', {
          p_query: null,
          p_sort: 'newest',
          p_limit: 6,
        }),
      ]);
      setSuggestions((catRes.data as StoreCategory[]) ?? []);
      setFeatured((featRes.data as Product[]) ?? []);
    }
    loadSuggestions();
  }, []);

  const runSearch = useCallback(async () => {
    const q = query.trim();
    setLoading(true);
    setSearched(true);

    try {
      // البحث عبر دالة قاعدة البيانات — تستبعد المحظور ومنتهي الاشتراك
      const [pRes, mRes] = await Promise.all([
        supabaseBrowser.rpc('search_products', {
          p_query: q || null,
          p_min: minPrice ? Number(minPrice) : null,
          p_max: maxPrice ? Number(maxPrice) : null,
          p_sort: sort,
          p_limit: 60,
        }),
        q
          ? supabaseBrowser
              .from('merchants')
              .select('*')
              .eq('is_subscription_active', true)
              .ilike('store_name', `%${q}%`)
              .limit(12)
          : Promise.resolve({ data: [] }),
      ]);

      setProducts((pRes.data as Product[]) ?? []);
      setMerchants((mRes.data as Merchant[]) ?? []);
    } finally {
      setLoading(false);
    }
  }, [query, minPrice, maxPrice, sort]);

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    runSearch();
  }

  const noResults =
    searched && !loading && products.length === 0 && merchants.length === 0;

  return (
    <main className="max-w-6xl mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6">البحث</h1>

      <form onSubmit={onSubmit} className="space-y-4">
        <input
          type="text"
          aria-label="ابحث عن عرض أو متجر"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="ابحث عن عرض أو متجر..."
          className="w-full border border-gray-300 rounded-xl px-5 py-3.5 outline-none focus:border-red-400"
        />

        <div className="flex flex-wrap gap-3 items-end">
          <div>
            <label
              htmlFor="min-price"
              className="block text-xs text-gray-500 mb-1"
            >
              من سعر
            </label>
            <input
              id="min-price"
              type="number"
              value={minPrice}
              onChange={(e) => setMinPrice(e.target.value)}
              placeholder="0"
              className="w-28 border border-gray-300 rounded-lg px-3 py-2 text-sm outline-none focus:border-red-400"
            />
          </div>

          <div>
            <label
              htmlFor="max-price"
              className="block text-xs text-gray-500 mb-1"
            >
              إلى سعر
            </label>
            <input
              id="max-price"
              type="number"
              value={maxPrice}
              onChange={(e) => setMaxPrice(e.target.value)}
              placeholder="—"
              className="w-28 border border-gray-300 rounded-lg px-3 py-2 text-sm outline-none focus:border-red-400"
            />
          </div>

          <div>
            <label
              htmlFor="sort-order"
              className="block text-xs text-gray-500 mb-1"
            >
              الترتيب
            </label>
            <select
              id="sort-order"
              value={sort}
              onChange={(e) => setSort(e.target.value as Sort)}
              className="border border-gray-300 rounded-lg px-3 py-2 text-sm outline-none focus:border-red-400"
            >
              <option value="newest">الأحدث</option>
              <option value="price_asc">الأقل سعراً</option>
              <option value="price_desc">الأعلى سعراً</option>
            </select>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="px-8 py-2 rounded-lg text-white text-sm font-bold disabled:opacity-60"
            style={{ backgroundColor: BRAND }}
          >
            {loading ? 'جاري البحث...' : 'بحث'}
          </button>
        </div>
      </form>

      {merchants.length > 0 && (
        <section className="mt-10">
          <h2 className="text-lg font-bold mb-4">المتاجر</h2>
          <div className="flex gap-5 overflow-x-auto pb-3">
            {merchants.map((m) => (
              <Link
                key={m.id}
                href={`/store/${m.id}`}
                className="shrink-0 w-24 text-center group"
              >
                <div className="w-20 h-20 mx-auto rounded-full overflow-hidden bg-gray-100 border-2 border-gray-200 group-hover:border-red-400 transition-colors">
                  {m.logo_url ? (
                    <img
                      src={m.logo_url}
                      alt=""
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-gray-300 text-xs">
                      متجر
                    </div>
                  )}
                </div>
                <p className="mt-2 text-xs text-gray-700 leading-4">
                  {m.store_name ?? 'متجر'}
                </p>
              </Link>
            ))}
          </div>
        </section>
      )}

      {products.length > 0 && (
        <section className="mt-10">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-bold">العروض</h2>
            <span className="text-sm text-gray-500">{products.length} نتيجة</span>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
            {products.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {noResults && (
        <section className="mt-12">
          <p className="text-center text-gray-500 mb-10">
            لا توجد نتائج مطابقة لبحثك
          </p>

          {suggestions.length > 0 && (
            <div className="mb-10">
              <h3 className="font-bold mb-4">تصفّح التصنيفات</h3>
              <div className="flex flex-wrap gap-2">
                {suggestions.map((c) => (
                  <Link
                    key={c.id}
                    href={`/category/${c.id}`}
                    className="px-4 py-2 rounded-lg border border-gray-200 text-sm hover:border-red-300 hover:text-red-700 transition-colors"
                  >
                    {c.name}
                  </Link>
                ))}
              </div>
            </div>
          )}

          {featured.length > 0 && (
            <div>
              <h3 className="font-bold mb-4">عروض قد تعجبك</h3>
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
                {featured.map((p) => (
                  <ProductCard key={p.id} product={p} />
                ))}
              </div>
            </div>
          )}
        </section>
      )}

      {!searched && (
        <p className="text-center text-gray-500 py-16">
          اكتب كلمة للبحث في العروض والمتاجر
        </p>
      )}
    </main>
  );
}