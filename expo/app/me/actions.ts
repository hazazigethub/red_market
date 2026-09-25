"use server";
import { revalidatePath } from "next/cache";
import { expo, getUser } from "@/lib/supabase/server";

export async function markAllRead() {
  const user = await getUser();
  if (!user) return;
  const db = await expo();
  await db.from("notifications").update({ read_at: new Date().toISOString() }).eq("user_id", user.id).is("read_at", null);
  revalidatePath("/", "layout");
}

export async function withdrawConsent(exhibitionId: string) {
  const db = await expo();
  await db.rpc("set_contact_consent", { p_exhibition: exhibitionId, p_consent: false });
  revalidatePath("/me");
}
