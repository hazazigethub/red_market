'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Mail } from 'lucide-react';
import { FaTiktok, FaInstagram, FaSnapchatGhost } from 'react-icons/fa';
import { FaXTwitter, FaWhatsapp } from 'react-icons/fa6';
import { supabaseBrowser } from '@/lib/supabase-client';

type Settings = {
  whatsapp_number: string | null;
  contact_email: string | null;
  url_x: string | null;
  url_instagram: string | null;
  url_tiktok: string | null;
  url_snapchat: string | null;
};

const CIRCLE =
  'w-9 h-9 rounded-full border border-gray-300 flex items-center justify-center text-gray-500 hover:border-red-300 hover:text-red-700 transition-colors';

/// بيانات التواصل تُدار من لوحة الأدمن — والفارغ منها لا يُعرض
export default function FooterContact() {
  const [s, setS] = useState<Settings | null>(null);

  useEffect(() => {
    let alive = true;

    (async () => {
      try {
        const { data } = await supabaseBrowser
          .from('system_settings')
          .select(
            'whatsapp_number, contact_email, url_x, url_instagram, url_tiktok, url_snapchat'
          )
          .eq('id', 1)
          .maybeSingle();

        if (alive && data) setS(data as Settings);
      } catch {
        // الإعدادات تكميلية — لا نُفشل التذييل
      }
    })();

    return () => {
      alive = false;
    };
  }, []);

  const socials = [
    { url: s?.url_x, label: 'إكس', icon: <FaXTwitter size={15} /> },
    { url: s?.url_instagram, label: 'انستغرام', icon: <FaInstagram size={17} /> },
    { url: s?.url_tiktok, label: 'تيك توك', icon: <FaTiktok size={15} /> },
    {
      url: s?.url_snapchat,
      label: 'سناب شات',
      icon: <FaSnapchatGhost size={16} />,
    },
  ].filter((x) => x.url && x.url.trim().length > 0);

  // رقم الواتساب يُنظَّف من غير الأرقام
  const wa = s?.whatsapp_number?.replace(/\D/g, '') ?? '';

  return (
    <>
      {wa.length > 0 && (
        <a
          href={`https://wa.me/${wa}`}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-3 group mb-4"
        >
          <span className="w-9 h-9 rounded-full border border-gray-300 flex items-center justify-center text-gray-500 shrink-0 group-hover:border-red-300 group-hover:text-red-700 transition-colors">
            <FaWhatsapp size={18} />
          </span>
          <span
            dir="ltr"
            className="text-sm text-gray-700 group-hover:text-red-700 transition-colors"
          >
            {s?.whatsapp_number}
          </span>
        </a>
      )}

      {s?.contact_email ? (
        <a
          href={`mailto:${s.contact_email}`}
          className="flex items-center gap-3 group"
        >
          <span className="w-9 h-9 rounded-full border border-gray-300 flex items-center justify-center text-gray-500 shrink-0 group-hover:border-red-300 group-hover:text-red-700 transition-colors">
            <Mail size={16} />
          </span>
          <span
            dir="ltr"
            className="text-sm text-gray-700 group-hover:text-red-700 transition-colors"
          >
            {s.contact_email}
          </span>
        </a>
      ) : (
        <Link
          prefetch={false}
          href="/support"
          className="flex items-center gap-3 group"
        >
          <span className="w-9 h-9 rounded-full border border-gray-300 flex items-center justify-center text-gray-500 shrink-0 group-hover:border-red-300 group-hover:text-red-700 transition-colors">
            <Mail size={16} />
          </span>
          <span className="text-sm text-gray-700 group-hover:text-red-700 transition-colors">
            راسلنا عبر صفحة الدعم
          </span>
        </Link>
      )}

      {socials.length > 0 && (
        <>
          <p className="text-sm font-bold mt-8 mb-1">تجدونا هنا بانتظاركم</p>
          <div className="flex gap-2.5 mt-4">
            {socials.map((x) => (
              <a
                key={x.label}
                href={x.url!}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={x.label}
                title={x.label}
                className={CIRCLE}
              >
                {x.icon}
              </a>
            ))}
          </div>
        </>
      )}
    </>
  );
}
