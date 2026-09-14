import type { Metadata } from 'next';
import { Cairo } from 'next/font/google';
import Link from 'next/link';
import Image from 'next/image';
import SearchBox from '@/components/SearchBox';
import AccountMenu from '@/components/AccountMenu';
import NotificationsBell from '@/components/NotificationsBell';
import AccountRecoveryGate from '@/components/AccountRecoveryGate';
import { TvMinimalPlay, Bookmark, Mail } from 'lucide-react';
import {
  FaTiktok,
  FaInstagram,
  FaApple,
} from 'react-icons/fa';
import { FaXTwitter, FaGooglePlay } from 'react-icons/fa6';
import './globals.css';

const cairo = Cairo({
  subsets: ['arabic'],
  display: 'swap',
  preload: true,
  // أوزان محددة — تقلّل حجم الخط المحمَّل
  weight: ['400', '700'],
  // يضبط أبعاد الخط البديل لتطابق Cairo — فلا يقفز النصّ عند التبديل
  adjustFontFallback: true,
  fallback: ['system-ui', 'arial'],
});

export const metadata: Metadata = {
  title: 'رد ماركت — عروض المتاجر في مكان واحد',
  description:
    'تصفّح أحدث المنتجات والعروض من متاجر متعددة، وانتقل مباشرة لصفحة المنتج في المتجر.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ar" dir="rtl">
      <body className={`${cairo.className} bg-white text-gray-900`}>
        <header className="sticky top-0 bg-white z-50">
          <div className="max-w-6xl mx-auto px-4 h-12 flex items-center gap-4">
            <Link href="/" className="flex items-center gap-2 shrink-0">
              {/* حاوية ثابتة تحجز المساحة قبل وصول الصورة */}
              <div className="relative w-[108px] h-[36px]">
                <Image
                  src="/logo.png"
                  alt="رد ماركت"
                  fill
                  sizes="108px"
                  className="object-contain"
                  priority
                />
              </div>
            </Link>

            {/* على الحاسب: داخل الصف الأول */}
            <div className="hidden md:block flex-1 min-w-0">
              <SearchBox />
            </div>

            <nav className="flex items-center gap-0.5 shrink-0">
              <Link
                href="/reels"
                aria-label="الريلز"
                title="الريلز"
                className="h-11 px-2 rounded-full flex items-center gap-1.5 hover:bg-gray-100 transition-colors"
                style={{ color: '#D32027' }}
              >
                <TvMinimalPlay size={30} strokeWidth={1.6} />
                <span className="text-sm font-bold">Reels</span>
              </Link>

              {/* على الحاسب فقط — وعلى الجوال تنزل للصف الثاني */}
              <div className="hidden md:flex items-center gap-0.5">
                <Link
                  href="/favorites"
                  aria-label="المفضلة"
                  title="المفضلة"
                  className="w-11 h-11 rounded-full flex items-center justify-center hover:bg-gray-100 transition-colors"
                  style={{ color: '#D32027' }}
                >
                  <Bookmark size={30} strokeWidth={1.6} />
                </Link>

                <NotificationsBell />
              </div>

              <AccountMenu />
            </nav>
          </div>

          {/* على الجوال: صف ثانٍ — البحث مع المفضلة والإشعارات */}
          <div className="md:hidden max-w-6xl mx-auto px-4 pb-2 flex items-center gap-1">
            <div className="flex-1 min-w-0">
              <SearchBox />
            </div>

            <Link
              href="/favorites"
              aria-label="المفضلة"
              title="المفضلة"
              className="w-11 h-11 shrink-0 rounded-full flex items-center justify-center hover:bg-gray-100 transition-colors"
              style={{ color: '#D32027' }}
            >
              <Bookmark size={26} strokeWidth={1.6} />
            </Link>

            <NotificationsBell />
          </div>
        </header>

        <AccountRecoveryGate />

        {children}

        <footer className="border-t mt-16 bg-gray-50">
          <div className="max-w-6xl mx-auto px-4 py-12">
            <div className="grid md:grid-cols-3 gap-10">
              {/* ===== العمود الأول: المؤسسة ===== */}
              <div>
                {/* حاوية ثابتة تحجز المساحة قبل وصول الصورة */}
                <div className="relative w-[120px] h-[40px]">
                  <Image
                    src="/logo.png"
                    alt="رد ماركت"
                    fill
                    sizes="120px"
                    className="object-contain"
                  />
                </div>

                <p className="text-sm text-gray-500 leading-7 mt-4">
                  رد ماركت منصة تجمع عروض المتاجر في مكان واحد، لتتصفح المنتجات
                  وتقارن بينها، ثم تنتقل مباشرة إلى المتجر لإتمام الشراء.
                </p>

                <p className="text-sm font-bold mt-7 mb-3">حمّل التطبيق</p>
                <div className="flex flex-wrap gap-2.5">
                  <span className="flex items-center gap-2.5 border border-gray-300 rounded-lg px-3.5 py-2 bg-white opacity-70 cursor-default">
                    <FaGooglePlay size={19} className="text-gray-600" />
                    <span className="leading-tight">
                      <span className="block text-[9px] text-gray-500">
                        احصل عليه من
                      </span>
                      <span className="block text-xs font-bold text-gray-800">
                        Google Play
                      </span>
                    </span>
                  </span>

                  <span className="flex items-center gap-2.5 border border-gray-300 rounded-lg px-3.5 py-2 bg-white opacity-70 cursor-default">
                    <FaApple size={21} className="text-gray-700" />
                    <span className="leading-tight">
                      <span className="block text-[9px] text-gray-500">
                        تحميل من
                      </span>
                      <span className="block text-xs font-bold text-gray-800">
                        App Store
                      </span>
                    </span>
                  </span>
                </div>
                <p className="text-[11px] text-red-600 mt-2">
                  ( تُربط بعد نشر التطبيق )
                </p>

              </div>

              {/* ===== العمود الثاني: روابط مهمة ===== */}
              <div>
                <h2 className="font-bold text-lg mb-5">روابط مهمة</h2>
                <div className="flex flex-col gap-3 text-sm text-gray-600">
                  <Link href="/about" className="hover:text-red-700">
                    من نحن
                  </Link>
                  <Link href="/support" className="hover:text-red-700">
                    الدعم الفني
                  </Link>
                  <Link href="/faq" className="hover:text-red-700">
                    الأسئلة الشائعة
                  </Link>
                  <Link href="/terms" className="hover:text-red-700">
                    الشروط والأحكام
                  </Link>
                  <Link href="/privacy" className="hover:text-red-700">
                    سياسة الخصوصية
                  </Link>
                  <Link href="/merchants" className="hover:text-red-700">
                    خدمات التاجر
                  </Link>
                </div>
              </div>

              {/* ===== العمود الثالث: تواصل معنا ===== */}
              <div>
                <h2 className="font-bold text-lg mb-5">تواصل معنا</h2>

                {/* رقم الواتساب والبريد يُضافان لاحقاً من لوحة الأدمن */}
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

                <p className="text-sm font-bold mt-8 mb-1">
                  تجدونا هنا بانتظاركم
                </p>
                <div className="flex gap-2.5 mt-4">
                  <a
                    href="https://x.com/redmarketsa"
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label="إكس"
                    title="إكس"
                    className="w-9 h-9 rounded-full border border-gray-300 flex items-center justify-center text-gray-500 hover:border-red-300 hover:text-red-700 transition-colors"
                  >
                    <FaXTwitter size={15} />
                  </a>

                  <a
                    href="https://www.instagram.com/redmarket.sa/"
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label="انستغرام"
                    title="انستغرام"
                    className="w-9 h-9 rounded-full border border-gray-300 flex items-center justify-center text-gray-500 hover:border-red-300 hover:text-red-700 transition-colors"
                  >
                    <FaInstagram size={17} />
                  </a>

                  <a
                    href="https://www.tiktok.com/@redmarket.sa"
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label="تيك توك"
                    title="تيك توك"
                    className="w-9 h-9 rounded-full border border-gray-300 flex items-center justify-center text-gray-500 hover:border-red-300 hover:text-red-700 transition-colors"
                  >
                    <FaTiktok size={15} />
                  </a>
                </div>

              </div>
            </div>

            <div className="border-t border-gray-200 mt-10 pt-6">
              <div className="flex flex-wrap items-center justify-center gap-x-10 gap-y-2 text-xs text-gray-600">
                <span>© رد ماركت — جميع الحقوق محفوظة</span>
                {/* البيانات النظامية تُضاف عند اكتمال التسجيل */}
                <span>منصة في مرحلة تشغيل تجريبي</span>
              </div>
            </div>
          </div>
        </footer>

      </body>
    </html>
  );
}
