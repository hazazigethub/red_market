import { getStaffBooth } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { ROLE } from "@/lib/format";
import { Flash } from "@/components/Flash";
import { addStaff, removeStaff } from "../../../actions";

export default async function Team({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; ok?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  const b = await getStaffBooth(id);
  const db = await expo();
  const { data } = await db.rpc("booth_team", { p_booth: id });
  const team = (data ?? []) as { user_id: string; email: string; full_name: string | null; role: string }[];
  const isOwner = b.role === "owner";
  return (
    <div className="flex flex-col gap-5">
      <Flash error={sp.error} ok={sp.ok ? "تمت إضافة العضو." : undefined} />
      <div className="card overflow-x-auto">
        <table className="table-x">
          <thead><tr><th>العضو</th><th>الدور</th><th></th></tr></thead>
          <tbody>
            {team.map((m) => (
              <tr key={m.user_id}>
                <td><p className="font-medium">{m.full_name ?? "—"}</p><p className="text-xs text-muted" dir="ltr">{m.email}</p></td>
                <td><span className="badge">{ROLE[m.role]}</span></td>
                <td>{isOwner && m.role !== "owner" && (
                  <form action={removeStaff.bind(null, id, m.user_id)}><button className="text-sm text-muted hover:text-primary">إزالة</button></form>
                )}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {isOwner ? (
        <form action={addStaff.bind(null, id)} className="card grid gap-3 p-5 sm:grid-cols-[1fr_180px_auto] sm:items-end">
          <div><label className="label" htmlFor="tm">بريد حساب Red Market</label><input id="tm" name="email" type="email" required className="input" dir="ltr" /></div>
          <div><label className="label" htmlFor="tr">الدور</label>
            <select id="tr" name="role" className="input"><option value="agent">موظف مبيعات</option><option value="manager">مدير</option></select></div>
          <button className="btn-primary">إضافة</button>
        </form>
      ) : <p className="text-sm text-muted">إدارة الفريق متاحة لمالك الجناح.</p>}
      <div className="card p-5 text-sm text-muted">
        <p><b className="text-ink">المدير:</b> يبني الجناح، يبث، يرى كل العملاء ويصدّرهم ويسندهم.</p>
        <p><b className="text-ink">موظف المبيعات:</b> يرد على المحادثات ويرى العملاء غير المسندين والمسندين إليه فقط.</p>
      </div>
    </div>
  );
}
