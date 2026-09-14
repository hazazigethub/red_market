import Link from 'next/link';
import Image from 'next/image';
import type { Product } from '@/lib/types';
import ProductCardStats from '@/components/ProductCardStats';
import FlashCountdown from '@/components/FlashCountdown';

const BRAND = '#D32027';
const LIGHT_RED = '#D32027';

function Price({
  value,
  strike = false,
}: {
  value: number;
  strike?: boolean;
}) {
  return (
    <span className="inline-flex items-center gap-1">
      <span className={strike ? 'line-through' : undefined}>
        {value.toLocaleString('en-US')}
      </span>
      <Image src="/sar.svg" alt="ر.س" width={15} height={15} className="inline-block opacity-80" />
    </span>
  );
}

export default function ProductCard({ product }: { product: Product }) {
  const price = product.discount_price ?? product.price ?? 0;
  const oldPrice = product.old_price;
  const hasDiscount = oldPrice != null && oldPrice > price;
  const percent = hasDiscount ? Math.round(((oldPrice - price) / oldPrice) * 100) : 0;

  const img = product.image_url || product.images_url?.[0] || null;

  return (
    <Link prefetch={false}
      href={`/offer/${product.id}`}
className="group block bg-white border border-gray-100 rounded-none overflow-hidden hover:shadow-none transition-shadow"    >
      <div className="relative aspect-square bg-gray-50 overflow-hidden">
        {img ? (
          <Image
            src={img}
            alt={product.name ?? 'عرض'}
            fill
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 200px"
            className="object-cover group-hover:scale-105 transition-transform duration-300"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-gray-300 text-sm">
            لا توجد صورة
          </div>
        )}

        {product.is_flash_sale && product.flash_sale_expiry && (
          <FlashCountdown expiry={product.flash_sale_expiry} />
        )}
        {!product.is_flash_sale && product.is_offer && (
          <span className="absolute top-2 right-2 bg-amber-500 text-white text-[11px] font-bold px-2.5 py-1 rounded">
            عرض
          </span>
        )}
      </div>

      <div className="p-1">
        {/* ارتفاع ثابت — يمنع قفز التخطيط عند تبديل العروض */}
        <p className="text-[11px] text-gray-500 mb-1 truncate h-4">
          {product.store_name ?? ''}
        </p>

        <p className="text-sm leading-6 truncate text-gray-800">
          {product.name ?? 'بدون اسم'}
        </p>

        <div className="mt-2 h-6 flex items-center gap-2 overflow-hidden">
          {hasDiscount && (
            <>
              <span
                className="text-xs text-gray-500 line-through"
              >
                <Price value={oldPrice} strike />
              </span>
              <span
                className="text-[11px] font-bold text-white px-2 py-0.5 rounded"
                style={{ backgroundColor: LIGHT_RED }}
              >
                {percent}%
              </span>
            </>
          )}
        </div>

        <div className="mt-0 flex items-end justify-between gap-2">
          <div className="text-base font-bold" style={{ color: BRAND }}>
            <Price value={price} />
          </div>

          <ProductCardStats
            productId={product.id}
            initialLikes={product.likes_count ?? 0}
            views={product.views_count ?? 0}
          />
        </div>
      </div>
    </Link>
  );
}