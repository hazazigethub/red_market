'use client';

import { useEffect, useState } from 'react';
import { supabaseBrowser } from '@/lib/supabase-client';
import LoginModal from '@/components/LoginModal';
import type { User } from '@supabase/supabase-js';

const BRAND = '#D32027';

type Comment = {
  id: string;
  content: string | null;
  created_at: string | null;
  user_id: string | null;
  author?: string;
};

export default function ProductInteractions({
  productId,
  initialLikes,
}: {
  productId: string;
  initialLikes: number;
}) {
  const [user, setUser] = useState<User | null>(null);
  const [liked, setLiked] = useState(false);
  const [likes, setLikes] = useState(initialLikes);
  const [faved, setFaved] = useState(false);
  const [comments, setComments] = useState<Comment[]>([]);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [showLogin, setShowLogin] = useState(false);

  useEffect(() => {
    let active = true;

    async function load() {
      const { data: u } = await supabaseBrowser.auth.getUser();
      if (!active) return;
      const current = u.user;
      setUser(current);

      const rows = await supabaseBrowser
        .from('product_comments')
        .select('id, content, created_at, user_id')
        .eq('product_id', productId)
        .order('created_at', { ascending: false })
        .limit(50);

      const list = (rows.data as Comment[]) ?? [];

      const ids = [...new Set(list.map((c) => c.user_id).filter(Boolean))];
      if (ids.length > 0) {
        const profs = await supabaseBrowser
          .from('profiles')
          .select('id, full_name, name')
          .in('id', ids as string[]);

        const map = new Map(
          (profs.data ?? []).map((p) => [
            p.id,
            p.full_name || p.name || 'مستخدم',
          ])
        );
        list.forEach((c) => {
          c.author = c.user_id ? map.get(c.user_id) ?? 'مستخدم' : 'مستخدم';
        });
      }

      if (!active) return;
      setComments(list);

      if (current) {
        const [likeRes, favRes] = await Promise.all([
          supabaseBrowser
            .from('product_likes')
            .select('product_id')
            .eq('product_id', productId)
            .eq('user_id', current.id)
            .maybeSingle(),
          supabaseBrowser
            .from('favorites')
            .select('id')
            .eq('product_id', productId)
            .eq('user_id', current.id)
            .maybeSingle(),
        ]);
        if (!active) return;
        setLiked(!!likeRes.data);
        setFaved(!!favRes.data);
      }
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

  async function toggleLike() {
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

  async function toggleFav() {
    if (busy) return;
    if (!user) {
      setShowLogin(true);
      return;
    }
    setBusy(true);
    try {
      if (faved) {
        await supabaseBrowser
          .from('favorites')
          .delete()
          .eq('product_id', productId)
          .eq('user_id', user.id);
        setFaved(false);
      } else {
        await supabaseBrowser
          .from('favorites')
          .insert({ product_id: productId, user_id: user.id });
        setFaved(true);
      }
    } finally {
      setBusy(false);
    }
  }

  async function addComment(e: React.FormEvent) {
    e.preventDefault();
    if (!user || !text.trim() || busy) return;
    setBusy(true);
    try {
      const { data, error } = await supabaseBrowser
        .from('product_comments')
        .insert({
          product_id: productId,
          user_id: user.id,
          content: text.trim(),
        })
        .select('id, content, created_at, user_id')
        .single();

      if (!error && data) {
        setComments((prev) => [
          { ...(data as Comment), author: 'أنت' },
          ...prev,
        ]);
        setText('');
      }
    } finally {
      setBusy(false);
    }
  }

  async function deleteComment(id: string) {
    if (!user || busy) return;
    setBusy(true);
    try {
      await supabaseBrowser.from('product_comments').delete().eq('id', id);
      setComments((prev) => prev.filter((c) => c.id !== id));
    } finally {
      setBusy(false);
    }
  }

  function fmt(d: string | null) {
    if (!d) return '';
    const date = new Date(d);
    return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`;
  }

  return (
    <div className="mt-8">
      <div className="flex items-center gap-3">
        <button
          onClick={toggleLike}
          disabled={busy}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg border text-sm transition-colors ${
            liked
              ? 'border-red-300 bg-red-50 text-red-700'
              : 'border-gray-300 text-gray-700 hover:border-red-300'
          } disabled:opacity-50`}
        >
          <span>{liked ? '♥' : '♡'}</span>
          <span>{likes}</span>
        </button>

        <button
          onClick={toggleFav}
          disabled={busy}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg border text-sm transition-colors ${
            faved
              ? 'border-amber-300 bg-amber-50 text-amber-700'
              : 'border-gray-300 text-gray-700 hover:border-amber-300'
          } disabled:opacity-50`}
        >
          {faved ? 'في المفضلة' : 'أضف للمفضلة'}
        </button>
      </div>


      <section className="mt-10 border-t pt-8">
        <h2 className="text-lg font-bold mb-4">
          التعليقات{' '}
          <span className="text-sm font-normal text-gray-500">
            ({comments.length})
          </span>
        </h2>

        {!user && (
          <button
            onClick={() => setShowLogin(true)}
            className="mb-6 w-full border border-dashed border-gray-300 rounded-lg py-4 text-sm text-gray-500 hover:border-red-300 hover:text-red-700 transition-colors"
          >
            سجّل الدخول لكتابة تعليق
          </button>
        )}

        {user && (
          <form onSubmit={addComment} className="mb-6">
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              rows={3}
              placeholder="اكتب تعليقك..."
              className="w-full border border-gray-300 rounded-lg px-4 py-3 outline-none focus:border-red-400 resize-none text-sm"
            />
            <button
              type="submit"
              disabled={busy || !text.trim()}
              className="mt-2 px-6 py-2 rounded-lg text-white text-sm font-bold disabled:opacity-50"
              style={{ backgroundColor: BRAND }}
            >
              نشر التعليق
            </button>
          </form>
        )}

        {comments.length === 0 ? (
          <p className="text-gray-500 text-sm py-6">لا توجد تعليقات بعد</p>
        ) : (
          <ul className="space-y-4">
            {comments.map((c) => (
              <li key={c.id} className="border border-gray-200 rounded-lg p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-bold text-gray-800">
                    {c.author ?? 'مستخدم'}
                  </span>
                  <span className="text-xs text-gray-500">
                    {fmt(c.created_at)}
                  </span>
                </div>
                <p className="text-sm text-gray-700 leading-6">{c.content}</p>

                {user && c.user_id === user.id && (
                  <button
                    onClick={() => deleteComment(c.id)}
                    className="mt-2 text-xs text-gray-500 hover:text-red-600"
                  >
                    حذف
                  </button>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      <LoginModal
        open={showLogin}
        onClose={() => setShowLogin(false)}
        onSuccess={refreshUser}
      />
    </div>
  );
}
