import { supabase } from '@/lib/supabase';
import Link from 'next/link';
import type { Metadata } from 'next';

export const revalidate = 300;

export const metadata: Metadata = {
  title: 'التصنيفات — رد ماركت',
  description: 'تصفّح جميع تصنيفات العروض على رد ماركت',
};

type StoreCategory = {
  id: string;
  name: string | null;
};

async function getCategories() {
  const { data } = await supabase
    .from('store_categories')
    .select('id, name')
    .eq('is_visible', true)
    .order('name');
  return (data as StoreCategory[]) ?? [];
}

export default async function CategoriesPage() {
  const categories = await getCategories();

  return (
    <main className="max-w-6xl mx-auto px-4 py-10">
      <h1 className="text-2xl font-bold mb-8">التصنيفات</h1>

      {categories.length === 0 ? (
        <p className="text-gray-500 py-12 text-center">لا توجد تصنيفات</p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {categories.map((c) => (
            <Link
              key={c.id}
              href={`/category/${c.id}`}
              className="border border-gray-200 rounded-xl p-6 text-center hover:border-red-300 hover:shadow-md transition-all"
            >
              <span className="font-bold text-gray-800">
                {c.name ?? 'تصنيف'}
              </span>
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}