import { getOrganizedExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { BOOTH_TIER } from "@/lib/format";
import type { Booth, Hall } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { HallMap } from "@/components/HallMap";
import { deleteHall, placeBooth, saveHall } from "../../../actions";

export default async function Halls({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  const e = await getOrganizedExhibition(id);
  const db = await expo();
  const [{ data: halls }, { data: booths }] = await Promise.all([
    db.from("exhibition_halls").select("*").eq("exhibition_id", id).order("sort_order"),
    db.from("booths").select("*").eq("exhibition_id", id).order("name"),
  ]);
  const hallList = (halls ?? []) as Hall[];
  const boothList = (booths ?? []) as Booth[];
  return (
    <div className="flex flex-col gap-6">
      <Flash error={sp.error} />
      {hallList.map((h) => (
        <section key={h.id} className="card flex flex-col gap-4 p-5">
          <form action={saveHall.bind(null, id, h.id)} className="flex flex-wrap items-end gap-2">
            <div className="flex-1"><label className="label">اسم القاعة</label><input name="name" defaultValue={h.name} className="input" required /></div>
            <div><label className="label">أعمدة</label><input name="cols" type="number" min={2} max={12} defaultValue={h.map_layout?.cols ?? 6} className="input w-20" /></div>
            <div><label className="label">صفوف</label><input name="rows" type="number" min={1} max={26} defaultValue={h.map_layout?.rows ?? 4} className="input w-20" /></div>
            <div><label className="label">ترتيب</label><input name="sort_order" type="number" defaultValue={h.sort_order} className="input w-20" /></div>
            <button className="btn-ghost">حفظ</button>
          </form>
          <HallMap hall={h} booths={boothList.filter((b) => b.hall_id === h.id)} slug={e.slug} liveBoothIds={new Set()} />
          {hallList.length > 1 && <form action={deleteHall.bind(null, id, h.id)}><button className="text-xs text-muted hover:text-primary">حذف القاعة</button></form>}
        </section>
      ))}
      <form action={saveHall.bind(null, id, null)} className="card flex flex-wrap items-end gap-2 p-5">
        <div className="flex-1"><label className="label">قاعة جديدة</label><input name="name" className="input" required placeholder="القاعة B" /></div>
        <input type="hidden" name="cols" value="6" /><input type="hidden" name="rows" value="4" />
        <button className="btn-primary">إضافة قاعة</button>
      </form>

      <section className="card overflow-x-auto">
        <h2 className="border-b border-line p-4 font-heading text-lg font-bold">توزيع الأجنحة ({boothList.length})</h2>
        <table className="table-x">
          <thead><tr><th>الجناح</th><th>القاعة / الموقع / النوع / الظهور</th></tr></thead>
          <tbody>
            {boothList.map((b) => (
              <tr key={b.id}>
                <td className="font-medium">{b.name}</td>
                <td>
                  <form action={placeBooth.bind(null, id, b.id)} className="flex flex-wrap gap-2">
                    <select name="hall_id" defaultValue={b.hall_id ?? ""} className="input w-36">
                      <option value="">بدون</option>{hallList.map((h) => <option key={h.id} value={h.id}>{h.name}</option>)}</select>
                    <input name="map_slot" defaultValue={b.map_slot ?? ""} className="input w-24" placeholder="A-01" dir="ltr" />
                    <select name="tier" defaultValue={b.tier} className="input w-28">{Object.entries(BOOTH_TIER).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
                    <select name="status" defaultValue={b.status} className="input w-28">
                      <option value="draft">مسودة</option><option value="published">منشور</option><option value="hidden">مخفي</option></select>
                    <button className="btn-ghost btn-sm">حفظ</button>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
