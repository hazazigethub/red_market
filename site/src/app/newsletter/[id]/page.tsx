import { supabase } from '@/lib/supabase';
import ProductCard from '@/components/ProductCard';
import type { Product } from '@/lib/types';
import { notFound } from 'next/navigation';
import Image from 'next/image';
import type { Metadata } from 'next';

export const revalidate = 300;

const BRAND = '#D32027';

async function getNewsletter(id: string) {
  const { data: nl } = await supabase
    .from('newsletters')
    .select('id, title, sent_at, status')
    .eq('id', id)
    .maybeSingle();

  if (!nl || nl.status !== 'sent') return { nl: null, products: [] };

  const { data: items } = await supabase
    .from('newsletter_items')
    .select('product_id, position')
    .eq('newsletter_id', id)
    .order('position');

  const ids = (items ?? []).map((i) => i.product_id as string);
  if (ids.length === 0) return { nl, products: [] };

  const { data: prods } = await supabase
    .from('products')
    .select('*')
    .in('id', ids)
    .eq('is_available', true);

  const list = (prods as Product[]) ?? [];
  const byId = new Map(list.map((p) => [p.id, p]));
  const ordered = ids.map((i) => byId.get(i)).filter(Boolean) as Product[];

  return { nl, products: ordered };
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const { data } = await supabase
    .from('newsletters')
    .select('title')
    .eq('id', id)
    .maybeSingle();

  const title = data?.title ?? 'نشرة العروض';
  return {
    title: `${title} — رد ماركت`,
    description: 'مجموعة عروض مختارة من متاجر رد ماركت',
  };
}

export default async function NewsletterPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { nl, products } = await getNewsletter(id);

  if (!nl) notFound();

  const date = nl.sent_at
    ? new Date(nl.sent_at).toLocaleDateString('ar-SA')
    : '';

  return (
    <main className="max-w-6xl mx-auto px-4 py-8">
      {/* ===== الترويسة ===== */}
      <div className="text-center border-b pb-8">
        <Image
          src="/logo.png"
          alt="رد ماركت"
          width={48}
          height={48}
          className="mx-auto object-contain"
        />
        <h1 className="text-2xl font-bold mt-4">{nl.title}</h1>
        <p className="text-sm text-gray-500 mt-2">
          {products.length} عرضاً مختاراً {date && `· ${date}`}
        </p>
      </div>

      {/* ===== دعوة للتطبيق ===== */}
      <div
        className="mt-6 rounded-lg px-5 py-4 flex flex-wrap items-center justify-between gap-3"
        style={{ backgroundColor: `${BRAND}0D` }}
      >
        <p className="text-sm text-gray-700">
          حمّل التطبيق لتحفظ العروض وتتابع متاجرك المفضلة
        </p>
        <span
          className="text-xs font-bold px-4 py-2 rounded-lg text-white opacity-70 cursor-default"
          style={{ backgroundColor: BRAND }}
        >
          تحميل التطبيق
        </span>
      </div>

      {/* ===== العروض ===== */}
      <section className="mt-8">
        {products.length === 0 ? (
          <p className="text-gray-500 py-16 text-center">
            لا توجد عروض في هذه النشرة
          </p>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
            {products.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
