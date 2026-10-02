'use client';

import { useEffect } from 'react';
import { supabaseBrowser } from '@/lib/supabase-client';

const KEY = 'recently_viewed_ids';
const MAX = 20;

/// يسجّل زيارة العرض محلياً وفي قاعدة البيانات
export default function TrackView({
  productId,
  merchantId,
}: {
  productId: string;
  merchantId?: string | null;
}) {
  useEffect(() => {
    async function track() {
      // 1) الحفظ المحلي — يعمل للزائر والمسجّل
      try {
        const raw = localStorage.getItem(KEY);
        const ids: string[] = raw ? JSON.parse(raw) : [];
        const next = [productId, ...ids.filter((x) => x !== productId)].slice(
          0,
          MAX
        );
        localStorage.setItem(KEY, JSON.stringify(next));
      } catch {
        // تجاهل فشل التخزين المحلي
      }

      // 2) عدّاد المشاهدات — يُسجَّل للزائر والمسجّل
      try {
        const { data } = await supabaseBrowser.auth.getUser();
        const u = data.user;

        await supabaseBrowser.from('product_views').insert({
          product_id: productId,
          merchant_id: merchantId ?? null,
          viewer_id: u?.id ?? null,
        });
      } catch {
        // تجاهل فشل التتبع
      }

      // 3) الحفظ الخادمي — للمستخدم المسجّل فقط
      try {
        const { data } = await supabaseBrowser.auth.getUser();
        const u = data.user;
        if (!u) return;

        await supabaseBrowser.from('user_recently_viewed').upsert(
          {
            user_id: u.id,
            product_id: productId,
            visited_at: new Date().toISOString(),
          },
          { onConflict: 'user_id,product_id' }
        );

        await supabaseBrowser.from('user_views').upsert(
          {
            user_id: u.id,
            product_id: productId,
            viewed_at: new Date().toISOString(),
          },
          { onConflict: 'user_id,product_id' }
        );
      } catch {
        // تجاهل فشل التتبع
      }
    }

    track();
  }, [productId, merchantId]);

  return null;
}
