import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtMoney } from "@/lib/format";
import type { BoothProduct } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { EmptyState } from "@/components/ui";
import { toggleBoothProduct, updateBoothProduct } from "../../../actions";

export default async function Products({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<{ q?: string; error?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  await getStaffBooth(id);
  const db = await expo();
  const [{ data: inBooth }, { data: store }] = await Promise.all([
    db.rpc("booth_products_list", { p_booth: id }),
    db.rpc("store_products", { p_booth: id, p_q: sp.q ?? null }),
  ]);
  const shown = (inBooth ?? []) as BoothProduct[];
  const catalog = (store ?? []) as { id: string; name: string; price: number | null; image_url: string | null; in_booth: boolean }[];
  return (
    <div className="flex flex-col gap-6">
      <Flash error={sp.error} />
      <p className="text-sm text-muted">المنتجات تأتي من متجرك في Red Market مباشرة، والشراء يتم هناك. يمكنك تحديد سعر خاص بالمعرض وشارة مثل «عرض المعرض».</p>
      <section className="card">
        <h2 className="border-b border-line p-4 font-heading text-lg font-bold">المعروضة في الجناح ({shown.length})</h2>
        {shown.length === 0 ? <p className="p-4 text-sm text-muted">أضف منتجات من قائمة متجرك أدناه.</p> : (
          <ul className="divide-y divide-line">
            {shown.map((p) => (
              <li key={p.product_id} className="flex flex-col gap-3 p-4 md:flex-row md:items-center">
                <div className="flex min-w-0 flex-1 items-center gap-3">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  {p.image_url ? <img src={p.image_url} alt="" className="h-12 w-12 rounded-lg object-cover" /> : <span className="h-12 w-12 rounded-lg bg-bg" />}
                  <div className="min-w-0"><p className="truncate font-medium">{p.name}</p><p className="text-xs text-muted">سعر المتجر {fmtMoney(p.price)}</p></div>
                </div>
                <form action={updateBoothProduct.bind(null, id, p.product_id)} className="flex flex-wrap items-center gap-2">
                  <input name="expo_price" type="number" step="0.01" min="0" className="input w-28" placeholder="سعر المعرض" defaultValue={p.expo_price ?? ""} aria-label="سعر المعرض" />
                  <input name="expo_badge" className="input w-32" placeholder="الشارة" defaultValue={p.expo_badge ?? ""} maxLength={40} aria-label="الشارة" />
                  <input name="sort_order" type="number" className="input w-20" defaultValue={p.sort_order} aria-label="الترتيب" />
                  <label className="flex items-center gap-1.5 text-sm"><input type="checkbox" name="is_highlighted" defaultChecked={p.is_highlighted} className="h-4 w-4 accent-[#C21815]" />مميز</label>
                  <button className="btn-ghost btn-sm">حفظ</button>
                </form>
                <form action={toggleBoothProduct.bind(null, id, p.product_id, false)}><button className="text-sm text-muted hover:text-primary">إزالة</button></form>
              </li>
            ))}
          </ul>
        )}
      </section>
      <section className="card">
        <div className="flex flex-wrap items-center gap-3 border-b border-line p-4">
          <h2 className="me-auto font-heading text-lg font-bold">منتجات متجرك</h2>
          <form><input name="q" defaultValue={sp.q} className="input w-56" placeholder="ابحث في منتجاتك" /></form>
        </div>
        {catalog.length === 0 ? <div className="p-4"><EmptyState title="لا توجد منتجات" /></div> : (
          <ul className="grid gap-px bg-line sm:grid-cols-2">
            {catalog.map((p) => (
              <li key={p.id} className="flex items-center gap-3 bg-surface p-3">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                {p.image_url ? <img src={p.image_url} alt="" className="h-10 w-10 rounded-lg object-cover" /> : <span className="h-10 w-10 rounded-lg bg-bg" />}
                <div className="min-w-0 flex-1"><p className="truncate text-sm font-medium">{p.name}</p><p className="text-xs text-muted">{fmtMoney(p.price)}</p></div>
                <form action={toggleBoothProduct.bind(null, id, p.id, !p.in_booth)}>
                  <button className={p.in_booth ? "btn-ghost btn-sm" : "btn-primary btn-sm"}>{p.in_booth ? "مضاف ✓" : "أضف"}</button>
                </form>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
