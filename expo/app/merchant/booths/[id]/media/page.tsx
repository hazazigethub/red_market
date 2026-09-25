import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { publicUrl, thumb } from "@/lib/storage";
import type { BoothMedia } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { MediaUploader } from "@/components/client/uploads";
import { deleteMedia, toggleGated } from "../../../actions";

export default async function Media({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  await getStaffBooth(id);
  const db = await expo();
  const { data } = await db.from("booth_media").select("*").eq("booth_id", id).order("type").order("sort_order").order("created_at");
  const list = (data ?? []) as BoothMedia[];
  const label = { image: "صورة", video: "فيديو", catalog: "كتالوج" };
  return (
    <div className="grid gap-6 xl:grid-cols-[1fr_360px]">
      <div className="flex flex-col gap-4">
        <Flash error={sp.error} />
        {list.length === 0 ? <p className="card p-5 text-sm text-muted">لا توجد ملفات بعد.</p> : (
          <ul className="card divide-y divide-line">
            {list.map((m) => (
              <li key={m.id} className="flex items-center gap-3 p-3">
                {m.type === "image"
                  // eslint-disable-next-line @next/next/no-img-element
                  ? <img src={thumb(m.storage_path, 160)!} alt="" className="h-14 w-20 rounded-lg object-cover" />
                  : <span className="grid h-14 w-20 place-items-center rounded-lg bg-bg text-xs font-bold text-muted">{m.type === "video" ? "MP4" : "PDF"}</span>}
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium">{m.title}</p>
                  <p className="text-xs text-muted">{label[m.type]}{m.size_bytes ? ` · ${(m.size_bytes / 1048576).toFixed(1)} MB` : ""}{m.is_gated ? " · محمي" : ""}</p>
                </div>
                {m.type === "catalog" && (
                  <form action={toggleGated.bind(null, id, m.id, !m.is_gated)}><button className="text-xs text-muted hover:text-ink">{m.is_gated ? "إلغاء الحماية" : "حماية"}</button></form>
                )}
                {m.type !== "catalog" && <a href={publicUrl(m.storage_path)!} target="_blank" rel="noopener" className="text-xs text-muted hover:text-ink">عرض</a>}
                <form action={deleteMedia.bind(null, id, m.id)}><button className="text-xs text-muted hover:text-primary">حذف</button></form>
              </li>
            ))}
          </ul>
        )}
      </div>
      <MediaUploader boothId={id} />
    </div>
  );
}
