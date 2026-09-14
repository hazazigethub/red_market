import Link from 'next/link';
import type { Category } from '@/lib/types';

const BRAND = '#D32027';

export default function CategoryStrip({
  categories,
}: {
  categories: Category[];
}) {
  return (
    <div className="flex gap-2 overflow-x-auto pb-2 -mx-1 px-1">
      <Link prefetch={false}
        href="/categories"
        className="shrink-0 w-[68px] h-[68px] md:w-[76px] md:h-[76px] rounded-lg text-white text-[10px] md:text-[12px] font-bold leading-tight flex items-center justify-center text-center px-1.5 hover:opacity-90 transition-opacity"
        style={{ backgroundColor: BRAND }}
      >
        جميع التصنيفات
      </Link>

      {categories.map((c) => (
        <Link prefetch={false}
          key={c.id}
          href={`/category/${c.id}`}
          className="shrink-0 w-[68px] h-[68px] md:w-[76px] md:h-[76px] rounded-lg border bg-white text-[10px] md:text-[12px] font-bold leading-tight text-gray-700 flex items-center justify-center text-center px-1.5 hover:bg-red-50 transition-colors"
          style={{ borderColor: BRAND }}
        >
          <span className="line-clamp-3">{c.name ?? 'تصنيف'}</span>
        </Link>
      ))}
    </div>
  );
}
