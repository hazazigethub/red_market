'use client';

import { useState } from 'react';
import { Share2, Check } from 'lucide-react';

export default function ShareButton({ name }: { name: string }) {
  const [done, setDone] = useState(false);

  async function share() {
    const url = window.location.href;
    try {
      if (navigator.share) {
        await navigator.share({ title: name, url });
      } else {
        await navigator.clipboard.writeText(url);
        setDone(true);
        setTimeout(() => setDone(false), 2000);
      }
    } catch {
      // المستخدم ألغى المشاركة
    }
  }

  return (
    <button
      onClick={share}
      aria-label="مشاركة المتجر"
      title="مشاركة المتجر"
      className="w-12 h-12 rounded-full flex items-center justify-center text-gray-700 hover:bg-gray-100 transition-colors"
    >
      {done ? <Check size={26} /> : <Share2 size={26} strokeWidth={1.7} />}
    </button>
  );
}
