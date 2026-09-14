'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { supabaseBrowser } from '@/lib/supabase-client';
import ProductCard from '@/components/ProductCard';
import type { Product } from '@/lib/types';

type Category = { id: string; name: string; product_count: number };

const PAGE = 24;

export default function CampaignProducts({
  campaignId,
  categories,
}: {
  campaignId: string;
  categories: Category[];
}) {
  // بذرة ثابتة للجلسة — فلا يتكرر العرض عند التمرير
  // تُولَّد مرة واحدة داخل initializer فلا تُستدعى أثناء الرسم
  const [seed] = useState<string>(() =>
    Math.random().toString(36).slice(2, 10)
  );

  const [products, setProducts] = useState<Product[]>([]);
  const [category, setCategory] = useState<string | null>(null);
  const [minDiscount, setMinDiscount] = useState<number | null>(null);
  const [sort, setSort] = useState<string>('random');
  const [loading, setLoading] = useState(true);
  const [done, setDone] = useState(false);
  const [offset, setOffset] = useState(0);

  const load = useCallback(
    async (reset: boolean, active = true) => {
      setLoading(true);
      const from = reset ? 0 : offset;

      try {
        const { data, error } = await supabaseBrowser.rpc(
          'get_campaign_products',
          {
            p_campaign_id: campaignId,
            p_seed: seed,
            p_category_id: category,
            p_min_price: null,
            p_max_price: null,
            p_min_discount: minDiscount,
            p_sort: sort,
            p_limit: PAGE,
            p_offset: from,
          }
        );

        if (!active) return;

        if (error) {
          console.error('campaign products error:', error);
          setLoading(false);
          return;
        }

        const list = (data ?? []) as Product[];

        setProducts((prev) => (reset ? list : [...prev, ...list]));
        setOffset(from + list.length);
        setDone(list.length < PAGE);
      } catch (err) {
        console.error('load error:', err);
      } finally {
        if (active) setLoading(false);
      }
    },
    [campaignId, seed, category, minDiscount, sort, offset]
  );

  // إعادة التحميل عند تغيّر أي فلتر
  useEffect(() => {
    let active = true;
    // التأجيل يمنع تعاقب الرسم
    queueMicrotask(() => void load(true, active));
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [category, minDiscount, sort]);

  function trackClick(productId: string) {
    supabaseBrowser
      .rpc('track_campaign_click', {
        p_campaign_id: campaignId,
        p_product_id: productId,
      })
      .then(undefined, (e) => console.error('click error:', e));
  }

  return (
    <div>
      {/* ===== التصنيفات ===== */}
      {categories.length > 0 && (
        <div className="flex gap-2 overflow-x-auto pb-2 mb-4">
          <FilterChip
            label="الكل"
            active={category === null}
            onClick={() => setCategory(null)}
          />
          {categories.map((c) => (
            <FilterChip
              key={c.id}
              label={`${c.name} (${c.product_count})`}
              active={category === c.id}
              onClick={() => setCategory(c.id)}
            />
          ))}
        </div>
      )}

      {/* ===== الفلاتر ===== */}
      <div className="flex gap-2 flex-wrap items-center mb-5">
        <span className="text-xs text-gray-500">الخصم:</span>
        {[null, 20, 30, 50, 75].map((d) => (
          <FilterChip
            key={String(d)}
            label={d === null ? 'الكل' : `${d}%+`}
            active={minDiscount === d}
            onClick={() => setMinDiscount(d)}
            small
          />
        ))}

        <span className="text-xs text-gray-500 mr-3">الترتيب:</span>

        <FilterChip
          label="الأقل سعراً"
          active={sort === 'price_asc'}
          onClick={() =>
            setSort(sort === 'price_asc' ? 'random' : 'price_asc')
          }
          small
        />

        <FilterChip
          label="الأعلى سعراً"
          active={sort === 'price_desc'}
          onClick={() =>
            setSort(sort === 'price_desc' ? 'random' : 'price_desc')
          }
          small
        />

        {(sort !== 'random' || minDiscount !== null || category) && (
          <button
            onClick={() => {
              setSort('random');
              setMinDiscount(null);
              setCategory(null);
            }}
            className="text-xs text-gray-500 underline mr-2"
          >
            مسح الفلاتر
          </button>
        )}
      </div>

      {/* ===== الشبكة ===== */}
      {products.length === 0 && !loading ? (
        <div className="text-center py-20 text-gray-500 text-sm">
          لا عروض مطابقة
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {products.map((p) => (
            <TrackedCard
              key={p.id}
              product={p}
              campaignId={campaignId}
              onClick={() => trackClick(p.id)}
            />
          ))}
        </div>
      )}

      {/* ===== المزيد ===== */}
      {!done && products.length > 0 && (
        <div className="text-center mt-6">
          <button
            onClick={() => load(false)}
            disabled={loading}
            className="px-8 py-3 rounded-lg text-white text-sm font-bold disabled:opacity-60"
            style={{ backgroundColor: '#D32027' }}
          >
            {loading ? 'جاري التحميل...' : 'عرض المزيد'}
          </button>
        </div>
      )}

      {loading && products.length === 0 && (
        <div className="text-center py-20 text-gray-500 text-sm">
          جاري التحميل...
        </div>
      )}
    </div>
  );
}

function FilterChip({
  label,
  active,
  onClick,
  small,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
  small?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      className={`shrink-0 rounded-lg border transition-colors ${
        small ? 'px-3 py-1.5 text-xs' : 'px-4 py-2 text-sm'
      } ${
        active
          ? 'text-white border-transparent'
          : 'bg-white text-gray-700 border-gray-200 hover:border-gray-300'
      }`}
      style={active ? { backgroundColor: '#D32027' } : undefined}
    >
      {label}
    </button>
  );
}

/// يغلّف بطاقة العرض لتتبّع الظهور والنقر
function TrackedCard({
  product,
  campaignId,
  onClick,
}: {
  product: Product;
  campaignId: string;
  onClick: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const seen = useRef(false);

  // تُحسب المشاهدة مرة واحدة حين يظهر نصف العرض
  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const obs = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !seen.current) {
          seen.current = true;
          supabaseBrowser
            .rpc('track_campaign_view', {
              p_campaign_id: campaignId,
              p_product_id: product.id,
            })
            .then(undefined, (e) => console.error('view error:', e));
        }
      },
      { threshold: 0.5 }
    );

    obs.observe(el);
    return () => obs.disconnect();
  }, [campaignId, product.id]);

  return (
    <div ref={ref} onClick={onClick}>
      <ProductCard product={product} />
    </div>
  );
}
