import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { env, loginUrl } from "@/lib/env";

const PROTECTED = ["/me", "/merchant", "/organizer", "/admin"];

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });
  const sb = createServerClient(env.supabaseUrl, env.supabaseAnonKey, {
    cookieOptions: env.cookieDomain
      ? { domain: env.cookieDomain, sameSite: "lax", secure: true, path: "/" }
      : undefined,
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (list) => {
        list.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        list.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  const { data } = await sb.auth.getUser();
  const path = request.nextUrl.pathname;
  if (!data.user && PROTECTED.some((p) => path === p || path.startsWith(p + "/"))) {
    const target = loginUrl(path + request.nextUrl.search);
    return NextResponse.redirect(target.startsWith("http") ? target : new URL(target, request.url));
  }
  return response;
}
