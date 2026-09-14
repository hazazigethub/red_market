import { supabase } from '@/lib/supabase';
import type { Metadata } from 'next';

export const revalidate = 300;

const BRAND = '#D32027';

export const metadata: Metadata = {
  title: 'سياسة الخصوصية — رد ماركت',
  description: 'كيف نتعامل مع بياناتك في منصة رد ماركت',
};

async function getPrivacy() {
  const { data } = await supabase
    .from('terms_content')
    .select('content, version, updated_at')
    .eq('type', 'privacy_customer')
    .maybeSingle();
  return data;
}

export default async function PrivacyPage() {
  const row = await getPrivacy();

  if (!row) {
    return (
      <main className="max-w-3xl mx-auto px-4 py-20 text-center">
        <h1 className="text-2xl font-bold mb-4">سياسة الخصوصية</h1>
        <p className="text-gray-500">لم تُنشر السياسة بعد.</p>
      </main>
    );
  }

  const content = (row.content ?? '') as string;
  const version = row.version as number | null;
  const updatedAt = row.updated_at
    ? new Date(row.updated_at as string).toLocaleDateString('ar-SA')
    : null;

  return (
    <main className="max-w-3xl mx-auto px-4 py-12">
      <div
        className="rounded-xl p-6 mb-8 flex items-start gap-4"
        style={{ backgroundColor: `${BRAND}0D` }}
      >
        <div
          className="w-11 h-11 rounded-full shrink-0 flex items-center justify-center"
          style={{ backgroundColor: `${BRAND}1A` }}
        >
          <svg
            className="w-5 h-5"
            fill="none"
            stroke={BRAND}
            strokeWidth={1.8}
            viewBox="0 0 24 24"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
        </div>

        <div>
          <h1 className="text-xl font-bold" style={{ color: BRAND }}>
            سياسة الخصوصية
          </h1>
          <p className="text-xs text-gray-600 leading-6 mt-1.5">
            كيف نجمع بياناتك ونستخدمها ونحميها، وفق نظام حماية البيانات
            الشخصية في المملكة العربية السعودية.
          </p>
        </div>
      </div>

      {(version || updatedAt) && (
        <p className="text-xs text-gray-500 mb-6">
          {[
            version ? `الإصدار ${version}` : null,
            updatedAt ? `آخر تحديث ${updatedAt}` : null,
          ]
            .filter(Boolean)
            .join(' · ')}
        </p>
      )}

      <div className="bg-white border border-gray-200 rounded-xl p-6">
        <pre className="whitespace-pre-wrap font-sans text-sm text-gray-700 leading-8">
          {content}
        </pre>
      </div>
    </main>
  );
}
