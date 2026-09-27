// POST /expo-catalog { media_id, consent?, message_id? } -> { url } (10-minute signed URL)
// Gated catalogs create/refresh a lead for the booth; consent is enforced in the database.
// A catalog the exhibitor sent in a live-stream chat (message_id) can be downloaded by anyone.
import { adminClient, cors, currentUser, fail, json, userClient, UUID_RE } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  const { media_id, consent, message_id } = await req.json().catch(() => ({}));
  if (!UUID_RE.test(media_id ?? "")) return fail(req, 400, "BAD_MEDIA_ID");

  const db = userClient(req);
  const { data: m } = await db.from("booth_media")
    .select("id, booth_id, type, storage_path, is_gated, booths(exhibition_id)")
    .eq("id", media_id).maybeSingle();
  if (!m || m.type !== "catalog") return fail(req, 404, "NOT_FOUND");

  const user = await currentUser(req);
  let sharedInChat = false;
  if (Number.isInteger(message_id)) {
    const { data } = await db.rpc("catalog_shared_in_chat", { p_message: message_id, p_media: media_id });
    sharedInChat = data === true;
  }
  if (m.is_gated && !sharedInChat) {
    if (!user) return fail(req, 401, "AUTH_REQUIRED");
    const { error } = await db.rpc("capture_lead", {
      p_booth: m.booth_id, p_source: "catalog_download", p_consent: consent === true,
    });
    if (error) return fail(req, error.message.includes("CONSENT_REQUIRED") ? 412 : 400, error.message);
  }

  const admin = adminClient();
  const { data: signed, error } = await admin.storage.from("expo-catalogs")
    .createSignedUrl(m.storage_path, 600, { download: true });
  if (error || !signed) return fail(req, 500, "SIGN_FAILED");

  // deno-lint-ignore no-explicit-any
  const exhibitionId = (m as any).booths?.exhibition_id;
  if (exhibitionId) {
    await admin.from("analytics_events").insert({
      exhibition_id: exhibitionId, booth_id: m.booth_id, user_id: user?.id ?? null,
      event: "catalog_download", props: { media_id, from_chat: sharedInChat },
    });
  }
  return json(req, { url: signed.signedUrl });
});
