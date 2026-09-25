import { isoToRiyadhLocal } from "@/lib/format";
import type { Exhibition } from "@/lib/types";
import { ImageField } from "@/components/client/uploads";

export function ExhibitionFields({ e, categories, uploadPrefix, isNew }: {
  e?: Exhibition; categories: { id: number; name_ar: string }[]; uploadPrefix: string; isNew?: boolean;
}) {
  return (
    <>
      <section className="card flex flex-col gap-4 p-5">
        <h2 className="font-heading text-lg font-bold">الأساسيات</h2>
        <div><label className="label" htmlFor="t">اسم المعرض</label><input id="t" name="title" className="input" required minLength={3} maxLength={160} defaultValue={e?.title} /></div>
        {isNew && (
          <div><label className="label" htmlFor="sl">الرابط المختصر</label>
            <div className="flex items-center gap-2" dir="ltr"><span className="text-sm text-muted">expo.redmarket.pro/e/</span>
              <input id="sl" name="slug" className="input" required pattern="[a-z0-9][a-z0-9-]{1,78}[a-z0-9]" placeholder="coffee-expo-2026" /></div>
            <p className="mt-1 text-xs text-muted">أحرف إنجليزية صغيرة وأرقام وشرطات. لا يمكن تغييره لاحقاً.</p></div>
        )}
        <div><label className="label" htmlFor="d">الوصف</label><textarea id="d" name="description" rows={5} className="input" defaultValue={e?.description ?? ""} /></div>
        <div className="grid gap-4 sm:grid-cols-2">
          <div><label className="label" htmlFor="c">التصنيف</label>
            <select id="c" name="category_id" className="input" defaultValue={e?.category_id ?? ""}>
              <option value="">—</option>{categories.map((c) => <option key={c.id} value={c.id}>{c.name_ar}</option>)}
            </select></div>
          <div><label className="label" htmlFor="lt">النوع</label>
            <select id="lt" name="location_type" className="input" defaultValue={e?.location_type ?? "virtual"}>
              <option value="virtual">افتراضي</option><option value="hybrid">هجين</option><option value="onsite">حضوري مع بث</option>
            </select></div>
          <div><label className="label" htmlFor="v">المكان (للحضوري/الهجين)</label><input id="v" name="venue" className="input" defaultValue={e?.venue ?? ""} /></div>
          <div><label className="label" htmlFor="ci">المدينة</label><input id="ci" name="city" className="input" defaultValue={e?.city ?? ""} /></div>
        </div>
      </section>
      <section className="card grid gap-4 p-5 sm:grid-cols-2">
        <h2 className="font-heading text-lg font-bold sm:col-span-2">الموعد (بتوقيت الرياض)</h2>
        <div><label className="label" htmlFor="sa">البداية</label><input id="sa" name="starts_at" type="datetime-local" className="input" required defaultValue={e ? isoToRiyadhLocal(e.starts_at) : ""} /></div>
        <div><label className="label" htmlFor="ea">النهاية</label><input id="ea" name="ends_at" type="datetime-local" className="input" required defaultValue={e ? isoToRiyadhLocal(e.ends_at) : ""} /></div>
      </section>
      <section className="card grid gap-4 p-5 sm:grid-cols-2">
        <h2 className="font-heading text-lg font-bold sm:col-span-2">الهوية البصرية</h2>
        <ImageField name="logo_path" label="الشعار" prefix={uploadPrefix} initial={e?.logo_path} />
        <ImageField name="cover_path" label="صورة الغلاف (1920×800)" prefix={uploadPrefix} initial={e?.cover_path} aspect="wide" />
      </section>
    </>
  );
}
