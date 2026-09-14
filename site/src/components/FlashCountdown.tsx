'use client';

import { useEffect, useState } from 'react';
import { Clock } from 'lucide-react';

const BRAND = '#D32027';

function two(n: number) {
  return n.toString().padStart(2, '0');
}

export default function FlashCountdown({ expiry }: { expiry: string }) {
  const [left, setLeft] = useState<number>(() => {
    const ms = new Date(expiry).getTime() - Date.now();
    return ms > 0 ? Math.floor(ms / 1000) : 0;
  });

  useEffect(() => {
    if (left <= 0) return;
    const t = setInterval(() => {
      const ms = new Date(expiry).getTime() - Date.now();
      setLeft(ms > 0 ? Math.floor(ms / 1000) : 0);
    }, 1000);
    return () => clearInterval(t);
  }, [expiry, left]);

  if (left <= 0) return null;

  const h = Math.floor(left / 3600);
  const m = Math.floor((left % 3600) / 60);
  const s = left % 60;

  return (
    <span
      className="absolute top-1.5 left-1.5 z-10 flex items-center gap-1 px-1.5 py-0.5 rounded-md text-white"
      style={{ backgroundColor: `${BRAND}E6` }}
    >
      <Clock size={15} strokeWidth={3} />
      <span
        className="text-[15px] font-bold"
        style={{ direction: 'ltr' }}
      >
        {two(h)}:{two(m)}:{two(s)}
      </span>
    </span>
  );
}
