'use client';

import { createBrowserClient } from '@supabase/ssr';

export const supabaseBrowser = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

/// يبني البريد الصناعي من رقم الجوال — نفس صيغة التطبيق
export function phoneToEmail(phone: string): string {
  const clean = phone.replace(/\D/g, '');
  return `u${clean}@redocean-official.com`;
}