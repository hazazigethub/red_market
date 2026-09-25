"use server";
import { revalidatePath } from "next/cache";
import { expo } from "@/lib/supabase/server";
import { failTo } from "@/lib/actions";

export async function setOrganizer(id: string, patch: { is_verified?: boolean; is_suspended?: boolean }) {
  const db = await expo();
  const { error } = await db.from("organizers").update(patch).eq("id", id);
  failTo("/admin", error);
  revalidatePath("/admin");
}

export async function setFeatured(id: string, featured: boolean) {
  const db = await expo();
  const { error } = await db.from("exhibitions").update({ is_featured: featured }).eq("id", id);
  failTo("/admin", error);
  revalidatePath("/admin");
}

export async function forceStatus(id: string, form: FormData) {
  const db = await expo();
  const { error } = await db.from("exhibitions").update({ status: String(form.get("status")) }).eq("id", id);
  failTo("/admin", error);
  revalidatePath("/admin");
}

export async function setStoreStatus(id: string, form: FormData) {
  const db = await expo();
  const status = String(form.get("status"));
  const { error } = await db.from("store").update({
    status, suspended_reason: status === "suspended" ? String(form.get("reason") ?? "") || null : null,
  }).eq("id", id);
  failTo("/admin", error);
  revalidatePath("/admin");
}
