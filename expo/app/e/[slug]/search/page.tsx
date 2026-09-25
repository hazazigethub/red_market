import { getExhibition } from "@/lib/queries";
import { SearchResults } from "@/components/SearchResults";

export const metadata = { title: "بحث" };

export default async function ExhibitionSearch({ params, searchParams }: {
  params: Promise<{ slug: string }>; searchParams: Promise<{ q?: string; kind?: string }>;
}) {
  const { slug } = await params;
  const { q = "", kind } = await searchParams;
  const e = await getExhibition(slug);
  return (
    <div className="container-x max-w-3xl py-8">
      <h1 className="section-title mb-5">ابحث في {e.title}</h1>
      <SearchResults q={q} kind={kind} exhibitionId={e.id} basePath={`/e/${slug}/search`} />
    </div>
  );
}
