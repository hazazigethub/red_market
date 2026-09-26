import { NextResponse, type NextRequest } from "next/server";
import { supabaseServer } from "@/lib/supabase/server";

/** Automatic sign-in from the Red Market panel: one-time token -> Expo session -> next page. */
export async function GET(request: NextRequest) {
  const url = request.nextUrl;
  const tokenHash = url.searchParams.get("token_hash");
  const raw = url.searchParams.get("next") ?? "/merchant";
  const next = raw.startsWith("/") && !raw.startsWith("//") ? raw : "/merchant";
  if (tokenHash) {
    const sb = await supabaseServer();
    const { error } = await sb.auth.verifyOtp({ token_hash: tokenHash, type: "magiclink" });
    if (error) return NextResponse.redirect(new URL(`/login?expired=1&next=${encodeURIComponent(next)}`, request.url));
  }
  return NextResponse.redirect(new URL(next, request.url));
}
