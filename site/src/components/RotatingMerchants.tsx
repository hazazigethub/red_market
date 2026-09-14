'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import type { Merchant, Product } from '@/lib/types';

const SHOW_MOBILE = 6;
const SHOW_DESKTOP = 18;

type Card = {
  merchant: Merchant;
  images: string[];
};

/// بطاقات المتاجر — شعار واسم وثلاث صور من عروضه
export default function RotatingMerchants({
  merchants,
  products = [],
}: {
  merchants: Merchant[];
  products?: Product[];
}) {
  const [visible, setVisible] = useState<Card[]>([]);
  const paused = useRef(false);
  const [count, setCount] = useState(SHOW_MOBILE);

  // عدد البطاقات يتبع عرض الشاشة
  useEffect(() => {
    function sync() {
      setCount(window.innerWidth >= 768 ? SHOW_DESKTOP : SHOW_MOBILE);
    }
    sync();
    window.addEventListener('resize', sync);
    return () => window.removeEventListener('resize', sync);
  }, []);

  useEffect(() => {
    // أول ثلاث صور من عروض كل متجر
    function build(list: Merchant[]): Card[] {
      return list.map((m) => ({
        merchant: m,
        images: products
          .filter((p) => p.merchant_id === m.id)
          .map((p) => p.image_url || p.images_url?.[0] || '')
          .filter(Boolean)
          .slice(0, 3) as string[],
      }));
    }

    function pick() {
      if (merchants.length <= count) {
        setVisible(build(merchants));
        return;
      }
      const shuffled = [...merchants].sort(() => Math.random() - 0.5);
      setVisible(build(shuffled.slice(0, count)));
    }

    pick();

    if (merchants.length <= count) return;

    const t = setInterval(() => {
      if (!paused.current) pick();
    }, 3000);

    return () => clearInterval(t);
  }, [merchants, products, count]);

  if (visible.length === 0) return null;

  return (
    <div
      className="grid grid-cols-3 md:grid-cols-9 gap-2 md:gap-2"
      onMouseEnter={() => (paused.current = true)}
      onMouseLeave={() => (paused.current = false)}
    >
      {visible.map(({ merchant: m, images }) => (
        <Link
          prefetch={false}
          key={m.id}
          href={`/store/${m.id}`}
          className="group block border border-gray-200 rounded-xl overflow-hidden hover:border-red-300 transition-colors"
        >
          {/* الشعار والاسم */}
          <div className="flex flex-col md:flex-row items-center gap-1 md:gap-2 p-2">
            <span className="relative w-9 h-9 md:w-11 md:h-11 shrink-0 rounded-full overflow-hidden bg-gray-100 border block">
              {m.logo_url ? (
                <Image
                  src={m.logo_url}
                  alt=""
                  fill
                  sizes="44px"
                  className="object-cover"
                />
              ) : (
                <span className="w-full h-full flex items-center justify-center text-[9px] text-gray-400">
                  متجر
                </span>
              )}
            </span>

            <p className="w-full md:flex-1 min-w-0 text-[10px] md:text-[11px] font-bold text-gray-800 truncate text-center md:text-start">
              {m.store_name ?? 'متجر'}
            </p>
          </div>

          {/* صور من عروضه */}
          {images.length > 0 && (
            <div className="px-2 pb-2">
              <div className="relative aspect-[4/3] rounded-lg overflow-hidden bg-gray-50">
                <Image
                  src={images[0]}
                  alt=""
                  fill
                  sizes="(max-width: 768px) 33vw, 200px"
                  className="object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>

              {images.length > 1 && (
                <div className="grid grid-cols-2 gap-1 mt-1">
                  {[1, 2].map((i) => (
                    <div
                      key={i}
                      className="relative aspect-square rounded-md overflow-hidden bg-gray-50"
                    >
                      {images[i] && (
                        <Image
                          src={images[i]}
                          alt=""
                          fill
                          sizes="(max-width: 768px) 17vw, 100px"
                          className="object-cover"
                        />
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </Link>
      ))}
    </div>
  );
}
