import Link from "next/link";
import { notFound } from "next/navigation";
import { getOrganizedExhibition } from "@/lib/queries";
import { expo, getUser } from "@/lib/supabase/server";
import { StreamStudio } from "@/components/client/stream";
import { ModeratedChat } from "@/components/client/ModeratedChat";
import { banUser } from "../../../../actions";

export default async function OrgStudio({ params }: { params: Promise<{ id: string; streamId: string }> }) {
  const { id, streamId } = await params;
  await getOrganizedExhibition(id);
  const user = (await getUser())!;
  const db = await expo();
  const { data: s } = await db.from("live_streams").select("id, title, status, exhibition_chats(id)").eq("id", streamId).eq("exhibition_id", id).maybeSingle();
  if (!s) notFound();
  const chatId = (s.exhibition_chats as unknown as { id: string }[])?.[0]?.id;
  return (
    <div className="flex flex-col gap-4">
      <Link href={`/organizer/e/${id}/sessions`} className="text-sm text-muted">← الجلسات</Link>
      <h2 className="font-heading text-xl font-bold">{s.title}</h2>
      <div className="grid gap-6 xl:grid-cols-[1fr_340px]">
        <StreamStudio streamId={s.id} status={s.status} />
        <div className="card flex h-[60vh] min-h-96 flex-col">
          <h3 className="border-b border-line p-4 font-heading font-bold">الدردشة</h3>
          <div className="min-h-0 flex-1">{chatId && <ModeratedChat chatId={chatId} meId={user.id} ban={banUser.bind(null, id)} />}</div>
        </div>
      </div>
    </div>
  );
}
