'use client';

import { useEffect, useState } from 'react';
import { Heart, Eye } from 'lucide-react';
import { supabaseBrowser } from '@/lib/supabase-client';
import LoginModal from '@/components/LoginModal';
import type { User } from '@supabase/supabase-js';

const BRAND = '#D32027';

function formatCount(n: number): string {
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
  return `${n}`;
}

export default function ProductCardStats({
  productId,
  initialLikes,
  views,
}: {
  productId: string;
  initialLikes: number;
  views: number;
}) {
  const [user, setUser] = useState<User | null>(null);
  const [liked, setLiked] = useState(false);
  const [likes, setLikes] = useState(initialLikes);
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
        .from('product_likes')
        .select('product_id')
        .eq('product_id', productId)
        .eq('user_id', u.id)
        .maybeSingle();

      if (active) setLiked(!!row);
    }

    load();
    return () => {
      active = false;
    };
  }, [productId]);

  async function refreshUser() {
    const { data } = await supabaseBrowser.auth.getUser();
    setUser(data.user);
  }

  async function toggleLike(e: React.MouseEvent) {
    e.preventDefault();
    e.stopPropagation();

    if (busy) return;
    if (!user) {
      setShowLogin(true);
      return;
    }

    setBusy(true);
    try {
      if (liked) {
        await supabaseBrowser
          .from('product_likes')
          .delete()
          .eq('product_id', productId)
          .eq('user_id', user.id);
        setLiked(false);
        setLikes((n) => Math.max(0, n - 1));
      } else {
        await supabaseBrowser
          .from('product_likes')
          .insert({ product_id: productId, user_id: user.id });
        setLiked(true);
        setLikes((n) => n + 1);
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="flex flex-col items-end gap-1 shrink-0 pl-2 pb-1">
        <button
          onClick={toggleLike}
          disabled={busy}
          aria-label="إعجاب"
          // ارتفاع 24 ومسافة جانبية — لمعيار حجم هدف اللمس
          className="flex items-center gap-1 min-h-6 px-1 -mx-1 disabled:opacity-60"
          style={{ color: BRAND }}
        >
          {likes > 0 && (
            <span className="text-xs font-bold">{formatCount(likes)}</span>
          )}
          <Heart size={20} fill={liked ? 'currentColor' : 'none'} />
        </button>

        {views > 0 && (
          <span className="flex items-center gap-1 text-slate-500">
            <span className="text-xs">{formatCount(views)}</span>
            <Eye size={20} />
          </span>
        )}
      </div>

      <LoginModal
        open={showLogin}
        onClose={() => setShowLogin(false)}
        onSuccess={refreshUser}
      />
    </>
  );
}
