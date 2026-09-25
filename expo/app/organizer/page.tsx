import Link from "next/link";
import { expo, getUser } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import type { Exhibition } from "@/lib/types";
import { Flash } from "@/components/Flash";
import { EmptyState, Logo, StatusBadge } from "@/components/ui";
import { createOrganizer } from "./actions";

export const metadata = { title: "لوحة المنظم" };

export default async function OrganizerHome({ searchParams }: { searchParams: Promise<{ error?: string; ok?: string }> }) {
  const sp = await searchParams;
  const user = (await getUser())!;
  const db = await expo();
  const { data: mem } = await db.from("organizer_members").select("role, organizers(id, name, logo_path, is_verified, is_suspended)").eq("user_id", user.id);
  const orgs = ((mem ?? []) as unknown as { role: string; organizers: { id: string; name: string; logo_path: string | null; is_verified: boolean; is_suspended: boolean } }[]).map((m) => m.organizers);
  const { data: ex } = orgs.length
    ? await db.from("exhibitions").select("*").in("organizer_id", orgs.map((o) => o.id)).order("starts_at", { ascending: false })
    : { data: [] };
  return (
    <div className="container-x flex flex-col gap-8 py-8">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="section-title me-auto">لوحة المنظم</h1>
        {orgs.length > 0 && <Link href="/organizer/new" className="btn-primary">معرض جديد</Link>}
      </div>
      <Flash error={sp.error} ok={sp.ok === "org" ? "تم إنشاء حساب المنظم. سيراجعه فريق Red Market لتفعيل النشر." : undefined} />
      {orgs.length === 0 ? (
        <form action={createOrganizer} className="card mx-auto flex w-full max-w-lg flex-col gap-4 p-6">
          <h2 className="font-heading text-xl font-bold">أنشئ حساب منظم</h2>
          <p className="text-sm text-muted">يمكنك إعداد معارضك فوراً، ويتطلب نشرها للزوار توثيق الحساب من إدارة Red Market.</p>
          <div><label className="label" htmlFor="on">اسم الجهة المنظمة</label><input id="on" name="name" className="input" required minLength={2} /></div>
          <button className="btn-primary">إنشاء</button>
        </form>
      ) : (
        <>
          <div className="flex flex-wrap gap-3">
            {orgs.map((o) => (
              <div key={o.id} className="card flex items-center gap-3 p-4">
                <Logo path={o.logo_path} name={o.name} size={40} />
                <div><p className="font-semibold">{o.name}</p>
                  <p className="text-xs text-muted">{o.is_suspended ? "موقوف" : o.is_verified ? "موثّق ✓" : "بانتظار التوثيق"}</p></div>
              </div>
            ))}
          </div>
          {(ex?.length ?? 0) === 0 ? <EmptyState title="لا توجد معارض" action={<Link href="/organizer/new" className="btn-primary">أنشئ أول معرض</Link>} /> : (
            <div className="card overflow-x-auto">
              <table className="table-x">
                <thead><tr><th>المعرض</th><th>الموعد</th><th>الحالة</th></tr></thead>
                <tbody>
                  {(ex as Exhibition[]).map((e) => (
                    <tr key={e.id}>
                      <td><Link href={`/organizer/e/${e.id}`} className="font-semibold hover:text-primary">{e.title}</Link></td>
                      <td className="text-muted">{fmtDate(e.starts_at, e.timezone)}</td>
                      <td><StatusBadge status={e.status} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
    </div>
  );
}
