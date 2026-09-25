import { notFound, redirect } from "next/navigation";
import { expo } from "@/lib/supabase/server";

/** Short link used in notifications: /stream/{id} -> /e/{slug}/live/{id} */
export default async function StreamRedirect({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const db = await expo();
  const { data } = await db.from("live_streams").select("id, exhibitions(slug)").eq("id", id).maybeSingle();
  const slug = (data?.exhibitions as unknown as { slug: string } | null)?.slug;
  if (!slug) notFound();
  redirect(`/e/${slug}/live/${id}`);
}
