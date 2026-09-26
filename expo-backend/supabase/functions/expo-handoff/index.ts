// Automatic sign-in from the Red Market panel to the Expo site.
// POST /expo-handoff { next }  (called with the user's panel session)
//  -> { url }  one-time link that opens a NEW, separate Expo session (panel session untouched)
import { adminClient, cors, currentUser, fail, json } from "../_shared/http.ts";

const SITE = Deno.env.get("EXPO_SITE_URL") ?? "https://expo.redmarket.pro";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  if (req.method !== "POST") return fail(req, 405, "METHOD");
  try {
    const user = await currentUser(req);
    if (!user?.email) return fail(req, 401, "AUTH_REQUIRED");

    const { next } = await req.json().catch(() => ({}));
    const path = typeof next === "string" && next.startsWith("/") && !next.startsWith("//") ? next : "/merchant";

    // one-time token (not emailed); verified by the Expo site to create its own session
    const { data, error } = await adminClient().auth.admin.generateLink({ type: "magiclink", email: user.email });
    const hashed = data?.properties?.hashed_token;
    if (error || !hashed) return fail(req, 500, "LINK_FAILED");

    const url = `${SITE}/auth/handoff?token_hash=${encodeURIComponent(hashed)}&next=${encodeURIComponent(path)}`;
    return json(req, { url });
  } catch (e) {
    console.error(e);
    return fail(req, 500, "INTERNAL");
  }
});
