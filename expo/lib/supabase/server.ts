import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { cache } from "react";
import { env } from "@/lib/env";

export async function supabaseServer() {
  const store = await cookies();
  return createServerClient(env.supabaseUrl, env.supabaseAnonKey, {
    cookieOptions: env.cookieDomain
      ? { domain: env.cookieDomain, sameSite: "lax", secure: true, path: "/" }
      : undefined,
    cookies: {
      getAll: () => store.getAll(),
      setAll: (list) => {
        try {
          list.forEach(({ name, value, options }) => store.set(name, value, options));
        } catch {
          // called from a Server Component: the proxy refreshes the session instead
        }
      },
    },
  });
}

export async function expo() {
  return (await supabaseServer()).schema("expo");
}

/** Current user, verified with the auth server (cached per request). */
export const getUser = cache(async () => {
  const sb = await supabaseServer();
  const { data } = await sb.auth.getUser();
  return data.user ?? null;
});

/** Roles used to show navigation; permissions are enforced by RLS regardless. */
export const getRoles = cache(async () => {
  const user = await getUser();
  if (!user) return { isAdmin: false, isOrganizer: false, isMerchant: false, hasStore: false };
  const db = await expo();
  const [admin, org, staff, stores] = await Promise.all([
    db.from("platform_admins").select("user_id").eq("user_id", user.id).maybeSingle(),
    db.from("organizer_members").select("organizer_id").eq("user_id", user.id).limit(1),
    db.from("booth_staff").select("booth_id").eq("user_id", user.id).limit(1),
    db.rpc("my_stores"),
  ]);
  return {
    isAdmin: !!admin.data,
    isOrganizer: (org.data?.length ?? 0) > 0,
    isMerchant: (staff.data?.length ?? 0) > 0,
    hasStore: ((stores.data as unknown[]) ?? []).length > 0,
  };
});
