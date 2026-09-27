// POST /expo-track { events: [{ exhibition_id, booth_id?, stream_id?, event, props?, anon_id? }] }
// Batched analytics ingestion into the partitioned expo.analytics_events table.
import { adminClient, cors, currentUser, fail, json, UUID_RE } from "../_shared/http.ts";

const ALLOWED = new Set([
  "exhibition_view", "lobby_view", "booth_view", "product_click", "product_buy_click",
  "video_play", "stream_join", "stream_leave", "share", "search", "session_view", "sponsor_click",
]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  if (req.method !== "POST") return fail(req, 405, "METHOD");
  const body = await req.json().catch(() => null);
  const events = Array.isArray(body?.events) ? body.events.slice(0, 50) : [];
  if (!events.length) return json(req, { accepted: 0 });

  const user = await currentUser(req);
  const rows = events
    // deno-lint-ignore no-explicit-any
    .filter((e: any) => ALLOWED.has(e?.event) && UUID_RE.test(e?.exhibition_id ?? ""))
    // deno-lint-ignore no-explicit-any
    .map((e: any) => ({
      exhibition_id: e.exhibition_id,
      booth_id: UUID_RE.test(e.booth_id ?? "") ? e.booth_id : null,
      stream_id: UUID_RE.test(e.stream_id ?? "") ? e.stream_id : null,
      user_id: user?.id ?? null,
      anon_id: typeof e.anon_id === "string" ? e.anon_id.slice(0, 64) : null,
      event: e.event,
      props: typeof e.props === "object" && e.props ? e.props : {},
    }));
  if (rows.length) {
    const { error } = await adminClient().from("analytics_events").insert(rows);
    if (error) return fail(req, 500, "INSERT_FAILED");
  }
  return json(req, { accepted: rows.length });
});
