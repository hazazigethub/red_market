import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    // صور Supabase Storage — تُحسَّن عبر next/image
    remotePatterns: [
      {
        protocol: "https",
        hostname: "ycuzwfsaxnfbdskerjfw.supabase.co",
        pathname: "/storage/v1/object/public/**",
      },
    ],
    // أحجام الشاشات المستهدفة — تقلّل عدد النسخ المولّدة
    deviceSizes: [360, 400, 480, 640, 828, 1080, 1200, 1920],
    imageSizes: [32, 64, 96, 128, 192, 256, 384],
    formats: ["image/webp"],
    minimumCacheTTL: 60 * 60 * 24 * 30,
  },
};

export default nextConfig;
