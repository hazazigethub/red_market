import type { Metadata, Viewport } from "next";
import { IBM_Plex_Sans_Arabic, Tajawal } from "next/font/google";
import "./globals.css";
import { Header } from "@/components/Header";
import { env } from "@/lib/env";

const tajawal = Tajawal({ subsets: ["arabic", "latin"], weight: ["500", "700", "800"], variable: "--font-tajawal" });
const plex = IBM_Plex_Sans_Arabic({ subsets: ["arabic", "latin"], weight: ["400", "500", "600"], variable: "--font-plex" });

export const metadata: Metadata = {
  metadataBase: new URL(env.siteUrl),
  title: { default: "Expo Red Market", template: "%s · Expo Red Market" },
  description: "المعارض والمؤتمرات الافتراضية من Red Market",
};

export const viewport: Viewport = { themeColor: "#C21815", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl" className={`${tajawal.variable} ${plex.variable}`}>
      <body className="min-h-screen bg-bg">
        <Header />
        <main>{children}</main>
        <footer className="mt-24 border-t border-line bg-surface">
          <div className="container-x flex flex-col gap-2 py-8 text-sm text-muted sm:flex-row sm:items-center sm:justify-between">
            <p>Expo Red Market — منصة المعارض من <a href={env.redmarketUrl} className="font-semibold text-ink hover:text-primary">Red Market</a></p>
            <p>جميع الأوقات بتوقيت الرياض</p>
          </div>
        </footer>
      </body>
    </html>
  );
}
