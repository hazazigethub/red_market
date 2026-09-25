import { redirect } from "next/navigation";
import { expo, getUser } from "@/lib/supabase/server";
import { ExhibitionFields } from "@/components/ExhibitionFields";
import { Flash } from "@/components/Flash";
import { createExhibition } from "../actions";

export const metadata = { title: "معرض جديد" };

export default async function NewExhibition({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const sp = await searchParams;
  const user = (await getUser())!;
  const db = await expo();
  const [{ data: mem }, { data: cats }] = await Promise.all([
    db.from("organizer_members").select("organizer_id, role, organizers(name)").eq("user_id", user.id).in("role", ["owner", "manager"]),
    db.from("exhibition_categories").select("id, name_ar").order("id"),
  ]);
  const orgs = (mem ?? []) as unknown as { organizer_id: string; organizers: { name: string } }[];
  if (!orgs.length) redirect("/organizer");
  return (
    <form action={createExhibition} className="container-x flex max-w-3xl flex-col gap-5 py-8">
      <h1 className="section-title">معرض جديد</h1>
      <Flash error={sp.error} />
      <div className="card p-5"><label className="label" htmlFor="org">الجهة المنظمة</label>
        <select id="org" name="organizer_id" className="input">{orgs.map((o) => <option key={o.organizer_id} value={o.organizer_id}>{o.organizers.name}</option>)}</select></div>
      <ExhibitionFields categories={cats ?? []} uploadPrefix={`organizers/${orgs[0].organizer_id}`} isNew />
      <p className="text-sm text-muted">يُنشأ المعرض كمسودة مع قاعة رئيسية. أضف القاعات والجلسات والرعاة ثم انشره.</p>
      <button className="btn-primary self-start">إنشاء المعرض</button>
    </form>
  );
}
