import Link from "next/link";
import { EXHIBITION_STATUS } from "@/lib/format";
import { thumb } from "@/lib/storage";

export function LiveBadge({ label = "مباشر" }: { label?: string }) {
  return <span className="badge-live"><span className="live-dot" aria-hidden />{label}</span>;
}

export function StatusBadge({ status }: { status: string }) {
  if (status === "live") return <LiveBadge label="مباشر الآن" />;
  return <span className="badge">{EXHIBITION_STATUS[status] ?? status}</span>;
}

export function Logo({ path, name, size = 56, className = "" }: { path?: string | null; name: string; size?: number; className?: string }) {
  const src = thumb(path, size * 2);
  return src ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={src} alt={name} width={size} height={size} loading="lazy"
      className={`shrink-0 rounded-xl border border-line bg-surface object-cover ${className}`} style={{ width: size, height: size }} />
  ) : (
    <span className={`grid shrink-0 place-items-center rounded-xl bg-ink font-heading font-extrabold text-bg ${className}`}
      style={{ width: size, height: size, fontSize: size * 0.4 }} aria-hidden>
      {name.trim().charAt(0)}
    </span>
  );
}

export function Cover({ path, alt, className = "" }: { path?: string | null; alt: string; className?: string }) {
  const src = thumb(path, 1600);
  return src ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={src} alt={alt} className={`h-full w-full object-cover ${className}`} />
  ) : (
    <div className={`h-full w-full bg-[linear-gradient(135deg,#8E0F0D_0%,#C21815_55%,#191413_100%)] ${className}`} aria-hidden />
  );
}

export function EmptyState({ title, body, action }: { title: string; body?: string; action?: React.ReactNode }) {
  return (
    <div className="card flex flex-col items-center gap-3 px-6 py-12 text-center">
      <p className="font-heading text-lg font-bold">{title}</p>
      {body && <p className="max-w-md text-sm text-muted">{body}</p>}
      {action}
    </div>
  );
}

export function Stat({ label, value, hint }: { label: string; value: React.ReactNode; hint?: string }) {
  return (
    <div className="card p-5">
      <p className="text-sm text-muted">{label}</p>
      <p className="mt-1 font-heading text-3xl font-extrabold">{value}</p>
      {hint && <p className="mt-1 text-xs text-muted">{hint}</p>}
    </div>
  );
}

export function SectionHead({ title, href, linkLabel = "عرض الكل" }: { title: string; href?: string; linkLabel?: string }) {
  return (
    <div className="mb-5 flex items-end justify-between gap-4">
      <h2 className="section-title">{title}</h2>
      {href && <Link href={href} className="text-sm font-semibold text-primary hover:text-primary-dark">{linkLabel}</Link>}
    </div>
  );
}

export function Tabs({ items, active }: { items: { key: string; label: string; href: string; count?: number }[]; active: string }) {
  return (
    <nav className="flex gap-6 overflow-x-auto border-b border-line" aria-label="أقسام">
      {items.map((t) => (
        <Link key={t.key} href={t.href} scroll={false} className={`tab ${active === t.key ? "tab-active" : ""}`}
          aria-current={active === t.key ? "page" : undefined}>
          {t.label}{t.count != null && <span className="ms-1 text-muted">({t.count})</span>}
        </Link>
      ))}
    </nav>
  );
}
