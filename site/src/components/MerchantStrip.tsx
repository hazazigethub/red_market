import Link from 'next/link';
import type { Merchant } from '@/lib/types';

export default function MerchantStrip({ merchants }: { merchants: Merchant[] }) {
  if (merchants.length === 0) return null;

  return (
    <div className="flex gap-3 overflow-x-auto pb-3">
      {merchants.map((m) => (
        <Link prefetch={false}
          key={m.id}
          href={`/store/${m.id}`}
          className="shrink-0 w-15 text-center group"
        >
          <div className="w-15 h-15 mx-auto rounded-full overflow-hidden bg-gray-100 border-2 border-gray-200 group-hover:border-red-400 transition-colors">
            {m.logo_url ? (
              <img
                src={m.logo_url}
                alt={m.store_name ?? ''}
                className="w-full h-full object-cover"
                loading="lazy"
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-gray-300 text-xs">
                متجر
              </div>
            )}
          </div>
          <p className="mt-2 text-xs text-gray-700 leading-4 line-clamp-2">
            {m.store_name ?? 'متجر'}
          </p>
        </Link>
      ))}
    </div>
  );
}