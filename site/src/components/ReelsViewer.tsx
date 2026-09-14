'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { supabaseBrowser } from '@/lib/supabase-client';
import LoginModal from '@/components/LoginModal';
import {
  Heart,
  Bookmark,
  Share2,
  ChevronRight,
  ChevronLeft,
} from 'lucide-react';
import type { User } from '@supabase/supabase-js';

const BRAND = '#D32027';
const LIGHT_RED = '#D32027';

type Reel = {
  id: string;
  merchant_id: string | null;
  title: string | null;
  description: string | null;
  video_url: string | null;
  thumbnail_url: string | null;
  likes_count: number | null;
  comments_count: number | null;
  product_id: string | null;
  merchant_name?: string;
  merchant_logo?: string | null;
};

type LinkedProduct = {
  id: string;
  name: string | null;
  price: number | null;
  discount_price: number | null;
  old_price: number | null;
};

type Comment = {
  id: string;
  content: string | null;
  created_at: string | null;
  user_id: string | null;
  author?: string;
};

export default function ReelsViewer({
  merchantId,
}: {
  merchantId?: string;
}) {
  const [user, setUser] = useState<User | null>(null);
  const [reels, setReels] = useState<Reel[]>([]);
  const [ready, setReady] = useState(false);
  const [index, setIndex] = useState(0);

  const [liked, setLiked] = useState<Set<string>>(new Set());
  const [saved, setSaved] = useState<Set<string>>(new Set());
  const [likeCounts, setLikeCounts] = useState<Record<string, number>>({});

  const [showLogin, setShowLogin] = useState(false);
  const [comments, setComments] = useState<Comment[]>([]);
  const [commentText, setCommentText] = useState('');
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [linked, setLinked] = useState<LinkedProduct | null>(null);
  // الفيديوهات التي عُرفت مدتها — يظهر شريط التحكّم بعدها فلا ينزاح التخطيط
  const [metaReady, setMetaReady] = useState<Set<string>>(() => new Set());

  const videoRefs = useRef<(HTMLVideoElement | null)[]>([]);
  const viewedRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    async function load() {
      const { data: u } = await supabaseBrowser.auth.getUser();
      const currentUser = u.user;
      setUser(currentUser);

      let q = supabaseBrowser
        .from('reels')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false })
        .limit(50);

      if (merchantId) {
        // ريلز متجر واحد
        q = q.eq('merchant_id', merchantId);
      } else {
        // كل الريلز — للتجار النشطين فقط
        const { data: actives } = await supabaseBrowser
          .from('profiles')
          .select('id')
          .eq('role', 'merchant')
          .eq('is_subscription_active', true);

        const activeIds = (actives ?? []).map((a) => a.id as string);
        // تُطبَّق دائماً — فإن لم يوجد تاجر نشط لا تظهر ريلز
        q = q.in('merchant_id', activeIds.length > 0 ? activeIds : ['']);
      }

      const { data: rows } = await q;
      const list = (rows as Reel[]) ?? [];

      const mIds = [...new Set(list.map((r) => r.merchant_id).filter(Boolean))];
      if (mIds.length > 0) {
        const { data: merch } = await supabaseBrowser
          .from('merchants')
          .select('id, store_name, logo_url')
          .in('id', mIds as string[]);

        const map = new Map((merch ?? []).map((m) => [m.id, m]));
        list.forEach((r) => {
          const m = r.merchant_id ? map.get(r.merchant_id) : null;
          r.merchant_name = m?.store_name ?? 'متجر';
          r.merchant_logo = m?.logo_url ?? null;
        });
      }

      const counts: Record<string, number> = {};
      list.forEach((r) => (counts[r.id] = r.likes_count ?? 0));
      setLikeCounts(counts);
      setReels(list);

      if (currentUser) {
        const [likeRes, saveRes] = await Promise.all([
          supabaseBrowser
            .from('reel_likes')
            .select('reel_id')
            .eq('user_id', currentUser.id),
          supabaseBrowser
            .from('reel_saves')
            .select('reel_id')
            .eq('user_id', currentUser.id),
        ]);
        setLiked(new Set((likeRes.data ?? []).map((x) => x.reel_id as string)));
        setSaved(new Set((saveRes.data ?? []).map((x) => x.reel_id as string)));
      }

      setReady(true);
    }
    load();
  }, [merchantId]);

  const showToast = useCallback((text: string) => {
    setToast(text);
    setTimeout(() => setToast(null), 2000);
  }, []);

  const logView = useCallback(
    async (reel: Reel) => {
      if (viewedRef.current.has(reel.id)) return;
      viewedRef.current.add(reel.id);
      try {
        await supabaseBrowser.from('reel_views').insert({
          reel_id: reel.id,
          merchant_id: reel.merchant_id,
          viewer_id: user?.id ?? null,
        });
      } catch {
        // تجاهل فشل التتبع
      }
    },
    [user]
  );

  const loadComments = useCallback(async (reelId: string) => {
    const { data: rows } = await supabaseBrowser
      .from('reel_comments')
      .select('id, content, created_at, user_id')
      .eq('reel_id', reelId)
      .order('created_at', { ascending: false })
      .limit(50);

    const list = (rows as Comment[]) ?? [];
    const ids = [...new Set(list.map((c) => c.user_id).filter(Boolean))];
    if (ids.length > 0) {
      const { data: profs } = await supabaseBrowser
        .from('profiles')
        .select('id, full_name, name')
        .in('id', ids as string[]);
      const map = new Map(
        (profs ?? []).map((p) => [p.id, p.full_name || p.name || 'مستخدم'])
      );
      list.forEach((c) => {
        c.author = c.user_id ? map.get(c.user_id) ?? 'مستخدم' : 'مستخدم';
      });
    }
    setComments(list);
  }, []);

  useEffect(() => {
    videoRefs.current.forEach((v, i) => {
      if (!v) return;
      if (i === index) {
        v.play().catch(() => {});
      } else {
        v.pause();
        v.currentTime = 0;
      }
    });
    const current = reels[index];
    if (current) {
      logView(current);
      // التأجيل يمنع تعاقب الرسم
      queueMicrotask(() => void loadComments(current.id));

      if (current.product_id) {
        supabaseBrowser
          .from('products')
          .select('id, name, price, discount_price, old_price')
          .eq('id', current.product_id)
          .maybeSingle()
          .then(({ data }) => setLinked((data as LinkedProduct) ?? null));
      } else {
        queueMicrotask(() => setLinked(null));
      }
    }
  }, [index, reels, logView, loadComments]);

  function goNext() {
    setIndex((i) => Math.min(i + 1, reels.length - 1));
  }
  function goPrev() {
    setIndex((i) => Math.max(i - 1, 0));
  }

  function requireAuth(): boolean {
    if (!user) {
      setShowLogin(true);
      return false;
    }
    return true;
  }

  async function refreshUser() {
    const { data } = await supabaseBrowser.auth.getUser();
    setUser(data.user);
  }

  async function toggleLike(reel: Reel) {
    if (!requireAuth() || busy) return;
    setBusy(true);
    try {
      const on = liked.has(reel.id);
      if (on) {
        await supabaseBrowser
          .from('reel_likes')
          .delete()
          .eq('reel_id', reel.id)
          .eq('user_id', user!.id);
        setLiked((prev) => {
          const n = new Set(prev);
          n.delete(reel.id);
          return n;
        });
        setLikeCounts((c) => ({
          ...c,
          [reel.id]: Math.max(0, (c[reel.id] ?? 0) - 1),
        }));
      } else {
        await supabaseBrowser
          .from('reel_likes')
          .insert({ reel_id: reel.id, user_id: user!.id });
        setLiked((prev) => new Set(prev).add(reel.id));
        setLikeCounts((c) => ({ ...c, [reel.id]: (c[reel.id] ?? 0) + 1 }));
      }
    } finally {
      setBusy(false);
    }
  }

  async function toggleSave(reel: Reel) {
    if (!requireAuth() || busy) return;
    setBusy(true);
    try {
      const on = saved.has(reel.id);
      if (on) {
        await supabaseBrowser
          .from('reel_saves')
          .delete()
          .eq('reel_id', reel.id)
          .eq('user_id', user!.id);
        setSaved((prev) => {
          const n = new Set(prev);
          n.delete(reel.id);
          return n;
        });
        showToast('أُزيل من المحفوظات');
      } else {
        await supabaseBrowser
          .from('reel_saves')
          .insert({ reel_id: reel.id, user_id: user!.id });
        setSaved((prev) => new Set(prev).add(reel.id));
        showToast('حُفظ');
      }
    } finally {
      setBusy(false);
    }
  }

  async function share(reel: Reel) {
    const url = merchantId
      ? `${window.location.origin}/store/${merchantId}/reels`
      : `${window.location.origin}/reels`;
    try {
      if (navigator.share) {
        await navigator.share({ title: reel.title ?? 'ريلز', url });
      } else {
        await navigator.clipboard.writeText(url);
        showToast('نُسخ الرابط');
      }
      await supabaseBrowser.from('reel_shares').insert({
        reel_id: reel.id,
        merchant_id: reel.merchant_id,
        user_id: user?.id ?? null,
      });
    } catch {
      // المستخدم ألغى المشاركة
    }
  }

  async function addComment(e: React.FormEvent, reel: Reel) {
    e.preventDefault();
    if (!requireAuth() || !commentText.trim() || busy) return;
    setBusy(true);
    try {
      const { data } = await supabaseBrowser
        .from('reel_comments')
        .insert({
          reel_id: reel.id,
          user_id: user!.id,
          content: commentText.trim(),
        })
        .select('id, content, created_at, user_id')
        .single();

      if (data) {
        setComments((prev) => [
          { ...(data as Comment), author: 'أنت' },
          ...prev,
        ]);
        setCommentText('');
      }
    } finally {
      setBusy(false);
    }
  }

  async function deleteComment(id: string) {
    if (!user || busy) return;
    setBusy(true);
    try {
      await supabaseBrowser.from('reel_comments').delete().eq('id', id);
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

  // هيكل بأبعاد المحتوى النهائي — فلا يقفز التخطيط عند وصول البيانات
  if (!ready) {
    return (
      <main className="max-w-5xl mx-auto px-4 py-6">
        <div className="grid lg:grid-cols-2 gap-8 items-start">
          <div>
            <div className="relative bg-gray-100 rounded-2xl overflow-hidden aspect-[9/16] w-full min-w-[280px] max-w-[420px] mx-auto flex items-center justify-center">
              <p className="text-gray-500 text-sm">جاري التحميل...</p>
            </div>
          </div>
          <aside>
            <h2 className="font-bold mb-4">التعليقات</h2>
            <div className="h-[420px] lg:h-[700px]" />
          </aside>
        </div>
      </main>
    );
  }

  if (reels.length === 0) {
    return (
      <main className="max-w-5xl mx-auto px-4 py-20 text-center min-h-[60vh]">
        <h1 className="text-2xl font-bold mb-4">
          {merchantId ? 'فيديوهات المتجر' : 'الريلز'}
        </h1>
        <p className="text-gray-500">
          {merchantId ? 'لا توجد مقاطع لهذا المتجر' : 'لا توجد مقاطع حالياً'}
        </p>
      </main>
    );
  }

  const reel = reels[index];

  // ===== قائمة التعليقات (مشتركة بين العمود والنافذة) =====
  const commentsBody = (
    <>
      <form onSubmit={(e) => addComment(e, reel)} className="mb-5">
        <textarea
          value={commentText}
          onChange={(e) => setCommentText(e.target.value)}
          onFocus={() => {
            if (!user) setShowLogin(true);
          }}
          rows={2}
          placeholder={user ? 'اكتب تعليقك...' : 'سجّل الدخول لكتابة تعليق'}
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm outline-none focus:border-red-400 resize-none"
        />
        <button
          type="submit"
          disabled={busy || !commentText.trim()}
          className="mt-2 px-5 py-1.5 rounded-lg text-white text-sm font-bold disabled:opacity-50"
          style={{ backgroundColor: BRAND }}
        >
          نشر
        </button>
      </form>

      {comments.length === 0 ? (
        <p className="text-gray-500 text-sm h-48 flex items-center justify-center">
          لا توجد تعليقات بعد
        </p>
      ) : (
        <ul className="space-y-3">
          {comments.map((c) => (
            <li key={c.id} className="border border-gray-200 rounded-lg p-3">
              <div className="flex items-center justify-between mb-1">
                <span className="text-sm font-bold">{c.author ?? 'مستخدم'}</span>
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-500">
                    {fmt(c.created_at)}
                  </span>
                  {user && c.user_id === user.id && (
                    <button
                      onClick={() => deleteComment(c.id)}
                      className="text-xs text-gray-500 hover:text-red-600"
                    >
                      حذف
                    </button>
                  )}
                </div>
              </div>
              <p className="text-sm text-gray-700">{c.content}</p>
            </li>
          ))}
        </ul>
      )}
    </>
  );

  // ===== أزرار التفاعل العمودية فوق الفيديو =====
  const sideActions = (
    <div className="absolute bottom-24 right-2.5 z-20 flex flex-col gap-2.5">
      <button
        onClick={() => toggleLike(reel)}
        disabled={busy}
        aria-label="إعجاب"
        className="flex flex-col items-center gap-0.5"
      >
        <span
          className={`w-7 h-7 rounded-full flex items-center justify-center backdrop-blur transition-colors ${
            liked.has(reel.id)
              ? 'bg-white'
              : 'bg-black/45 hover:bg-black/60'
          }`}
        >
          <Heart
            size={15}
            strokeWidth={2.5}
            className={liked.has(reel.id) ? 'text-red-600' : 'text-white'}
            fill={liked.has(reel.id) ? 'currentColor' : 'none'}
          />
        </span>
        <span className="text-[9px] text-white drop-shadow font-bold">
          {likeCounts[reel.id] ?? 0}
        </span>
      </button>

      <button
        onClick={() => toggleSave(reel)}
        disabled={busy}
        aria-label="حفظ"
        className={`w-7 h-7 rounded-full flex items-center justify-center backdrop-blur transition-colors ${
          saved.has(reel.id) ? 'bg-white' : 'bg-black/45 hover:bg-black/60'
        }`}
      >
        <Bookmark
          size={15}
          strokeWidth={2.5}
          className={saved.has(reel.id) ? 'text-amber-600' : 'text-white'}
          fill={saved.has(reel.id) ? 'currentColor' : 'none'}
        />
      </button>

      <button
        onClick={() => share(reel)}
        aria-label="مشاركة"
        className="w-7 h-7 rounded-full flex items-center justify-center bg-black/45 hover:bg-black/60 backdrop-blur transition-colors"
      >
        <Share2 size={14} strokeWidth={2.5} className="text-white" />
      </button>
    </div>
  );

  // ===== مشغّل الفيديو =====
  const player = (
    <div className="relative bg-black rounded-2xl overflow-hidden aspect-[9/16] w-full min-w-[280px] max-w-[420px] mx-auto">
      {reels.map((r, i) => {
        // الحالي والمجاوران فقط يُحمَّلون — الباقي ينتظر دوره
        const near = Math.abs(i - index) <= 1;

        return (
          <video
            key={r.id}
            ref={(el) => {
              videoRefs.current[i] = el;
            }}
            src={near ? (r.video_url ?? '') : undefined}
            poster={r.thumbnail_url ?? undefined}
            // none للبعيد — يمنع تنزيل عشرات الميجابايت دفعةً
            preload={i === index ? 'auto' : near ? 'metadata' : 'none'}
            className={`absolute inset-0 w-full h-full object-contain ${
              i === index ? 'block' : 'hidden'
            }`}
            loop
            playsInline
            // يظهر بعد قراءة المدة — يمنع إعادة ترتيب الشريط أثناء القياس
            controls={metaReady.has(r.id)}
            onLoadedMetadata={() =>
              setMetaReady((prev) => {
                if (prev.has(r.id)) return prev;
                const copy = new Set(prev);
                copy.add(r.id);
                return copy;
              })
            }
          />
        );
      })}

      <div className="absolute top-3 right-3 left-3 flex items-center gap-2 z-20">
        {reel.merchant_logo && (
          <span className="relative w-8 h-8 rounded-full overflow-hidden border-2 border-white/70 block shrink-0">
            <Image
              src={reel.merchant_logo}
              alt=""
              fill
              sizes="32px"
              className="object-cover"
            />
          </span>
        )}
        <Link prefetch={false}
          href={reel.merchant_id ? `/store/${reel.merchant_id}` : '#'}
          className="text-white text-sm font-bold drop-shadow"
        >
          {reel.merchant_name}
        </Link>
      </div>

      {sideActions}

      <div className="absolute bottom-24 right-20 left-4 z-20">
        {reel.title && (
          <p className="text-white text-sm font-bold drop-shadow mb-1">
            {reel.title}
          </p>
        )}
        {reel.description && (
          <p className="text-white/80 text-xs drop-shadow line-clamp-2">
            {reel.description}
          </p>
        )}
      </div>

      {linked && (
        <div className="absolute bottom-12 left-0 right-0 z-20 flex justify-center px-6">
          <Link prefetch={false}
            href={`/offer/${linked.id}`}
            className="flex items-center gap-2.5 bg-white/95 rounded-lg px-3 py-2 hover:bg-white transition-colors max-w-[92%]"
          >
            <span className="text-[11px] text-gray-800 font-bold whitespace-nowrap">
              صفحة العرض
            </span>

            {(() => {
              const cur = linked.discount_price ?? linked.price ?? 0;
              const old = linked.old_price;
              const hasOff = old != null && old > cur;
              const pct = hasOff
                ? Math.round(((old - cur) / old) * 100)
                : 0;

              return (
                <>
                  {hasOff && (
                    <>
                      <span className="text-[10px] text-gray-500 line-through whitespace-nowrap">
                        {old.toLocaleString('en-US')}
                      </span>
                      <span
                        className="text-[10px] font-bold text-white px-1.5 py-0.5 rounded"
                        style={{ backgroundColor: LIGHT_RED }}
                      >
                        {pct}%
                      </span>
                    </>
                  )}
                  <span
                    className="text-xs font-bold whitespace-nowrap"
                    style={{ color: BRAND }}
                  >
                    {cur.toLocaleString('en-US')} ر.س
                  </span>
                </>
              );
            })()}
          </Link>
        </div>
      )}

      {(
        <>
          <button
            onClick={goPrev}
            disabled={index === 0}
            aria-label="السابق"
            className="absolute top-1/2 -translate-y-1/2 right-2 z-20 w-8 h-8 rounded-full flex items-center justify-center backdrop-blur transition-opacity hover:opacity-90 disabled:opacity-30"
            style={{ backgroundColor: `${LIGHT_RED}B3` }}
          >
            <ChevronLeft size={18} strokeWidth={3} className="text-white" />
          </button>

          <button
            onClick={goNext}
            disabled={index === reels.length - 1}
            aria-label="التالي"
            className="absolute top-1/2 -translate-y-1/2 left-2 z-20 w-8 h-8 rounded-full flex items-center justify-center backdrop-blur transition-opacity hover:opacity-90 disabled:opacity-30"
            style={{ backgroundColor: `${LIGHT_RED}B3` }}
          >
            <ChevronRight size={18} strokeWidth={3} className="text-white" />
          </button>
        </>
      )}
    </div>
  );

  return (
    <main className="max-w-5xl mx-auto px-4 py-6">
      <div className="grid lg:grid-cols-2 gap-8 items-start">
        {/* اليمين: الفيديو */}
        <div>
          {player}

          {toast && (
            <p className="mt-3 text-center text-sm text-gray-500">{toast}</p>
          )}
        </div>

        {/* اليسار: التعليقات — على الشاشات الكبيرة فقط */}
        <aside>
          <h2 className="font-bold mb-4">
            التعليقات{' '}
            <span className="text-sm font-normal text-gray-500">
              ({comments.length})
            </span>
          </h2>
          {/* ارتفاع محجوز — يمنع قفز التذييل عند وصول التعليقات */}
          {/* ارتفاع ثابت — لا يتمدّد مهما كثرت التعليقات، فلا يُدفع التذييل */}
          <div className="h-[420px] overflow-y-auto lg:h-[700px] lg:pl-1">
            {commentsBody}
          </div>
        </aside>
      </div>

      <LoginModal
        open={showLogin}
        onClose={() => setShowLogin(false)}
        onSuccess={refreshUser}
      />
    </main>
  );
}
