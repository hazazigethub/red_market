"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { expo } from "@/lib/supabase/server";
import { bool, failTo, num, str } from "@/lib/actions";
import { riyadhLocalToIso } from "@/lib/format";

const B = (id: string, p = "") => `/merchant/booths/${id}${p}`;

export async function applyToExhibition(form: FormData) {
  const db = await expo();
  // registers the merchant in expo.store on first use, then submits the application
  const { error } = await db.rpc("apply_to_exhibition", {
    p_exhibition: str(form, "exhibition_id"), p_merchant: str(form, "merchant_id"),
    p_tier: str(form, "tier") ?? "standard", p_message: str(form, "message"),
  });
  failTo("/merchant", error);
  revalidatePath("/merchant");
  redirect("/merchant?ok=applied");
}

export async function withdrawApplication(id: string) {
  const db = await expo();
  const { error } = await db.from("booth_applications").update({ status: "withdrawn" }).eq("id", id);
  failTo("/merchant", error);
  revalidatePath("/merchant");
}

export async function updateBooth(boothId: string, form: FormData) {
  const db = await expo();
  const contact = {
    phone: str(form, "phone") ?? undefined, whatsapp: str(form, "whatsapp") ?? undefined,
    email: str(form, "email") ?? undefined, website: str(form, "website") ?? undefined,
  };
  const { error } = await db.from("booths").update({
    name: str(form, "name"), tagline: str(form, "tagline"), about: str(form, "about"),
    logo_path: str(form, "logo_path"), cover_path: str(form, "cover_path"), contact,
    status: str(form, "status") ?? "draft",
  }).eq("id", boothId);
  failTo(B(boothId, "/edit"), error);
  revalidatePath(B(boothId), "layout");
  redirect(B(boothId, "/edit?ok=saved"));
}

export async function toggleBoothProduct(boothId: string, productId: string, add: boolean) {
  const db = await expo();
  const { error } = add
    ? await db.from("booth_products").insert({ booth_id: boothId, product_id: productId })
    : await db.from("booth_products").delete().eq("booth_id", boothId).eq("product_id", productId);
  failTo(B(boothId, "/products"), error);
  revalidatePath(B(boothId, "/products"));
}

export async function updateBoothProduct(boothId: string, productId: string, form: FormData) {
  const db = await expo();
  const { error } = await db.from("booth_products").update({
    is_highlighted: bool(form, "is_highlighted"), expo_price: num(form, "expo_price"),
    expo_badge: str(form, "expo_badge"), sort_order: num(form, "sort_order") ?? 0,
  }).eq("booth_id", boothId).eq("product_id", productId);
  failTo(B(boothId, "/products"), error);
  revalidatePath(B(boothId, "/products"));
}

export async function deleteMedia(boothId: string, mediaId: string) {
  const db = await expo();
  const { data } = await db.from("booth_media").select("storage_path, type").eq("id", mediaId).single();
  const { error } = await db.from("booth_media").delete().eq("id", mediaId);
  failTo(B(boothId, "/media"), error);
  if (data) {
    const sb = (await import("@/lib/supabase/server")).supabaseServer;
    await (await sb()).storage.from(data.type === "catalog" ? "expo-catalogs" : "expo-public").remove([data.storage_path]);
  }
  revalidatePath(B(boothId, "/media"));
}

export async function toggleGated(boothId: string, mediaId: string, gated: boolean) {
  const db = await expo();
  const { error } = await db.from("booth_media").update({ is_gated: gated }).eq("id", mediaId);
  failTo(B(boothId, "/media"), error);
  revalidatePath(B(boothId, "/media"));
}

export async function createStream(boothId: string, form: FormData) {
  const db = await expo();
  const when = str(form, "scheduled_at");
  const { error } = await db.from("live_streams").insert({
    booth_id: boothId, title: str(form, "title"), scheduled_at: when ? riyadhLocalToIso(when) : null,
  });
  failTo(B(boothId, "/studio"), error);
  revalidatePath(B(boothId, "/studio"));
}

export async function deleteStream(boothId: string, streamId: string) {
  const db = await expo();
  const { error } = await db.from("live_streams").delete().eq("id", streamId);
  failTo(B(boothId, "/studio"), error);
  revalidatePath(B(boothId, "/studio"));
}

export async function pinProduct(boothId: string, streamId: string, form: FormData) {
  const db = await expo();
  const { error } = await db.from("live_streams").update({ pinned_product_id: str(form, "product_id") }).eq("id", streamId);
  failTo(B(boothId, `/studio?stream=${streamId}`), error);
  revalidatePath(B(boothId, "/studio"));
}

export async function updateLead(boothId: string, leadId: string, form: FormData) {
  const db = await expo();
  const patch: Record<string, unknown> = {};
  if (form.has("status")) patch.status = str(form, "status");
  if (form.has("assigned_to")) patch.assigned_to = str(form, "assigned_to");
  const { error } = await db.from("exhibition_leads").update(patch).eq("id", leadId);
  failTo(B(boothId, `/leads/${leadId}`), error);
  revalidatePath(B(boothId, "/leads"), "layout");
}

export async function addNote(boothId: string, leadId: string, form: FormData) {
  const db = await expo();
  const { error } = await db.from("lead_notes").insert({ lead_id: leadId, body: str(form, "body") });
  failTo(B(boothId, `/leads/${leadId}`), error);
  revalidatePath(B(boothId, `/leads/${leadId}`));
}

export async function deleteNote(boothId: string, leadId: string, noteId: string) {
  const db = await expo();
  const { error } = await db.from("lead_notes").delete().eq("id", noteId);
  failTo(B(boothId, `/leads/${leadId}`), error);
  revalidatePath(B(boothId, `/leads/${leadId}`));
}

export async function togglePinNote(boothId: string, leadId: string, noteId: string, pinned: boolean) {
  const db = await expo();
  await db.from("lead_notes").update({ is_pinned: pinned }).eq("id", noteId);
  revalidatePath(B(boothId, `/leads/${leadId}`));
}

export async function addStaff(boothId: string, form: FormData) {
  const db = await expo();
  const { error } = await db.rpc("add_booth_staff", {
    p_booth: boothId, p_email: str(form, "email"), p_role: str(form, "role") ?? "agent",
  });
  failTo(B(boothId, "/team"), error);
  revalidatePath(B(boothId, "/team"));
  redirect(B(boothId, "/team?ok=added"));
}

export async function removeStaff(boothId: string, userId: string) {
  const db = await expo();
  const { error } = await db.from("booth_staff").delete().eq("booth_id", boothId).eq("user_id", userId);
  failTo(B(boothId, "/team"), error);
  revalidatePath(B(boothId, "/team"));
}

export async function setChatStatus(boothId: string, chatId: string, status: "open" | "closed") {
  const db = await expo();
  const { error } = await db.from("exhibition_chats").update({ status }).eq("id", chatId);
  failTo(B(boothId, `/inbox?chat=${chatId}`), error);
  revalidatePath(B(boothId, "/inbox"));
}

export async function markChatRead(chatId: string) {
  const db = await expo();
  await db.from("exhibition_chats").update({ staff_last_read_at: new Date().toISOString() }).eq("id", chatId);
}
