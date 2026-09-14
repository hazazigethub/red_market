'use client';

import { useEffect, useState } from 'react';
import { UserPlus, UserCheck } from 'lucide-react';
import { supabaseBrowser } from '@/lib/supabase-client';
import LoginModal from '@/components/LoginModal';
import type { User } from '@supabase/supabase-js';

const BRAND = '#D32027';

export default function FollowButton({
  merchantId,
  initialCount,
}: {
  merchantId: string;
  initialCount: number;
}) {
  const [user, setUser] = useState<User | null>(null);
  const [following, setFollowing] = useState(false);
  const [count, setCount] = useState(initialCount);
  const [busy, setBusy] = useState(false);
  const [showLogin, setShowLogin] = useState(false);

  useEffect(() => {
    let active = true;

    async function load() {
      const { data } = await supabaseBrowser.auth.getUser();
      if (!active) return;
      const u = data.user;
      setUser(u);
      if (!u) return;

      const { data: row } = await supabaseBrowser
        .from('merchant_followers')
        .select('id')
        .eq('merchant_id', merchantId)
        .eq('user_id', u.id)
        .maybeSingle();

      if (active) setFollowing(!!row);
    }

    load();
    return () => {
      active = false;
    };
  }, [merchantId]);

  async function refreshUser() {
    const { data } = await supabaseBrowser.auth.getUser();
    setUser(data.user);
  }

  async function toggle() {
    if (busy) return;
    if (!user) {
      setShowLogin(true);
      return;
    }

    setBusy(true);
    try {
      if (following) {
        await supabaseBrowser
          .from('merchant_followers')
          .delete()
          .eq('merchant_id', merchantId)
          .eq('user_id', user.id);
        setFollowing(false);
        setCount((n) => Math.max(0, n - 1));
      } else {
        await supabaseBrowser
          .from('merchant_followers')
          .insert({ merchant_id: merchantId, user_id: user.id });
        setFollowing(true);
        setCount((n) => n + 1);
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      {/* العدّاد هو الزر — الرقم فوق والحالة تحته */}
      <button
        onClick={toggle}
        disabled={busy}
        aria-label={following ? 'إلغاء المتابعة' : 'متابعة المتجر'}
        className="flex flex-col items-center leading-tight disabled:opacity-60 transition-opacity hover:opacity-80"
      >
        <span className="text-xl font-bold text-gray-900">{count}</span>
        <span
          className="text-xs flex items-center gap-1"
          style={{ color: following ? BRAND : '#6b7280' }}
        >
          {following ? <UserCheck size={13} /> : <UserPlus size={13} />}
          {following ? 'تمت المتابعة' : 'متابعة'}
        </span>
      </button>

      <LoginModal
        open={showLogin}
        onClose={() => setShowLogin(false)}
        onSuccess={refreshUser}
      />
    </>
  );
}
