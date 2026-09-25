import Link from "next/link";
import { getRoles, getUser, expo } from "@/lib/supabase/server";
import { loginUrl } from "@/lib/env";

export async function Header() {
  const user = await getUser();
  const roles = await getRoles();
  let unread = 0;
  if (user) {
    const db = await expo();
    const { count } = await db.from("notifications").select("id", { count: "exact", head: true })
      .eq("user_id", user.id).is("read_at", null);
    unread = count ?? 0;
  }
  return (
    <header className="sticky top-0 z-40 border-b border-line bg-bg/90 backdrop-blur">
      <div className="container-x flex h-16 items-center gap-6">
        <Link href="/" className="flex items-baseline gap-1.5" aria-label="Expo Red Market">
          <span className="font-heading text-2xl font-extrabold text-primary">Expo</span>
          <span className="font-heading text-sm font-bold text-ink">Red Market</span>
        </Link>
        <nav className="hidden items-center gap-5 text-sm font-medium md:flex">
          <Link href="/" className="hover:text-primary">المعارض</Link>
          <Link href="/search" className="hover:text-primary">بحث</Link>
          {(roles.isMerchant || roles.hasStore) && <Link href="/merchant" className="hover:text-primary">لوحة العارض</Link>}
          {roles.isOrganizer && <Link href="/organizer" className="hover:text-primary">لوحة المنظم</Link>}
          {roles.isAdmin && <Link href="/admin" className="hover:text-primary">الإدارة</Link>}
        </nav>
        <div className="ms-auto flex items-center gap-2">
          {user ? (
            <>
            <Link href="/me" className="btn-ghost btn-sm relative">
              معرضي
              {unread > 0 && (
                <span className="absolute -top-1.5 -left-1.5 grid h-5 min-w-5 place-items-center rounded-full bg-primary px-1 text-[11px] font-bold text-white">
                  {unread > 9 ? "9+" : unread}
                </span>
              )}
            </Link>
            <form action="/auth/signout" method="post">
              <button className="btn-sm px-2 text-xs text-muted hover:text-primary" aria-label="تسجيل الخروج">خروج</button>
            </form>
            </>
          ) : (
            <a href={loginUrl("/")} className="btn-primary btn-sm">دخول</a>
          )}
        </div>
      </div>
      <nav className="container-x flex gap-5 overflow-x-auto pb-2 text-sm md:hidden">
        <Link href="/">المعارض</Link>
        <Link href="/search">بحث</Link>
        {(roles.isMerchant || roles.hasStore) && <Link href="/merchant">لوحة العارض</Link>}
        {roles.isOrganizer && <Link href="/organizer">المنظم</Link>}
        {roles.isAdmin && <Link href="/admin">الإدارة</Link>}
      </nav>
    </header>
  );
}
