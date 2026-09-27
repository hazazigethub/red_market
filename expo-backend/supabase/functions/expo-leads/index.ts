// GET /expo-leads?booth_id=...&status=...  -> CSV (UTF-8 BOM so Excel renders Arabic)
import { adminClient, cors, currentUser, fail, userClient, UUID_RE } from "../_shared/http.ts";

const COLS: [string, string][] = [
  ["full_name", "الاسم"], ["phone", "الهاتف"], ["email", "البريد"], ["company", "الشركة"],
  ["message", "الرسالة"], ["source", "المصدر"], ["status", "الحالة"], ["score", "التقييم"],
  ["created_at", "وقت الإنشاء"], ["last_activity_at", "آخر نشاط"],
];

const esc = (v: unknown) => {
  let s = v == null ? "" : String(v);
  if (/^[=+\-@]/.test(s)) s = "'" + s; // CSV formula-injection guard
  return `"${s.replaceAll('"', '""')}"`;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  const url = new URL(req.url);
  const boothId = url.searchParams.get("booth_id") ?? "";
  if (!UUID_RE.test(boothId)) return fail(req, 400, "BAD_BOOTH_ID");
  const user = await currentUser(req);
  if (!user) return fail(req, 401, "AUTH_REQUIRED");

  const db = userClient(req);
  const { data: allowed } = await db.rpc("is_booth_staff", { p_booth: boothId, p_roles: ["owner", "manager"] });
  if (allowed !== true) return fail(req, 403, "FORBIDDEN");

  let q = db.from("exhibition_leads").select(COLS.map((c) => c[0]).join(",") + ",id")
    .eq("booth_id", boothId).order("created_at", { ascending: false }).limit(10000);
  const status = url.searchParams.get("status");
  if (status) q = q.eq("status", status);
  const { data, error } = await q;
  if (error) return fail(req, 500, "QUERY_FAILED");

  // deno-lint-ignore no-explicit-any
  const rows = (data ?? []) as any[];
  const csv = "\uFEFF" + [COLS.map((c) => esc(c[1])).join(","),
    ...rows.map((r) => COLS.map(([k]) => esc(r[k])).join(","))].join("\r\n");

  if (rows.length) {
    await adminClient().from("lead_activities").insert(
      rows.slice(0, 1000).map((r) => ({ lead_id: r.id, actor_id: user.id, type: "exported", data: {} })),
    );
  }
  return new Response(csv, {
    headers: {
      ...cors(req),
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="leads-${boothId.slice(0, 8)}.csv"`,
    },
  });
});
