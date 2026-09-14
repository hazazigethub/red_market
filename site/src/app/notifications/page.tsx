'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { User } from '@supabase/supabase-js';

const BRAND = '#D32027';

type Notif = {
  id: string;
  title: string | null;
  body: string | null;
  target_type: string | null;
  target_id: string | null;
  segment_filter: string | null;
  created_at: string | null;
  scheduled_at: string | null;
  is_read: boolean | null;
  icon_type: string | null;
  product_id: string | null;
  reel_id: string | null;
  newsletter_id: string | null;
};

export default function NotificationsPage() {
  const [user, setUser] = useState<User | null>(null);
  const [items, setItems] = useState<Notif[]>([]);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    async function load() {
      const { data } = await supabaseBrowser.auth.getUser();
      const u = data.user;
      setUser(u);

      if (!u) {
        setReady(true);
        return;
      }

      // إطلاق الإشعارات المجدولة التي حان موعدها
      try {
        await supabaseBrowser.rpc('release_due_notifications');
      } catch {
        // فشل الإطلاق لا يمنع عرض الموجود
      }

      const { data: rows } = await supabaseBrowser
        .from('notifications_log')
        .select('*')
        .eq('status', 'sent')
        .order('created_at', { ascending: false })
        .limit(100);

      // الإشعارات التي قرأها هذا المستخدم
      const { data: reads } = await supabaseBrowser
        .from('notification_reads')
        .select('notification_id')
        .eq('user_id', u.id);

      // المتاجر التي يتابعها
      const { data: follows } = await supabaseBrowser
        .from('merchant_followers')
        .select('merchant_id')
        .eq('user_id', u.id);

      const followed = new Set(
        (follows ?? []).map((f) => f.merchant_id as string)
      );

      const readSet = new Set(
        (reads ?? []).map((r) => r.notification_id as string)
      );

      const list = ((rows as Notif[]) ?? []).filter((n) => {
        const type = n.target_type;
        if (type === 'all') return true;
        if (type === 'specific' && n.target_id === u.id) return true;
        if (type === 'segment' && n.segment_filter) {
          return n.segment_filter.includes('users');
        }
        if (type === 'followers' && n.target_id) {
          return followed.has(n.target_id);
        }
        return false;
      });

      setItems(list.map((n) => ({ ...n, is_read: readSet.has(n.id) })));
      setReady(true);
    }
    load();
  }, []);

  async function markRead(id: string) {
    if (busy || !user) return;
    setBusy(true);
    try {
      await supabaseBrowser
        .from('notification_reads')
        .upsert(
          { user_id: user.id, notification_id: id },
          { onConflict: 'user_id,notification_id' }
        );
      setItems((prev) =>
        prev.map((n) => (n.id === id ? { ...n, is_read: true } : n))
      );
      window.dispatchEvent(new Event('notifications-updated'));
    } finally {
      setBusy(false);
    }
  }

  async function remove(id: string) {
    if (busy) return;
    setBusy(true);
    try {
      await supabaseBrowser.from('notifications_log').delete().eq('id', id);
      setItems((prev) => prev.filter((n) => n.id !== id));
      window.dispatchEvent(new Event('notifications-updated'));
    } finally {
      setBusy(false);
    }
  }

  function fmt(d: string | null) {
    if (!d) return '';
    const date = new Date(d);
    return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`;
  }

  if (!ready) {
    return (
      <main className="max-w-2xl mx-auto px-4 py-16">
        <p className="text-center text-gray-500">جاري التحميل...</p>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="max-w-md mx-auto px-4 py-20 text-center">
        <h1 className="text-2xl font-bold mb-4">الإشعارات</h1>
        <p className="text-gray-600 mb-6">سجّل الدخول لعرض إشعاراتك</p>
        <Link
          href="/login"
          className="inline-block px-8 py-3 rounded-lg text-white font-bold"
          style={{ backgroundColor: BRAND }}
        >
          تسجيل الدخول
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-2xl mx-auto px-4 py-10">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">الإشعارات</h1>
        <span className="text-sm text-gray-500">{items.length}</span>
      </div>

      {items.length === 0 ? (
        <p className="text-center text-gray-500 py-20">لا توجد إشعارات</p>
      ) : (
        <ul className="space-y-3">
          {items.map((n) => (
            <li
              key={n.id}
              onClick={() => !n.is_read && markRead(n.id)}
              className={`border rounded-xl p-5 cursor-pointer transition-colors ${
                n.is_read
                  ? 'border-gray-200 bg-white'
                  : 'border-red-200 bg-red-50/40'
              }`}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    {!n.is_read && (
                      <span
                        className="w-2 h-2 rounded-full shrink-0"
                        style={{ backgroundColor: BRAND }}
                      />
                    )}
                    <h2 className="font-bold text-gray-900">
                      {n.title ?? 'إشعار'}
                    </h2>
                  </div>

                  {n.body && (
                    <p className="mt-2 text-sm text-gray-600 leading-6">
                      {n.body}
                    </p>
                  )}

                  <p className="mt-2 text-xs text-gray-500">
                    {fmt(n.scheduled_at ?? n.created_at)}
                  </p>

                  {(n.product_id || n.reel_id || n.newsletter_id) && (
                    <Link
                      href={
                        n.newsletter_id
                          ? `/newsletter/${n.newsletter_id}`
                          : n.product_id
                            ? `/offer/${n.product_id}`
                            : `/reels`
                      }
                      onClick={(e) => e.stopPropagation()}
                      className="inline-block mt-3 text-xs font-bold hover:opacity-80"
                      style={{ color: BRAND }}
                    >
                      {n.newsletter_id
                        ? 'تصفّح النشرة'
                        : n.product_id
                          ? 'فتح العرض'
                          : 'مشاهدة الريلز'}
                    </Link>
                  )}
                </div>

                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    remove(n.id);
                  }}
                  disabled={busy}
                  aria-label="حذف"
                  className="text-gray-300 hover:text-red-600 text-sm shrink-0 disabled:opacity-50"
                >
                  ✕
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}