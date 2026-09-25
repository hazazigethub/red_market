import Link from "next/link";
import { expo } from "@/lib/supabase/server";
import { thumb } from "@/lib/storage";
import { EmptyState, Tabs } from "@/components/ui";

type Hit = { kind: string; id: string; title: string; subtitle: string | null; exhibition_slug: string; ref_slug: string | null; image: string | null };
const KIND: Record<string, string> = { exhibition: "المعارض", booth: "العارضون", product: "المنتجات", session: "الجلسات", speaker: "المتحدثون" };

function href(h: Hit) {
  switch (h.kind) {
    case "exhibition": return `/e/${h.exhibition_slug}`;
    case "booth": return `/e/${h.exhibition_slug}/b/${h.ref_slug}`;
    case "product": return `/e/${h.exhibition_slug}/b/${h.ref_slug}?tab=products`;
    case "session": return `/e/${h.exhibition_slug}/sessions#${h.id}`;
    default: return `/e/${h.exhibition_slug}/speakers#${h.id}`;
  }
}

export async function SearchResults({ q, kind, exhibitionId, basePath }: { q: string; kind?: string; exhibitionId?: string; basePath: string }) {
  const db = await expo();
  const { data } = q.trim().length >= 2
    ? await db.rpc("search", { p_q: q, p_exhibition: exhibitionId ?? null, p_limit: 60 })
    : { data: [] };
  const hits = (data ?? []) as Hit[];
  const kinds = Object.keys(KIND).filter((k) => hits.some((h) => h.kind === k));
  const active = kind && kinds.includes(kind) ? kind : "all";
  const shown = active === "all" ? hits : hits.filter((h) => h.kind === active);
  return (
    <div className="flex flex-col gap-5">
      <form action={basePath}>
        <label htmlFor="sq" className="sr-only">ابحث</label>
        <input id="sq" name="q" defaultValue={q} autoFocus className="input py-3 text-base" placeholder="ابحث عن عارض، منتج، جلسة أو متحدث" />
      </form>
      {q.trim().length < 2 ? <p className="text-sm text-muted">اكتب حرفين على الأقل. البحث يتجاهل التشكيل وفروق الهمزات والتاء المربوطة.</p>
        : hits.length === 0 ? <EmptyState title={`لا نتائج لـ «${q}»`} body="جرّب كلمة أقصر أو اسماً مختلفاً." /> : (
        <>
          <Tabs active={active} items={[{ key: "all", label: "الكل", href: `${basePath}?q=${encodeURIComponent(q)}`, count: hits.length },
            ...kinds.map((k) => ({ key: k, label: KIND[k], href: `${basePath}?q=${encodeURIComponent(q)}&kind=${k}`, count: hits.filter((h) => h.kind === k).length }))]} />
          <ul className="card divide-y divide-line">
            {shown.map((h) => (
              <li key={`${h.kind}-${h.id}`}>
                <Link href={href(h)} className="flex items-center gap-3 p-4 hover:bg-bg/60">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  {h.image ? <img src={thumb(h.image, 96) ?? h.image} alt="" className="h-12 w-12 rounded-lg object-cover" />
                    : <span className="grid h-12 w-12 place-items-center rounded-lg bg-bg text-xs text-muted">{KIND[h.kind]?.slice(0, 3)}</span>}
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold">{h.title}</p>
                    {h.subtitle && <p className="truncate text-sm text-muted">{h.subtitle}</p>}
                  </div>
                  <span className="badge">{KIND[h.kind]}</span>
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
