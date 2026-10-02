import { supabase } from '@/lib/supabase';
import type { Metadata } from 'next';

export const revalidate = 3600;

export const metadata: Metadata = {
  title: 'الشروط والأحكام — رد ماركت',
  description: 'اتفاقية استخدام منصة رد ماركت',
};

const PLACEHOLDER = '( يجب وضع الاسم القانوني هنا )';

async function getTerms() {
  const { data } = await supabase
    .from('terms_content')
    .select('content, version')
    .eq('type', 'customer')
    .maybeSingle();
  return data;
}

function renderContent(content: string) {
  const parts = content.split(PLACEHOLDER);
  return parts.map((part, i) => (
    <span key={i}>
      {part}
      {i < parts.length - 1 && (
        <span className="font-bold text-red-600">{PLACEHOLDER}</span>
      )}
    </span>
  ));
}

export default async function TermsPage() {
  const terms = await getTerms();

  return (
    <main className="max-w-3xl mx-auto px-4 py-12">
      <h1 className="text-2xl font-bold mb-2">الشروط والأحكام</h1>
      {terms?.version && (
        <p className="text-sm text-gray-500 mb-8">
          الإصدار {terms.version}
        </p>
      )}

      {terms?.content ? (
        <div className="text-gray-700 leading-8 text-sm whitespace-pre-line">
          {renderContent(terms.content)}
        </div>
      ) : (
        <p className="text-gray-500 py-12 text-center">
          لا يوجد محتوى متاح حالياً
        </p>
      )}
    </main>
  );
}
