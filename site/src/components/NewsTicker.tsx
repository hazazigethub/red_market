'use client';

import { useEffect, useState } from 'react';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

/// شريط أخبار متحرّك — رسائله تُدار من لوحة الأدمن
export default function NewsTicker() {
  const [messages, setMessages] = useState<string[]>([]);

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

  const strip = (
    <div className="flex items-center shrink-0">
      {messages.map((m, i) => (
        <span key={i} className="flex items-center">
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
      <span
        className="flex items-center px-3 shrink-0"
        style={{ backgroundColor: BRAND }}
        aria-hidden
      >
        <svg
          className="w-3.5 h-3.5 text-white"
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          viewBox="0 0 24 24"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M3 11v2a1 1 0 001 1h2l4 4V6L6 10H4a1 1 0 00-1 1z" />
          <path d="M15 9a3 3 0 010 6" />
        </svg>
      </span>

      <div className="flex-1 overflow-hidden py-1.5" dir="ltr">
        <div className="flex w-max animate-rm-ticker">
          {strip}
          {strip}
        </div>
      </div>

      <style jsx global>{`
        @keyframes rm-ticker {
          from {
            transform: translateX(0);
          }
          to {
            transform: translateX(-50%);
          }
        }
        .animate-rm-ticker {
          animation: rm-ticker 32s linear infinite;
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
