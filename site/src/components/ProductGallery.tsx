'use client';

import { useState } from 'react';
import Image from 'next/image';

const BRAND = '#D32027';

export default function ProductGallery({
  images,
  alt,
}: {
  images: string[];
  alt: string;
}) {
  const [active, setActive] = useState(0);

  if (images.length === 0) {
    return (
      <div className="relative aspect-square md:w-[525px] md:h-[525px] rounded-xl overflow-hidden bg-gray-50 border">
        <div className="w-full h-full flex items-center justify-center text-gray-300">
          لا توجد صورة
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* الصورة الكبيرة */}
      {/* الجوال بعرض الشاشة — والحاسب 525 ثابتة */}
      <div className="relative aspect-square md:w-[525px] md:h-[525px] rounded-xl overflow-hidden bg-gray-50 border">
        {images.map((src, i) => (
          <Image
            key={src}
            src={src}
            alt={alt}
            fill
            sizes="(max-width: 768px) 100vw, 525px"
            // الأولى هي عنصر LCP — تُحمَّل بأولوية
            priority={i === 0}
            fetchPriority={i === 0 ? 'high' : 'auto'}
            className={`object-cover transition-opacity duration-200 ${
              i === active ? 'opacity-100' : 'opacity-0'
            }`}
          />
        ))}
      </div>

      {/* المصغّرات — بعدد الصور الموجودة فقط */}
      {images.length > 1 && (
        <div className="flex gap-2 mt-3 md:w-[525px]">
          {images.map((src, i) => (
            <button
              key={src}
              onClick={() => setActive(i)}
              aria-label={`عرض الصورة ${i + 1}`}
              className="relative flex-1 aspect-square rounded-lg overflow-hidden bg-gray-50 border-2 transition-colors"
              style={{
                borderColor: i === active ? BRAND : 'rgb(229, 231, 235)',
              }}
            >
              <Image
                src={src}
                alt=""
                fill
                sizes="(max-width: 768px) 25vw, 128px"
                className="object-cover"
              />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
