import Link from "next/link";
import { getOrganizedExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import type { Speaker } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { Logo } from "@/components/ui";
import { ImageField } from "@/components/client/uploads";
import { deleteSpeaker, saveSpeaker } from "../../../actions";

export default async function OrgSpeakers({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; edit?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  await getOrganizedExhibition(id);
  const db = await expo();
  const { data } = await db.from("speakers").select("*").eq("exhibition_id", id).order("sort_order").order("full_name");
  const list = (data ?? []) as Speaker[];
  const s = list.find((x) => x.id === sp.edit);
  return (
    <div className="grid gap-6 xl:grid-cols-[1fr_380px]">
      <ul className="card divide-y divide-line self-start">
        {list.length === 0 && <li className="p-4 text-sm text-muted">لا يوجد متحدثون.</li>}
        {list.map((x) => (
          <li key={x.id} className="flex items-center gap-3 p-3">
            <Logo path={x.photo_path} name={x.full_name} size={44} className="rounded-full" />
            <div className="min-w-0 flex-1"><p className="font-medium">{x.full_name}</p><p className="truncate text-xs text-muted">{[x.job_title, x.company].filter(Boolean).join(" · ")}</p></div>
            <Link href={`?edit=${x.id}`} className="btn-ghost btn-sm">تعديل</Link>
            <form action={deleteSpeaker.bind(null, id, x.id)}><button className="text-xs text-muted hover:text-primary">حذف</button></form>
          </li>
        ))}
      </ul>
      <form key={s?.id ?? "new"} action={saveSpeaker.bind(null, id, s?.id ?? null)} className="card flex flex-col gap-3 p-5">
        <Flash error={sp.error} />
        <h2 className="font-heading text-lg font-bold">{s ? "تعديل متحدث" : "متحدث جديد"}</h2>
        <ImageField name="photo_path" label="الصورة" prefix={`exhibitions/${id}/speakers`} initial={s?.photo_path} />
        <div><label className="label">الاسم</label><input name="full_name" className="input" required defaultValue={s?.full_name} /></div>
        <div><label className="label">المسمى الوظيفي</label><input name="job_title" className="input" defaultValue={s?.job_title ?? ""} /></div>
        <div><label className="label">الجهة</label><input name="company" className="input" defaultValue={s?.company ?? ""} /></div>
        <div><label className="label">نبذة</label><textarea name="bio" rows={4} className="input" defaultValue={s?.bio ?? ""} /></div>
        <div><label className="label">LinkedIn</label><input name="linkedin" type="url" className="input" dir="ltr" defaultValue={s?.links?.linkedin ?? ""} /></div>
        <div><label className="label">X</label><input name="x" type="url" className="input" dir="ltr" defaultValue={s?.links?.x ?? ""} /></div>
        <div><label className="label">الترتيب</label><input name="sort_order" type="number" className="input" defaultValue={s?.sort_order ?? 0} /></div>
        <div className="flex gap-2"><button className="btn-primary">حفظ</button>{s && <Link href="?" className="btn-ghost">إلغاء</Link>}</div>
      </form>
    </div>
  );
}
