import Link from "next/link";
import { expo, getUser } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import type { Exhibition } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { EmptyState, Logo, StatusBadge } from "@/components/ui";
import { ParticipateButton } from "@/components/client/ParticipateButton";
import { applyToExhibition, withdrawApplication } from "./actions";

export const metadata = { title: "لوحة العارض" };

const APP_STATUS: Record<string, string> = { pending: "قيد المراجعة", approved: "مقبول", rejected: "مرفوض", withdrawn: "مسحوب" };

export default async function MerchantHome({ searchParams }: { searchParams: Promise<{ error?: string; ok?: string }> }) {
  const sp = await searchParams;
  const user = (await getUser())!;
  const db = await expo();
  const [{ data: staff }, { data: stores }, { data: apps }, { data: open }] = await Promise.all([
    db.from("booth_staff").select("role, booths(id, name, logo_path, status, views_count, follows_count, exhibitions(id, title, slug, status, starts_at, timezone))")
      .eq("user_id", user.id),
    db.rpc("my_stores"),
    db.from("booth_applications").select("id, status, created_at, review_note, exhibitions(title, slug)").order("created_at", { ascending: false }),
    db.from("exhibitions").select("*").eq("applications_open", true).in("status", ["scheduled", "live"]).order("starts_at"),
  ]);
  type SB = { role: string; booths: { id: string; name: string; logo_path: string | null; status: string; views_count: number; follows_count: number;
    exhibitions: { id: string; title: string; slug: string; status: string; starts_at: string; timezone: string } } };
  const booths = ((staff ?? []) as unknown as SB[]).filter((s) => s.booths);
  const allStores = (stores ?? []) as { id: string; name: string; expo_store_id: string | null; expo_status: string | null }[];
  const storeList = allStores.filter((s) => s.expo_status !== "suspended");
  const suspended = allStores.filter((s) => s.expo_status === "suspended");
  const joined = new Set(booths.map((b) => b.booths.exhibitions.id));
  const appliedTo = new Set(((apps ?? []) as unknown as { status: string; exhibitions: { slug: string } }[])
    .filter((a) => a.status !== "withdrawn").map((a) => a.exhibitions.slug));
  const openList = ((open ?? []) as Exhibition[]).filter((e) => !joined.has(e.id) && !appliedTo.has(e.slug));

  return (
    <div className="container-x flex flex-col gap-10 py-8">
      <div>
        <h1 className="section-title">لوحة العارض</h1>
        <p className="text-muted">أجنحتك في المعارض، الطلبات، والمعارض المفتوحة للمشاركة.</p>
      </div>
      <Flash error={sp.error} ok={sp.ok === "applied" ? "تم إرسال طلب المشاركة إلى المنظم." : undefined} />
      {suspended.length > 0 && (
        <p className="rounded-[10px] border border-primary/30 bg-tint p-3 text-sm">
          مشاركة {suspended.map((s) => s.name).join("، ")} في المعارض موقوفة من إدارة المنصة. تواصل مع دعم Red Market.
        </p>
      )}

      <section>
        <h2 className="mb-4 font-heading text-xl font-bold">أجنحتي</h2>
        {booths.length === 0 ? <EmptyState title="لا توجد أجنحة بعد" body="قدّم طلب مشاركة في أحد المعارض المفتوحة أدناه." /> : (
          <div className="grid gap-4 md:grid-cols-2">
            {booths.map(({ booths: b, role }) => (
              <Link key={b.id} href={`/merchant/booths/${b.id}`} className="card flex items-center gap-4 p-5 hover:border-ink">
                <Logo path={b.logo_path} name={b.name} size={56} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2"><p className="truncate font-heading font-bold">{b.name}</p>
                    {b.status !== "published" && <span className="badge">غير منشور</span>}</div>
                  <p className="truncate text-sm text-muted">{b.exhibitions.title} · {fmtDate(b.exhibitions.starts_at, b.exhibitions.timezone)}</p>
                  <p className="text-xs text-muted">{b.views_count} زيارة · {b.follows_count} متابع · دورك: {role === "owner" ? "مالك" : role === "manager" ? "مدير" : "مبيعات"}</p>
                </div>
                <StatusBadge status={b.exhibitions.status} />
              </Link>
            ))}
          </div>
        )}
      </section>

      {(apps?.length ?? 0) > 0 && (
        <section>
          <h2 className="mb-4 font-heading text-xl font-bold">طلبات المشاركة</h2>
          <div className="card overflow-x-auto">
            <table className="table-x">
              <thead><tr><th>المعرض</th><th>الحالة</th><th>ملاحظة المنظم</th><th></th></tr></thead>
              <tbody>
                {(apps as unknown as { id: string; status: string; review_note: string | null; exhibitions: { title: string } }[]).map((a) => (
                  <tr key={a.id}>
                    <td>{a.exhibitions.title}</td>
                    <td><span className="badge">{APP_STATUS[a.status]}</span></td>
                    <td className="text-muted">{a.review_note ?? "—"}</td>
                    <td>{a.status === "pending" && <form action={withdrawApplication.bind(null, a.id)}><button className="text-sm text-muted hover:text-primary">سحب</button></form>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section>
        <h2 className="mb-4 font-heading text-xl font-bold">معارض مفتوحة للمشاركة</h2>
        {allStores.length === 0 ? (
          <EmptyState title="تحتاج متجراً في Red Market" body="المشاركة في المعارض متاحة لأصحاب المتاجر. أنشئ متجرك في Red Market أولاً." />
        ) : openList.length === 0 ? <EmptyState title="لا توجد معارض مفتوحة حالياً" /> : (
          <div className="grid gap-4 md:grid-cols-2">
            {openList.map((e) => (
              <div key={e.id} className="card flex flex-wrap items-center gap-4 p-5">
                <Logo path={e.logo_path} name={e.title} size={48} />
                <div className="min-w-0 flex-1"><p className="font-heading font-bold">{e.title}</p>
                  <p className="text-sm text-muted">{fmtDate(e.starts_at, e.timezone)} — {fmtDate(e.ends_at, e.timezone)}</p></div>
                <ParticipateButton exhibitionId={e.id} merchantId={storeList[0].id} action={applyToExhibition} />
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
