import Link from "next/link";
import { redirect } from "next/navigation";
import { expo, getUser } from "@/lib/supabase/server";
import { fmtDateTime, timeAgo } from "@/lib/format";
import { EmptyState, Logo, Tabs } from "@/components/ui";
import { ChatPanel } from "@/components/client/ChatPanel";
import { markAllRead, withdrawConsent } from "./actions";

export const metadata = { title: "معرضي" };

export default async function Me({ searchParams }: { searchParams: Promise<{ tab?: string; chat?: string }> }) {
  const user = await getUser();
  if (!user) redirect("/");
  const sp = await searchParams;
  const tab = sp.chat ? "chats" : sp.tab ?? "agenda";
  const db = await expo();
  const [agenda, follows, chats, notes, consents] = await Promise.all([
    db.from("session_registrations").select("session_id, exhibition_sessions(id, title, starts_at, status, exhibitions(slug, title, timezone))")
      .eq("user_id", user.id),
    db.from("exhibition_follows").select("booth_id, booths(id, slug, name, logo_path, tagline, exhibitions(slug, title))").eq("user_id", user.id),
    db.from("exhibition_chats").select("id, status, last_message_at, booths(name, logo_path, slug), exhibitions(slug, title)")
      .eq("visitor_id", user.id).eq("type", "booth_dm").order("last_message_at", { ascending: false, nullsFirst: false }),
    db.from("notifications").select("*").eq("user_id", user.id).order("created_at", { ascending: false }).limit(50),
    db.from("exhibition_visitors").select("exhibition_id, consent_at, exhibitions(title)").eq("user_id", user.id).eq("share_contact_consent", true),
  ]);
  type Sess = { id: string; title: string; starts_at: string; status: string; exhibitions: { slug: string; title: string; timezone: string } };
  const sessions = ((agenda.data ?? []) as unknown as { exhibition_sessions: Sess }[])
    .map((r) => r.exhibition_sessions).filter(Boolean).sort((a, b) => a.starts_at.localeCompare(b.starts_at));
  type FB = { booths: { id: string; slug: string; name: string; logo_path: string | null; tagline: string | null; exhibitions: { slug: string; title: string } } };
  type Ch = { id: string; status: string; last_message_at: string | null; booths: { name: string; logo_path: string | null; slug: string }; exhibitions: { slug: string; title: string } };
  const chatList = (chats.data ?? []) as unknown as Ch[];
  const active = chatList.find((c) => c.id === sp.chat);
  const unread = (notes.data ?? []).filter((n) => !n.read_at).length;

  return (
    <div className="container-x py-8">
      <h1 className="section-title mb-5">معرضي</h1>
      <Tabs active={tab} items={[
        { key: "agenda", label: "أجندتي", href: "/me?tab=agenda", count: sessions.length },
        { key: "follows", label: "أتابعهم", href: "/me?tab=follows", count: follows.data?.length ?? 0 },
        { key: "chats", label: "محادثاتي", href: "/me?tab=chats", count: chatList.length },
        { key: "notifications", label: "الإشعارات", href: "/me?tab=notifications", count: unread },
        { key: "privacy", label: "الخصوصية", href: "/me?tab=privacy" },
      ]} />
      <div className="py-6">
        {tab === "agenda" && (sessions.length ? (
          <ul className="card divide-y divide-line">
            {sessions.map((s) => (
              <li key={s.id} className="flex flex-wrap items-center gap-3 p-4">
                <span className="w-56 text-sm font-semibold">{fmtDateTime(s.starts_at, s.exhibitions.timezone)}</span>
                <Link href={`/e/${s.exhibitions.slug}/sessions#${s.id}`} className="flex-1 hover:text-primary">{s.title}
                  <span className="block text-xs text-muted">{s.exhibitions.title}</span></Link>
              </li>
            ))}
          </ul>
        ) : <EmptyState title="لم تسجل في أي جلسة بعد" body="سجّل حضورك من صفحة الأجندة، وسنذكّرك قبل البدء بـ15 دقيقة." />)}

        {tab === "follows" && ((follows.data?.length ?? 0) ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {(follows.data as unknown as FB[]).map(({ booths: b }) => (
              <Link key={b.id} href={`/e/${b.exhibitions.slug}/b/${b.slug}`} className="card flex items-center gap-3 p-4 hover:border-ink">
                <Logo path={b.logo_path} name={b.name} size={48} />
                <div className="min-w-0"><p className="truncate font-semibold">{b.name}</p><p className="truncate text-xs text-muted">{b.exhibitions.title}</p></div>
              </Link>
            ))}
          </div>
        ) : <EmptyState title="لا تتابع أي جناح" body="تابع الأجنحة لتصلك إشعارات بثها المباشر." />)}

        {tab === "chats" && (chatList.length ? (
          <div className="grid gap-4 lg:grid-cols-[320px_1fr]">
            <ul className="card divide-y divide-line self-start">
              {chatList.map((c) => (
                <li key={c.id}>
                  <Link href={`/me?chat=${c.id}`} className={`flex items-center gap-3 p-3 ${c.id === active?.id ? "bg-bg" : "hover:bg-bg/60"}`}>
                    <Logo path={c.booths.logo_path} name={c.booths.name} size={40} />
                    <div className="min-w-0"><p className="truncate font-semibold">{c.booths.name}</p>
                      <p className="truncate text-xs text-muted">{c.last_message_at ? timeAgo(c.last_message_at) : c.exhibitions.title}</p></div>
                  </Link>
                </li>
              ))}
            </ul>
            <div className="card h-[60vh] min-h-96">
              {active ? <ChatPanel chatId={active.id} meId={user.id} readOnly={active.status !== "open"} />
                : <p className="grid h-full place-items-center text-sm text-muted">اختر محادثة</p>}
            </div>
          </div>
        ) : <EmptyState title="لا توجد محادثات" />)}

        {tab === "notifications" && (
          <div className="flex flex-col gap-3">
            {unread > 0 && <form action={markAllRead}><button className="btn-ghost btn-sm">تحديد الكل كمقروء</button></form>}
            {(notes.data?.length ?? 0) ? (
              <ul className="card divide-y divide-line">
                {notes.data!.map((n) => (
                  <li key={n.id} className={`flex gap-3 p-4 ${n.read_at ? "" : "bg-tint/40"}`}>
                    <div className="flex-1">
                      {n.href ? <Link href={n.href} className="font-semibold hover:text-primary">{n.title}</Link> : <p className="font-semibold">{n.title}</p>}
                      {n.body && <p className="text-sm text-muted">{n.body}</p>}
                    </div>
                    <span className="shrink-0 text-xs text-muted">{timeAgo(n.created_at)}</span>
                  </li>
                ))}
              </ul>
            ) : <EmptyState title="لا توجد إشعارات" />}
          </div>
        )}

        {tab === "privacy" && (
          <div className="card flex flex-col gap-4 p-5">
            <p className="text-sm text-muted">المعارض التي وافقت فيها على مشاركة بيانات تواصلك مع العارضين. سحب الموافقة يمنع إنشاء عملاء محتملين جدد باسمك، ولا يحذف الاستفسارات التي أرسلتها سابقاً.</p>
            {(consents.data?.length ?? 0) === 0 ? <p className="text-sm">لا توجد موافقات نشطة.</p> : (
              <ul className="divide-y divide-line">
                {consents.data!.map((c) => (
                  <li key={c.exhibition_id} className="flex items-center justify-between gap-3 py-3">
                    <span>{(c.exhibitions as unknown as { title: string }).title}</span>
                    <form action={withdrawConsent.bind(null, c.exhibition_id)}><button className="btn-ghost btn-sm">سحب الموافقة</button></form>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
