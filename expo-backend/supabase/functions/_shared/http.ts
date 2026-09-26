import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

const ALLOWED_ORIGINS = (Deno.env.get("EXPO_ALLOWED_ORIGINS") ??
  "https://expo.redmarket.pro,http://localhost:3000").split(",");

export function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Vary": "Origin",
  };
}

export function json(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(req), "Content-Type": "application/json; charset=utf-8" },
  });
}

export function fail(req: Request, status: number, code: string): Response {
  return json(req, { error: code }, status);
}

const URL_ = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/** Acts as the caller: RLS applies. */
// deno-lint-ignore no-explicit-any
export function userClient(req: Request): SupabaseClient<any, "expo", any> {
  return createClient(URL_, ANON, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? `Bearer ${ANON}` } },
    auth: { persistSession: false },
    db: { schema: "expo" },
  });
}

/** Bypasses RLS. Use only after an explicit permission check. */
// deno-lint-ignore no-explicit-any
export function adminClient(): SupabaseClient<any, "expo", any> {
  return createClient(URL_, SERVICE, { auth: { persistSession: false }, db: { schema: "expo" } });
}

export async function currentUser(req: Request): Promise<{ id: string; email?: string } | null> {
  const auth = req.headers.get("Authorization");
  if (!auth || auth === `Bearer ${ANON}`) return null;
  const { data } = await userClient(req).auth.getUser(auth.replace("Bearer ", ""));
  return data.user ? { id: data.user.id, email: data.user.email ?? undefined } : null;
}

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
