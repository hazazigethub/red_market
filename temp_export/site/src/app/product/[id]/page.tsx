import { permanentRedirect } from 'next/navigation';

// legacy path -> /offer/[id]
export default async function LegacyProductPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  permanentRedirect(`/offer/${id}`);
}