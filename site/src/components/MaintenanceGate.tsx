'use client';

import { useEffect, useState } from 'react';
import { usePathname } from 'next/navigation';
import Image from 'next/image';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

/// يغطّي الموقع كلّه أثناء الصيانة — ويتجاوزه الأدمن
export default function MaintenanceGate() {
  const pathname = usePathname();
  const [on, setOn] = useState(false);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    let alive = true;

    (async () => {
      try {
        const { data } = await supabaseBrowser
          .from('system_settings')
          .select('is_maintenance, maintenance_message')
          .eq('id', 1)
          .maybeSingle();

        if (!alive || !data?.is_maintenance) return;

        // الأدمن يتجاوز الصيانة
        const {
          data: { user },
        } = await supabaseBrowser.auth.getUser();

        if (user) {
          const { data: p } = await supabaseBrowser
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

          if (p?.role === 'super_admin') return;
        }

        if (!alive) return;
        setMsg(data.maintenance_message ?? '');
        setOn(true);
      } catch {
        // تعذّر الفحص — لا نُغلق الموقع على شكّ
      }
    })();

    return () => {
      alive = false;
    };
  }, [pathname]);

  if (!on) return null;

  return (
    <div
      dir="rtl"
      role="status"
      className="fixed inset-0 z-[100] bg-white flex items-center justify-center px-6"
    >
      <div className="max-w-md text-center">
        <Image
          src="/logo.png"
          alt="رد ماركت"
          width={88}
          height={88}
          className="mx-auto object-contain"
        />

        <h1 className="text-2xl font-bold mt-6" style={{ color: BRAND }}>
          المنصة تحت الصيانة
        </h1>

        <p className="text-sm text-gray-600 leading-8 mt-4 whitespace-pre-line">
          {msg.trim().length > 0
            ? msg
            : 'نقوم بأعمال صيانة لتحسين التجربة، نعود قريباً'}
        </p>

        <button
          onClick={() => window.location.reload()}
          className="mt-8 px-8 py-3 rounded-lg text-white font-bold hover:opacity-90 transition-opacity"
          style={{ backgroundColor: BRAND }}
        >
          إعادة المحاولة
        </button>
      </div>
    </div>
  );
}
