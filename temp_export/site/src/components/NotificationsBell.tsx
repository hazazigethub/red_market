'use client';

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { BellRing } from 'lucide-react';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

export default function NotificationsBell() {
  const [count, setCount] = useState(0);

  const load = useCallback(async () => {
    const { data: auth } = await supabaseBrowser.auth.getUser();
    const u = auth.user;
    if (!u) {
      setCount(0);
      return;
    }

    try {
      await supabaseBrowser.rpc('release_due_notifications');
    } catch {
      // تجاهل
    }

    const [notifRes, readsRes, followRes] = await Promise.all([
      supabaseBrowser
        .from('notifications_log')
        .select('id, target_type, target_id, segment_filter')
        .eq('status', 'sent')
        .limit(200),
      supabaseBrowser
        .from('notification_reads')
        .select('notification_id')
        .eq('user_id', u.id),
      supabaseBrowser
        .from('merchant_followers')
        .select('merchant_id')
        .eq('user_id', u.id),
    ]);

    const followed = new Set(
      (followRes.data ?? []).map((f) => f.merchant_id as string)
    );

    const readSet = new Set(
      (readsRes.data ?? []).map((r) => r.notification_id as string)
    );

    const mine = (notifRes.data ?? []).filter((n) => {
      const type = n.target_type;
      if (type === 'all') return true;
      if (type === 'specific' && n.target_id === u.id) return true;
      if (type === 'segment' && n.segment_filter) {
        return String(n.segment_filter).includes('users');
      }
      if (type === 'followers' && n.target_id) {
        return followed.has(n.target_id as string);
      }
      return false;
    });

    setCount(mine.filter((n) => !readSet.has(n.id as string)).length);
  }, []);

  useEffect(() => {
    // التأجيل يمنع تعاقب الرسم — setState يقع بعد الإطار الحالي
    queueMicrotask(() => void load());

    const { data: sub } = supabaseBrowser.auth.onAuthStateChange(() => load());
    window.addEventListener('notifications-updated', load);

    return () => {
      sub.subscription.unsubscribe();
      window.removeEventListener('notifications-updated', load);
    };
  }, [load]);

  return (
    <Link
      href="/notifications"
      aria-label="الإشعارات"
      title="الإشعارات"
      style={{ color: '#D32027' }}
      className="relative w-11 h-11 rounded-full flex items-center justify-center hover:bg-gray-100 transition-colors"
    >
      <BellRing size={30} strokeWidth={1.6} />

      {count > 0 && (
        <span
          className="absolute top-1 left-1 min-w-[18px] h-[18px] px-1 rounded-full text-white text-[10px] font-bold flex items-center justify-center"
          style={{ backgroundColor: BRAND }}
        >
          {count > 99 ? '99+' : count}
        </span>
      )}
    </Link>
  );
}
