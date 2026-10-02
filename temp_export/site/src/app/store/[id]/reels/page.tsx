import { supabase } from '@/lib/supabase';
import ReelsViewer from '@/components/ReelsViewer';
import { notFound } from 'next/navigation';
import type { Metadata } from 'next';

export const revalidate = 60;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const { data } = await supabase
    .from('merchants')
    .select('store_name')
    .eq('id', id)
    .maybeSingle();

  const name = data?.store_name ?? 'متجر';
  return {
    title: `فيديوهات ${name} — رد ماركت`,
    description: `شاهد مقاطع ${name} على رد ماركت`,
  };
}

export default async function StoreReelsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const { data: merchant } = await supabase
    .from('merchants')
    .select('id')
    .eq('id', id)
    .maybeSingle();

  if (!merchant) notFound();

  return <ReelsViewer merchantId={id} />;
}
