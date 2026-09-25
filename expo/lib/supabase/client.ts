"use client";
import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { env } from "@/lib/env";

let client: SupabaseClient | null = null;

/** Browser client. Session lives in a cookie on .redmarket.pro, shared with Red Market (SSO). */
export function supabaseBrowser(): SupabaseClient {
  if (!client) {
    client = createBrowserClient(env.supabaseUrl, env.supabaseAnonKey, {
      cookieOptions: env.cookieDomain
        ? { domain: env.cookieDomain, sameSite: "lax", secure: true, path: "/" }
        : undefined,
    });
  }
  return client;
}

export const expoBrowser = () => supabaseBrowser().schema("expo");
