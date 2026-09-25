import Link from "next/link";
import { getExhibition } from "@/lib/queries";
import { expo } from "@/lib/supabase/server";
import { fmtDateTime } from "@/lib/format";
import { thumb } from "@/lib/storage";
import type { Speaker } from "@/lib/types";
import { EmptyState } from "@/components/ui";

export const metadata = { title: "المتحدثون" };

export default async function Speakers({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const e = await getExhibition(slug);
  const db = await expo();
  const { data } = await db.from("speakers")
    .select("*, session_speakers(exhibition_sessions(id, title, starts_at))")
    .eq("exhibition_id", e.id).order("sort_order").order("full_name");
  const list = (data ?? []) as (Speaker & { session_speakers: { exhibition_sessions: { id: string; title: string; starts_at: string } }[] })[];
  return (
    <div className="container-x py-8">
      <h1 className="section-title mb-6">المتحدثون</h1>
      {list.length === 0 ? <EmptyState title="لم يُعلن عن المتحدثين بعد" /> : (
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {list.map((s) => (
            <article key={s.id} id={s.id} className="card flex flex-col gap-3 p-5">
              <div className="flex items-center gap-4">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                {s.photo_path ? <img src={thumb(s.photo_path, 200)!} alt={s.full_name} className="h-20 w-20 rounded-full object-cover" />
                  : <span className="grid h-20 w-20 place-items-center rounded-full bg-ink font-heading text-2xl font-bold text-bg">{s.full_name[0]}</span>}
                <div>
                  <h2 className="font-heading text-lg font-bold">{s.full_name}</h2>
                  <p className="text-sm text-muted">{[s.job_title, s.company].filter(Boolean).join(" · ")}</p>
                </div>
              </div>
              {s.bio && (
                <details className="text-sm text-muted">
                  <summary className="cursor-pointer font-semibold text-ink">نبذة</summary>
                  <p className="mt-2 whitespace-pre-line">{s.bio}</p>
                </details>
              )}
              {s.session_speakers.length > 0 && (
                <ul className="flex flex-col gap-1 border-t border-line pt-3 text-sm">
                  {s.session_speakers.map(({ exhibition_sessions: x }) => (
                    <li key={x.id}><Link href={`/e/${slug}/sessions#${x.id}`} className="hover:text-primary">{x.title}</Link>
                      <span className="block text-xs text-muted">{fmtDateTime(x.starts_at, e.timezone)}</span></li>
                  ))}
                </ul>
              )}
              {Object.keys(s.links ?? {}).length > 0 && (
                <div className="flex gap-3 text-sm">
                  {Object.entries(s.links).map(([k, v]) => <a key={k} href={v} target="_blank" rel="noopener" className="text-primary">{k}</a>)}
                </div>
              )}
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
