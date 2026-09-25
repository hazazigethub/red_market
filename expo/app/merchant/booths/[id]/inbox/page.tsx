import Link from "next/link";
import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { timeAgo } from "@/lib/format";
import { Flash } from "@/components/Flash";
import { EmptyState } from "@/components/ui";
import { ChatPanel } from "@/components/client/ChatPanel";
import { InboxLive } from "@/components/client/InboxLive";
import { markChatRead, setChatStatus } from "../../../actions";

export default async function Inbox({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<{ chat?: string; error?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const b = await getStaffBooth(id);
  const db = await expo();
  const { data } = await db.from("exhibition_chats")
    .select("id, status, last_message_at, staff_last_read_at, lead_id, exhibition_leads!chats_lead_fk(id, full_name, status)")
    .eq("booth_id", id).eq("type", "booth_dm").order("last_message_at", { ascending: false, nullsFirst: false }).limit(200);
  type C = { id: string; status: string; last_message_at: string | null; staff_last_read_at: string | null; lead_id: string | null;
    exhibition_leads: { id: string; full_name: string; status: string } | null };
  const chats = (data ?? []) as unknown as C[];
  const active = chats.find((c) => c.id === sp.chat);
  if (active) await markChatRead(active.id);
  const unread = (c: C) => c.last_message_at && (!c.staff_last_read_at || c.last_message_at > c.staff_last_read_at);

  return (
    <div className="flex flex-col gap-4">
      <InboxLive boothId={id} />
      <Flash error={sp.error} />
      {chats.length === 0 ? <EmptyState title="لا توجد محادثات بعد" body="ستظهر هنا فور أن يراسلك زائر من صفحة جناحك." /> : (
        <div className="grid gap-4 lg:grid-cols-[300px_1fr]">
          <ul className="card max-h-[70vh] divide-y divide-line overflow-y-auto">
            {chats.map((c) => (
              <li key={c.id}>
                <Link href={`?chat=${c.id}`} className={`flex items-center gap-3 p-3 ${c.id === active?.id ? "bg-bg" : "hover:bg-bg/60"}`}>
                  <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-ink text-sm font-bold text-bg">
                    {(c.exhibition_leads?.full_name ?? "ز")[0]}</span>
                  <div className="min-w-0 flex-1">
                    <p className={`truncate ${unread(c) ? "font-bold" : "font-medium"}`}>{c.exhibition_leads?.full_name ?? "زائر (بدون مشاركة بيانات)"}</p>
                    <p className="text-xs text-muted">{c.last_message_at ? timeAgo(c.last_message_at) : "لا رسائل"}{c.status !== "open" ? " · مغلقة" : ""}</p>
                  </div>
                  {unread(c) && <span className="h-2.5 w-2.5 rounded-full bg-primary" aria-label="غير مقروءة" />}
                </Link>
              </li>
            ))}
          </ul>
          <div className="card flex h-[70vh] min-h-96 flex-col">
            {active ? (
              <>
                <div className="flex flex-wrap items-center gap-2 border-b border-line p-3">
                  <p className="me-auto font-semibold">{active.exhibition_leads?.full_name ?? "زائر"}</p>
                  {active.lead_id && <Link href={`/merchant/booths/${id}/leads/${active.lead_id}`} className="btn-ghost btn-sm">ملف العميل</Link>}
                  <form action={setChatStatus.bind(null, id, active.id, active.status === "open" ? "closed" : "open")}>
                    <button className="btn-ghost btn-sm">{active.status === "open" ? "إغلاق المحادثة" : "إعادة فتح"}</button>
                  </form>
                </div>
                <div className="min-h-0 flex-1"><ChatPanel chatId={active.id} meId={b.userId} readOnly={active.status === "read_only"} canModerate /></div>
              </>
            ) : <p className="grid h-full place-items-center text-sm text-muted">اختر محادثة من القائمة</p>}
          </div>
        </div>
      )}
    </div>
  );
}
