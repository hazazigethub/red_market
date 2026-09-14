'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import ProductCard from '@/components/ProductCard';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { Product } from '@/lib/types';

const PAGE = 18;
const INTEREST_RATIO = 0.6; // 60% من اهتماماته و40% عشوائي

export default function DiscoverMore() {
  const [items, setItems] = useState<Product[]>([]);
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);

  const offset = useRef(0);
  const catIds = useRef<string[] | null>(null);
  const interestOffset = useRef(0);
  const interestDone = useRef(false);
  const seen = useRef<Set<string>>(new Set());
  const sentinel = useRef<HTMLDivElement>(null);

  /// يجلب تصنيفات اهتمامات المستخدم مرة واحدة
  const loadInterests = useCallback(async () => {
    if (catIds.current !== null) return catIds.current;

    const { data: auth } = await supabaseBrowser.auth.getUser();
    const u = auth.user;
    if (!u) {
      catIds.current = [];
      return catIds.current;
    }

    const { data: prof } = await supabaseBrowser
      .from('profiles')
      .select('preferred_categories')
      .eq('id', u.id)
      .maybeSingle();

    const storeCats = (prof?.preferred_categories as string[]) ?? [];
    if (storeCats.length === 0) {
      catIds.current = [];
      return catIds.current;
    }

    // اهتماماته تصنيفات رئيسية — نحوّلها لتصنيفاتها الفرعية
    const { data: subs } = await supabaseBrowser
      .from('product_categories')
      .select('id')
      .in('parent_id', storeCats);

    catIds.current = (subs ?? []).map((c) => c.id as string);
    return catIds.current;
  }, []);

  const loadMore = useCallback(async () => {
    if (loading || done) return;
    setLoading(true);

    try {
      const cats = await loadInterests();
      const batch: Product[] = [];

      // الجزء الأول: من اهتماماته — ما دامت متاحة
      let gotInterest = 0;
      if (cats.length > 0 && !interestDone.current) {
        const want = Math.round(PAGE * INTEREST_RATIO);
        const iFrom = interestOffset.current;

        const { data } = await supabaseBrowser
          .from('products')
          .select('*')
          .eq('is_available', true)
          .in('category_id', cats)
          .order('created_at', { ascending: false })
          .range(iFrom, iFrom + want - 1);

        const list = ((data as Product[]) ?? []).filter(
          (p) => !seen.current.has(p.id)
        );

        gotInterest = list.length;
        batch.push(...list);
        interestOffset.current = iFrom + want;

        // نفدت عروض اهتماماته
        if (((data as Product[]) ?? []).length < want) {
          interestDone.current = true;
        }
      }

      // الجزء الثاني: عشوائي — يملأ ما تبقّى من الدفعة
      const wantRandom = PAGE - gotInterest;

      if (wantRandom > 0) {
        const from = offset.current;

        const { data: rest } = await supabaseBrowser
          .from('products')
          .select('*')
          .eq('is_available', true)
          .order('created_at', { ascending: false })
          .range(from, from + PAGE - 1);

        const fetched = (rest as Product[]) ?? [];

        const pool = fetched
          .filter((p) => !seen.current.has(p.id))
          .sort(() => Math.random() - 0.5)
          .slice(0, wantRandom);

        batch.push(...pool);

        // المؤشر يتقدّم بمقدار ما جُلب فعلاً
        offset.current = from + fetched.length;
      }

      // إزالة المكرر وخلط الدفعة
      const fresh = batch
        .filter((p) => {
          if (seen.current.has(p.id)) return false;
          seen.current.add(p.id);
          return true;
        })
        .sort(() => Math.random() - 0.5);

      if (fresh.length === 0) {
        setDone(true);
      } else {
        setItems((prev) => [...prev, ...fresh]);
      }
    } catch {
      setDone(true);
    } finally {
      setLoading(false);
    }
  }, [loading, done, loadInterests]);

  // التحميل الأول
  useEffect(() => {
    // التأجيل يمنع تعاقب الرسم — setState يقع بعد الإطار الحالي
    queueMicrotask(() => void loadMore());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // تحميل تلقائي عند الوصول لأسفل القسم
  useEffect(() => {
    const el = sentinel.current;
    if (!el || done) return;

    const io = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) loadMore();
      },
      { rootMargin: '300px' }
    );

    io.observe(el);
    return () => io.disconnect();
  }, [loadMore, done]);

  if (items.length === 0 && done) return null;

  return (
    <section className="mt-5">
      <h2 className="text-base font-bold mb-5">اكتشف المزيد</h2>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
        {items.map((p) => (
          <ProductCard key={p.id} product={p} />
        ))}
      </div>

      <div ref={sentinel} className="h-10" />

      {loading && (
        <p className="text-center text-sm text-gray-500 py-4">
          جاري التحميل...
        </p>
      )}
    </section>
  );
}
