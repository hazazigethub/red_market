import "server-only";
import { cache } from "react";
import { notFound } from "next/navigation";
import { expo, getUser } from "@/lib/supabase/server";
import type { Booth, Exhibition, MemberRole } from "@/lib/types";

export const getExhibition = cache(async (slug: string): Promise<Exhibition> => {
  const db = await expo();
  const { data } = await db.from("exhibitions").select("*").eq("slug", slug).maybeSingle();
  if (!data) notFound();
  return data as Exhibition;
});

export const getBoothBySlug = cache(async (exhibitionId: string, slug: string): Promise<Booth> => {
  const db = await expo();
  const { data } = await db.from("booths").select("*").eq("exhibition_id", exhibitionId).eq("slug", slug).maybeSingle();
  if (!data) notFound();
  return data as Booth;
});

/** Booth the current user staffs, with their role. 404 for anyone else. */
export const getStaffBooth = cache(async (boothId: string) => {
  const user = await getUser();
  if (!user) notFound();
  const db = await expo();
  const [{ data: booth }, { data: me }] = await Promise.all([
    db.from("booths").select("*, exhibitions(id, slug, title, status, chat_enabled, timezone)").eq("id", boothId).maybeSingle(),
    db.from("booth_staff").select("role").eq("booth_id", boothId).eq("user_id", user.id).maybeSingle(),
  ]);
  if (!booth || !me) notFound();
  return {
    ...(booth as Booth),
    exhibitions: (booth as { exhibitions: Pick<Exhibition, "id" | "slug" | "title" | "status" | "chat_enabled" | "timezone"> }).exhibitions,
    role: me.role as MemberRole,
    userId: user.id,
  };
});

/** Exhibition the current user organizes. 404 for anyone else (admins allowed). */
export const getOrganizedExhibition = cache(async (id: string) => {
  const db = await expo();
  const [{ data }, { data: ok }, { data: admin }] = await Promise.all([
    db.from("exhibitions").select("*").eq("id", id).maybeSingle(),
    db.rpc("is_organizer", { p_exhibition: id }),
    db.rpc("is_admin"),
  ]);
  if (!data || !(ok || admin)) notFound();
  return data as Exhibition;
});
