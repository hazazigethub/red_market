import { getStaffBooth } from "@/lib/queries";
import { Flash } from "@/components/Flash";
import { ImageField } from "@/components/client/uploads";
import { updateBooth } from "../../../actions";

export default async function EditBooth({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; ok?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const b = await getStaffBooth(id);
  return (
    <form action={updateBooth.bind(null, id)} className="flex flex-col gap-6">
      <Flash error={sp.error} ok={sp.ok ? "تم حفظ الجناح." : undefined} />
      <section className="card flex flex-col gap-4 p-5">
        <h2 className="font-heading text-lg font-bold">الهوية</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <ImageField name="logo_path" label="الشعار (مربع)" prefix={`booths/${id}/brand`} initial={b.logo_path} />
          <ImageField name="cover_path" label="صورة الغلاف (عريضة 1600×600)" prefix={`booths/${id}/brand`} initial={b.cover_path} aspect="wide" />
        </div>
        <div><label className="label" htmlFor="name">اسم الجناح</label><input id="name" name="name" className="input" defaultValue={b.name} required minLength={2} maxLength={120} /></div>
        <div><label className="label" htmlFor="tagline">العبارة التعريفية</label><input id="tagline" name="tagline" className="input" defaultValue={b.tagline ?? ""} maxLength={160} placeholder="سطر واحد يلخص ما تقدمه" /></div>
        <div><label className="label" htmlFor="about">نبذة</label><textarea id="about" name="about" rows={6} className="input" defaultValue={b.about ?? ""} maxLength={5000} /></div>
      </section>
      <section className="card grid gap-4 p-5 sm:grid-cols-2">
        <h2 className="font-heading text-lg font-bold sm:col-span-2">بيانات التواصل الظاهرة للزوار</h2>
        <div><label className="label" htmlFor="whatsapp">واتساب</label><input id="whatsapp" name="whatsapp" className="input" dir="ltr" defaultValue={b.contact?.whatsapp ?? ""} placeholder="9665XXXXXXXX" /></div>
        <div><label className="label" htmlFor="phone">الهاتف</label><input id="phone" name="phone" className="input" dir="ltr" defaultValue={b.contact?.phone ?? ""} /></div>
        <div><label className="label" htmlFor="email">البريد</label><input id="email" name="email" type="email" className="input" dir="ltr" defaultValue={b.contact?.email ?? ""} /></div>
        <div><label className="label" htmlFor="website">الموقع</label><input id="website" name="website" type="url" className="input" dir="ltr" defaultValue={b.contact?.website ?? ""} placeholder="https://" /></div>
      </section>
      <section className="card flex flex-col gap-3 p-5">
        <h2 className="font-heading text-lg font-bold">الظهور</h2>
        <select name="status" className="input sm:w-64" defaultValue={b.status}>
          <option value="draft">مسودة (لا يراه الزوار)</option>
          <option value="published">منشور</option>
          <option value="hidden">مخفي مؤقتاً</option>
        </select>
        <p className="text-xs text-muted">تم إضافة جناحك في قائمة أجنحة المعرض.</p>
      </section>
      <button className="btn-primary self-start">حفظ الجناح</button>
    </form>
  );
}
