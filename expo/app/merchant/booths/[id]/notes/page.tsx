import Link from "next/link";
import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { timeAgo } from "@/lib/format";
import { EmptyState } from "@/components/ui";

export default async function Notes({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ q?: string }> }) {
  const { id } = await params;
  const { q } = await searchParams;
  await getStaffBooth(id);
  const db = await expo();
  let query = db.from("lead_notes").select("id, body, is_pinned, created_at, lead_id, exhibition_leads!inner(full_name, booth_id)")
    .eq("exhibition_leads.booth_id", id).order("created_at", { ascending: false }).limit(200);
  if (q) query = query.ilike("body", `%${q.replace(/[%,]/g, "")}%`);
  const { data } = await query;
  const notes = (data ?? []) as unknown as { id: string; body: string; is_pinned: boolean; created_at: string; lead_id: string; exhibition_leads: { full_name: string } }[];
  return (
    <div className="flex flex-col gap-4">
      <form><input name="q" defaultValue={q} className="input sm:w-72" placeholder="ابحث في الملاحظات" /></form>
      {notes.length === 0 ? <EmptyState title="لا توجد ملاحظات" body="أضف ملاحظاتك من صفحة كل عميل محتمل." /> : (
        <ul className="grid gap-3 md:grid-cols-2">
          {notes.map((n) => (
            <li key={n.id} className={`card p-4 ${n.is_pinned ? "border-primary/40" : ""}`}>
              <Link href={`/merchant/booths/${id}/leads/${n.lead_id}`} className="text-sm font-semibold hover:text-primary">{n.exhibition_leads.full_name}</Link>
              <p className="mt-1 whitespace-pre-line text-sm">{n.body}</p>
              <p className="mt-2 text-xs text-muted">{timeAgo(n.created_at)}</p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
