'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

type Card = {
  id: string;
  name: string;
  images: string[];
  count: number;
  big: boolean;
};

export default function CategoryShowcase() {
  const [cards, setCards] = useState<Card[]>([]);
  const paused = useRef(false);

  const load = useCallback(async () => {
      // 1) العروض المتاحة مع تصنيفاتها
      const { data: rows } = await supabaseBrowser
        .from('products')
        .select('id, image_url, images_url, category_id')
        .eq('is_available', true)
        .not('category_id', 'is', null)
        .limit(500);

      const products = rows ?? [];
      if (products.length === 0) return;

      // 2) تجميع الصور حسب التصنيف
      const byCat = new Map<string, string[]>();
      products.forEach((p) => {
        const cid = p.category_id as string;
        const img =
          (p.image_url as string | null) ||
          ((p.images_url as string[] | null) ?? [])[0] ||
          null;
        if (!img) return;
        const arr = byCat.get(cid) ?? [];
        arr.push(img);
        byCat.set(cid, arr);
      });

      const catIds = [...byCat.keys()];
      if (catIds.length === 0) return;

      // 3) أسماء التصنيفات
      const { data: cats } = await supabaseBrowser
        .from('product_categories')
        .select('id, name')
        .in('id', catIds)
        .eq('is_visible', true);

      const names = new Map(
        (cats ?? []).map((c) => [c.id as string, (c.name as string) ?? 'تصنيف'])
      );

      const pool = catIds
        .filter((id) => names.has(id))
        .sort(() => Math.random() - 0.5);

      if (pool.length === 0) return;

      // 4) نمطان يتناوبان عشوائياً:
      //    أ) ثماني بطاقات صغيرة
      //    ب) بطاقة كبيرة بأربع صور + أربع صغيرة
      const richIndex = pool.findIndex(
        (id) => (byCat.get(id) ?? []).length >= 4
      );
      const wantBig = Math.random() < 0.5 && richIndex !== -1;

      const built: Card[] = [];

      if (wantBig) {
        const bigId = pool[richIndex];
        const bigImgs = [...(byCat.get(bigId) ?? [])].sort(
          () => Math.random() - 0.5
        );
        built.push({
          id: bigId,
          name: names.get(bigId) ?? 'تصنيف',
          images: bigImgs.slice(0, 4),
          count: bigImgs.length,
          big: true,
        });

        pool
          .filter((id) => id !== bigId)
          .slice(0, 8)
          .forEach((id) => {
            const imgs = [...(byCat.get(id) ?? [])].sort(
              () => Math.random() - 0.5
            );
            built.push({
              id,
              name: names.get(id) ?? 'تصنيف',
              images: imgs.slice(0, 1),
              count: imgs.length,
              big: false,
            });
          });
      } else {
        pool.slice(0, 12).forEach((id) => {
          const imgs = [...(byCat.get(id) ?? [])].sort(
            () => Math.random() - 0.5
          );
          built.push({
            id,
            name: names.get(id) ?? 'تصنيف',
            images: imgs.slice(0, 1),
            count: imgs.length,
            big: false,
          });
        });
      }

    setCards(built);
  }, []);

  // تبديل عشوائي كل 5 ثوانٍ، يتوقف عند تمرير الماوس
  useEffect(() => {
    // التأجيل يمنع تعاقب الرسم — setState يقع بعد الإطار الحالي
    queueMicrotask(() => void load());

    const t = setInterval(() => {
      if (!paused.current) load();
    }, 5000);

    return () => clearInterval(t);
  }, [load]);

  if (cards.length === 0) return null;

  return (
    <section className="mt-5">
      <h2 className="text-base font-bold mb-5">تصفّح التصنيفات</h2>

      <div
        className="grid grid-cols-2 md:grid-cols-6 gap-4"
        onMouseEnter={() => (paused.current = true)}
        onMouseLeave={() => (paused.current = false)}
      >
        {cards.map((c) => (
          <Link prefetch={false}
            key={c.id}
            href={`/category-offers/${c.id}`}
            className={`group relative rounded-none overflow-hidden bg-gray-50 hover:shadow-lg transition-shadow ${
              c.big
                ? 'md:col-span-2 md:row-span-2 border-2 p-2 aspect-square'
                : 'border border-gray-200 aspect-square'
            }`}
            style={c.big ? { borderColor: BRAND } : undefined}
          >
            {c.big ? (
              <div className="grid grid-cols-2 grid-rows-2 gap-2 w-full h-full">
                {c.images.map((src, i) => (
                  <span
                    key={i}
                    className="relative block overflow-hidden rounded-none bg-white border border-gray-100"
                  >
                    <Image
                      src={src}
                      alt=""
                      fill
                      sizes="(max-width: 768px) 25vw, 150px"
                      className="object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </span>
                ))}
              </div>
            ) : (
              <Image
                src={c.images[0]}
                alt=""
                fill
                sizes="(max-width: 768px) 50vw, 200px"
                className="object-cover group-hover:scale-105 transition-transform duration-300"
              />
            )}

            <div
              className={`absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/75 to-transparent px-3 pt-8 pb-3 ${
                c.big ? 'mx-2 mb-2' : ''
              }`}
            >
              <p className="text-white font-bold text-sm leading-5 line-clamp-2">
                {c.name}
              </p>
              <p className="text-white/70 text-[11px] mt-0.5">{c.count} عرض</p>
            </div>

            <span
              className="absolute top-3 right-3 text-white text-[10px] font-bold px-2 py-1 rounded-none opacity-0 group-hover:opacity-100 transition-opacity"
              style={{ backgroundColor: BRAND }}
            >
              تصفّح
            </span>
          </Link>
        ))}
      </div>
    </section>
  );
}
