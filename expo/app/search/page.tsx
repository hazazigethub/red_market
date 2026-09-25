import { SearchResults } from "@/components/SearchResults";

export const metadata = { title: "بحث" };

export default async function Search({ searchParams }: { searchParams: Promise<{ q?: string; kind?: string }> }) {
  const { q = "", kind } = await searchParams;
  return (
    <div className="container-x max-w-3xl py-8">
      <h1 className="section-title mb-5">البحث في جميع المعارض</h1>
      <SearchResults q={q} kind={kind} basePath="/search" />
    </div>
  );
}
