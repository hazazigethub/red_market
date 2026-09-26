// Live video on Cloudflare Stream
// POST /expo-stream/start   { stream_id } -> { whip_url }   (publisher only)
// POST /expo-stream/end     { stream_id } -> { ok }         (publisher only)
// POST /expo-stream/webhook  Cloudflare "Stream Live Input" notification -> live / ended
import { adminClient, cors, fail, json, userClient, UUID_RE } from "../_shared/http.ts";

const CF_ACCOUNT = Deno.env.get("CLOUDFLARE_ACCOUNT_ID") ?? "";
const CF_TOKEN = Deno.env.get("CLOUDFLARE_STREAM_TOKEN") ?? "";
const CF_WEBHOOK_SECRET = Deno.env.get("CLOUDFLARE_WEBHOOK_SECRET") ?? "";
// domains allowed to embed the player (no scheme)
const PLAYER_ORIGINS = (Deno.env.get("EXPO_PLAYER_ORIGINS") ?? "expo.redmarket.pro,expo-redmarket.vercel.app")
  .split(",").map((s) => s.trim()).filter(Boolean);
const API = `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/stream/live_inputs`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  const path = new URL(req.url).pathname.split("/").pop();
  try {
    if (path === "start") return await start(req);
    if (path === "end") return await end(req);
    if (path === "webhook") return await webhook(req);
    return fail(req, 404, "NOT_FOUND");
  } catch (e) {
    console.error(e);
    return fail(req, 500, "INTERNAL");
  }
});

async function cf(url: string, init: RequestInit = {}) {
  const res = await fetch(url, {
    ...init,
    headers: { Authorization: `Bearer ${CF_TOKEN}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body?.success === false) {
    console.error("cloudflare", res.status, JSON.stringify(body?.errors ?? body));
    throw new Error("CLOUDFLARE_ERROR");
  }
  return body.result;
}

async function canPublish(req: Request, streamId: string) {
  const { data } = await userClient(req).rpc("can_publish_stream", { p_stream: streamId });
  return data === true;
}

async function start(req: Request) {
  const { stream_id } = await req.json().catch(() => ({}));
  if (!UUID_RE.test(stream_id ?? "")) return fail(req, 400, "BAD_STREAM_ID");
  if (!(await canPublish(req, stream_id))) return fail(req, 403, "FORBIDDEN");

  const db = adminClient();
  const { data: s } = await db.from("live_streams")
    .select("id, title, status, cf_input_id, exhibitions(status)")
    .eq("id", stream_id).single();
  // deno-lint-ignore no-explicit-any
  const exStatus = (s as any)?.exhibitions?.status;
  if (!s || !["scheduled", "live"].includes(exStatus)) return fail(req, 409, "EXHIBITION_NOT_OPEN");

  // one Cloudflare live input per stream, created on first broadcast
  // deno-lint-ignore no-explicit-any
  let input: any;
  if (s.cf_input_id) {
    input = await cf(`${API}/${s.cf_input_id}`);
  } else {
    input = await cf(API, {
      method: "POST",
      body: JSON.stringify({
        meta: { name: s.title, stream_id: s.id },
        recording: { mode: "off", allowedOrigins: PLAYER_ORIGINS },
      }),
    });
    await db.from("live_streams").update({ cf_input_id: input.uid }).eq("id", s.id);
  }
  const whip = input?.webRTC?.url;
  if (!whip) return fail(req, 500, "NO_WHIP_URL");

  await db.from("live_streams")
    .update({ status: "live", started_at: new Date().toISOString(), ended_at: null })
    .eq("id", s.id);
  return json(req, { whip_url: whip, input_id: input.uid });
}

async function end(req: Request) {
  const { stream_id } = await req.json().catch(() => ({}));
  if (!UUID_RE.test(stream_id ?? "")) return fail(req, 400, "BAD_STREAM_ID");
  if (!(await canPublish(req, stream_id))) return fail(req, 403, "FORBIDDEN");
  await adminClient().from("live_streams")
    .update({ status: "ended", ended_at: new Date().toISOString(), current_viewers: 0 })
    .eq("id", stream_id);
  return json(req, { ok: true });
}

// Cloudflare Notifications -> Webhook (secret sent in the cf-webhook-auth header)
async function webhook(req: Request) {
  if (!CF_WEBHOOK_SECRET || req.headers.get("cf-webhook-auth") !== CF_WEBHOOK_SECRET) {
    return fail(req, 401, "BAD_SECRET");
  }
  const body = await req.json().catch(() => ({}));
  const inputId: string | undefined = body?.data?.input_id;
  const event: string | undefined = body?.data?.event_type;
  if (!inputId || !event) return json(req, { ignored: true });

  const db = adminClient();
  if (event === "live_input.connected") {
    await db.from("live_streams").update({ status: "live", ended_at: null }).eq("cf_input_id", inputId);
  } else if (event === "live_input.disconnected" || event === "live_input.errored") {
    await db.from("live_streams")
      .update({ status: "ended", ended_at: new Date().toISOString(), current_viewers: 0 })
      .eq("cf_input_id", inputId).eq("status", "live");
  }
  return json(req, { ok: true });
}
