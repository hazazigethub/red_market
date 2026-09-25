"use client";
import { useEffect, useState } from "react";
import type { User } from "@supabase/supabase-js";
import { supabaseBrowser } from "@/lib/supabase/client";

export function useUser() {
  const [user, setUser] = useState<User | null | undefined>(undefined);
  useEffect(() => {
    const sb = supabaseBrowser();
    sb.auth.getUser().then(({ data }) => setUser(data.user ?? null));
    const { data } = sb.auth.onAuthStateChange((_e, s) => setUser(s?.user ?? null));
    return () => data.subscription.unsubscribe();
  }, []);
  return user;
}

/** Headers for calling Edge Functions as the signed-in user. */
export async function authHeaders(): Promise<Record<string, string>> {
  const sb = supabaseBrowser();
  const { data } = await sb.auth.getSession();
  const { env } = await import("@/lib/env");
  return {
    apikey: env.supabaseAnonKey,
    Authorization: `Bearer ${data.session?.access_token ?? env.supabaseAnonKey}`,
    "Content-Type": "application/json",
  };
}

export async function realtimeAuth() {
  const sb = supabaseBrowser();
  const { data } = await sb.auth.getSession();
  if (data.session?.access_token) await sb.realtime.setAuth(data.session.access_token);
  return sb;
}
