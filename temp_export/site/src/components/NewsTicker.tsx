'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

/// شريط أخبار متحرّك — رسائله تُدار من لوحة الأدمن
export default function NewsTicker() {
  const [messages, setMessages] = useState<string[]>([]);

  /// نسخ تكفي لملء عرض الشريط — وإلا ظهرت الرسائل في نطاق ضيّق
  const [copies, setCopies] = useState(2);
  const boxRef = useRef<HTMLDivElement>(null);
  const stripRef = useRef<HTMLDivElement>(null);

  const measure = useCallback(() => {
    const box = boxRef.current;
    const strip = stripRef.current;
    if (!box || !strip) return;

    const w = strip.offsetWidth;
    if (w <= 0) return;

    setCopies(Math.max(2, Math.ceil(box.offsetWidth / w) + 1));
  }, []);

  useEffect(() => {
    if (messages.length === 0) return;
    measure();

    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, [messages, measure]);

  useEffect(() => {
    let alive = true;

    (async () => {
      try {
        const today = new Date().toISOString().slice(0, 10);

        const { data } = await supabaseBrowser
          .from('ticker_messages')
          .select('text, sort_order, expires_at')
          .eq('is_active', true)
          .in('audience', ['customer', 'all'])
          .order('sort_order');

        if (!alive || !data) return;

        const list = (data as { text: string; expires_at: string | null }[])
          .filter((r) => !r.expires_at || r.expires_at >= today)
          .map((r) => (r.text ?? '').trim())
          .filter((t) => t.length > 0);

        setMessages(list);
      } catch {
        // الشريط تكميلي — لا نُفشل الصفحة
      }
    })();

    return () => {
      alive = false;
    };
  }, []);

  if (messages.length === 0) return null;

  const strip = (i: number) => (
    <div
      key={i}
      ref={i === 0 ? stripRef : undefined}
      className="flex items-center shrink-0"
    >
      {messages.map((m, j) => (
        <span key={j} className="flex items-center">
          <span className="text-xs font-semibold text-gray-700 whitespace-nowrap">
            {m}
          </span>
          <span
            className="inline-block w-1 h-1 rounded-full mx-5"
            style={{ backgroundColor: BRAND }}
          />
        </span>
      ))}
    </div>
  );

  return (
    <div className="flex items-stretch border-b border-gray-200 overflow-hidden"
         style={{ backgroundColor: `${BRAND}0F` }}>
      <div
        ref={boxRef}
        className="flex-1 overflow-hidden py-1.5"
        dir="rtl"
      >
        <div
          className="flex w-max animate-rm-ticker"
          style={{ '--rm-copies': copies } as React.CSSProperties}
        >
          {Array.from({ length: copies }, (_, i) => strip(i))}
        </div>
      </div>

      <style jsx global>{`
        @keyframes rm-ticker {
          from {
            transform: translateX(0);
          }
          to {
            transform: translateX(calc(-100% / var(--rm-copies)));
          }
        }
        .animate-rm-ticker {
          animation: rm-ticker 5s linear infinite;
        }
        .animate-rm-ticker:hover {
          animation-play-state: paused;
        }
        @media (prefers-reduced-motion: reduce) {
          .animate-rm-ticker {
            animation: none;
          }
        }
      `}</style>
    </div>
  );
}
