'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { bannerHref, type Banner } from '@/lib/bannerLink';
import { trackImpression, trackClick } from '@/lib/bannerTracking';

export default function HeroBanner({ banners }: { banners: Banner[] }) {
  const [index, setIndex] = useState(0);
  // الشرائح المسموح بتحميلها — تبدأ بالأولى وحدها
  const [loaded, setLoaded] = useState<Set<number>>(() => new Set([0]));
  const [visible, setVisible] = useState(false);
  const boxRef = useRef<HTMLDivElement>(null);

  const next = useCallback(() => {
    setIndex((i) => {
      const n = (i + 1) % banners.length;
      setLoaded((prev) => {
        if (prev.has(n)) return prev;
        const copy = new Set(prev);
        copy.add(n);
        return copy;
      });
      return n;
    });
  }, [banners.length]);

  useEffect(() => {
    if (banners.length <= 1) return;
    const t = setInterval(next, 3000);
    return () => clearInterval(t);
  }, [banners.length, next]);

  // يرصد ظهور البنر كاملاً في الشاشة
  useEffect(() => {
    const el = boxRef.current;
    if (!el) return;

    const obs = new IntersectionObserver(
      ([entry]) => setVisible(entry.intersectionRatio >= 0.99),
      { threshold: [0, 0.99, 1] }
    );

    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  // يُحتسب الظهور للشريحة الحالية متى كانت ظاهرة كاملة
  useEffect(() => {
    if (!visible) return;
    const b = banners[index];
    if (b) trackImpression(b.booking_id);
  }, [visible, index, banners]);

  if (banners.length === 0) return null;

  const current = banners[index];
  const href = bannerHref(current);

  // تسمية لقارئ الشاشة — فصور البنر بلا نصّ بديل
  const label =
    current.target_type === 'product'
      ? 'إعلان — الانتقال لصفحة العرض'
      : current.target_type === 'store'
        ? 'إعلان — الانتقال لصفحة المتجر'
        : current.target_type === 'category'
          ? 'إعلان — الانتقال لصفحة التصنيف'
          : 'إعلان';

  // كل الشرائح تبقى في الشجرة — فلا يتغيّر التخطيط
  // لكن غير المرئية لا تُحمَّل إلا بعد أن يحين دورها
  const slides = (
    <>
      {banners.map((b, i) => (
        <div
          key={b.id}
          className={`absolute inset-0 transition-opacity duration-700 ${
            i === index ? 'opacity-100' : 'opacity-0'
          }`}
        >
          {loaded.has(i) && (
            <Image
              src={b.image_url ?? ''}
              alt=""
              fill
              // الشريحة الأولى هي عنصر LCP — تُحمَّل بأولوية قصوى
              priority={i === 0}
              fetchPriority={i === 0 ? 'high' : 'auto'}
              sizes="(max-width: 768px) 100vw, 1200px"
              className="object-cover"
            />
          )}
        </div>
      ))}
    </>
  );

  return (
    <div className="relative w-full">
      <div ref={boxRef}>
        {href ? (
          <Link prefetch={false}
            href={href}
            aria-label={label}
            onClick={() => trackClick(current.booking_id)}
            className="block relative w-full aspect-[30/7] rounded-[15px] overflow-hidden bg-gray-100"
          >
            {slides}
          </Link>
        ) : (
          <div className="relative w-full aspect-[30/7] rounded-[15px] overflow-hidden bg-gray-100">
            {slides}
          </div>
        )}
      </div>

      {banners.length > 1 && (
        <div className="flex justify-center gap-1 mt-1">
          {banners.map((_, i) => (
            <button
              key={i}
              onClick={() => setIndex(i)}
              aria-label={`بنر ${i + 1}`}
              // منطقة لمس 24×24 — والنقطة داخلها تبقى صغيرة بصرياً
              className="w-6 h-6 flex items-center justify-center"
            >
              <span
                className={`h-2 rounded-full transition-all block ${
                  i === index ? 'w-6 bg-gray-700' : 'w-2 bg-gray-300'
                }`}
              />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
