'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { bannerHref, type Banner } from '@/lib/bannerLink';
import { trackImpression, trackClick } from '@/lib/bannerTracking';

const SHOW_MOBILE = 2;
const SHOW_DESKTOP = 4;

export default function SmallBanners({ banners }: { banners: Banner[] }) {
  const [count, setCount] = useState(SHOW_MOBILE);
  const [start, setStart] = useState(0);

  // عدد البنرات يتبع عرض الشاشة
  useEffect(() => {
    function sync() {
      setCount(window.innerWidth >= 768 ? SHOW_DESKTOP : SHOW_MOBILE);
    }
    sync();
    window.addEventListener('resize', sync);
    return () => window.removeEventListener('resize', sync);
  }, []);

  // تبديل دوري — يتوقّف إن كان العدد لا يفيض
  useEffect(() => {
    if (banners.length <= count) {
      setStart(0);
      return;
    }
    const t = setInterval(() => {
      setStart((s) => (s + count) % banners.length);
    }, 3000);
    return () => clearInterval(t);
  }, [banners.length, count]);

  if (banners.length === 0) return null;

  // شريحة دائرية بطول count
  const visible = Array.from({ length: Math.min(count, banners.length) }).map(
    (_, i) => banners[(start + i) % banners.length]
  );

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
      {visible.map((b, i) => (
        <SmallBannerCell key={`${b.id}-${i}`} banner={b} />
      ))}
    </div>
  );
}

/// بنر واحد يرصد ظهوره
function SmallBannerCell({ banner }: { banner: Banner }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const obs = new IntersectionObserver(
      ([entry]) => {
        if (entry.intersectionRatio >= 0.99) {
          trackImpression(banner.booking_id);
        }
      },
      { threshold: [0, 0.99, 1] }
    );

    obs.observe(el);
    return () => obs.disconnect();
  }, [banner.booking_id]);

  const href = bannerHref(banner);

  // تسمية لقارئ الشاشة — فالصورة بلا نصّ بديل
  const label =
    banner.target_type === 'product'
      ? 'إعلان — الانتقال لصفحة العرض'
      : banner.target_type === 'store'
        ? 'إعلان — الانتقال لصفحة المتجر'
        : banner.target_type === 'category'
          ? 'إعلان — الانتقال لصفحة التصنيف'
          : 'إعلان';

  const cell = (
    <Image
      src={banner.image_url ?? ''}
      alt=""
      fill
      sizes="(max-width: 768px) 50vw, 25vw"
      className="object-cover hover:scale-105 transition-transform duration-300"
    />
  );

  return (
    <div
      ref={ref}
      className="relative rounded-[12px] overflow-hidden bg-gray-100 aspect-[19/10]"
    >
      {href ? (
        <Link
          prefetch={false}
          href={href}
          aria-label={label}
          onClick={() => trackClick(banner.booking_id)}
          className="block relative w-full h-full"
        >
          {cell}
        </Link>
      ) : (
        cell
      )}
    </div>
  );
}
