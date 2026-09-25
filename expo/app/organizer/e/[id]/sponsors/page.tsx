import Link from "next/link";
import { getOrganizedExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { SPONSOR_TIER } from "@/lib/format";
import type { Sponsor } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { Logo } from "@/components/ui";
import { ImageField } from "@/components/client/uploads";
import { deleteSponsor, saveSponsor } from "../../../actions";

export default async function OrgSponsors({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; edit?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  await getOrganizedExhibition(id);
  const db = await expo();
  const [{ data }, { data: booths }] = await Promise.all([
    db.from("sponsors").select("*").eq("exhibition_id", id).order("tier").order("sort_order"),
    db.from("booths").select("id, name").eq("exhibition_id", id).order("name"),
  ]);
  const list = (data ?? []) as Sponsor[];
  const s = list.find((x) => x.id === sp.edit);
  return (
    <div className="grid gap-6 xl:grid-cols-[1fr_380px]">
      <ul className="card divide-y divide-line self-start">
        {list.length === 0 && <li className="p-4 text-sm text-muted">لا يوجد رعاة.</li>}
        {list.map((x) => (
          <li key={x.id} className="flex items-center gap-3 p-3">
            <Logo path={x.logo_path} name={x.name} size={44} />
            <div className="flex-1"><p className="font-medium">{x.name}</p><p className="text-xs text-muted">{SPONSOR_TIER[x.tier]}</p></div>
            <Link href={`?edit=${x.id}`} className="btn-ghost btn-sm">تعديل</Link>
            <form action={deleteSponsor.bind(null, id, x.id)}><button className="text-xs text-muted hover:text-primary">حذف</button></form>
          </li>
        ))}
      </ul>
      <form key={s?.id ?? "new"} action={saveSponsor.bind(null, id, s?.id ?? null)} className="card flex flex-col gap-3 p-5">
        <Flash error={sp.error} />
        <h2 className="font-heading text-lg font-bold">{s ? "تعديل راعٍ" : "راعٍ جديد"}</h2>
        <ImageField name="logo_path" label="الشعار" prefix={`exhibitions/${id}/sponsors`} initial={s?.logo_path} />
        <div><label className="label">الاسم</label><input name="name" className="input" required defaultValue={s?.name} /></div>
        <div><label className="label">الفئة</label><select name="tier" className="input" defaultValue={s?.tier ?? "partner"}>
          {Object.entries(SPONSOR_TIER).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></div>
        <div><label className="label">جناح الراعي (إن وجد)</label><select name="booth_id" className="input" defaultValue={s?.booth_id ?? ""}>
          <option value="">—</option>{(booths ?? []).map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}</select></div>
        <div><label className="label">الموقع</label><input name="website_url" type="url" className="input" dir="ltr" defaultValue={s?.website_url ?? ""} /></div>
        <div><label className="label">الترتيب</label><input name="sort_order" type="number" className="input" defaultValue={s?.sort_order ?? 0} /></div>
        <div className="flex gap-2"><button className="btn-primary">حفظ</button>{s && <Link href="?" className="btn-ghost">إلغاء</Link>}</div>
      </form>
    </div>
  );
}
