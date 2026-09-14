import type { Metadata } from 'next';
import Link from 'next/link';
import Image from 'next/image';

const BRAND = '#D32027';

export const metadata: Metadata = {
  title: 'من نحن — رد ماركت',
  description:
    'رد ماركت منصة تجمع عروض المتاجر في مكان واحد، وتوصل العميل لمتجره في خطوة واحدة.',
};

const sections = [
  {
    title: 'الفكرة',
    body: 'كل متجر يعرض عروضه في مكانه، والعميل يبحث في عشرة تطبيقات ليجد ما يريد. رد ماركت يقلب المعادلة: مكان واحد يجمع المتاجر، والعميل يتصفح ويقارن ثم ينتقل مباشرة إلى المتجر الذي أعجبه.',
  },
  {
    title: 'ما نفعله',
    body: 'نعرض عروض المتاجر ومقاطعها القصيرة في واجهة واحدة منظّمة. حين يجد العميل ما يريد، نحيله إلى صفحة العرض في متجره ليُتم الشراء هناك. نحن جسر لا وسيط: لا نبيع ولا نشحن ولا نتدخل بين التاجر وعميله.',
  },
  {
    title: 'للتاجر',
    body: 'واجهة عرض جاهزة بلا تكلفة تطوير، ووصول إلى عملاء يتصفحون يومياً. تضيف عروضك من لوحة تحكم بسيطة، وتنشر مقاطع قصيرة تعرّف بها، وتتابع زياراتك — ويبقى متجرك وهويتك وأسعارك ملكك وحدك.',
  },
  {
    title: 'للعميل',
    body: 'تصفّح واسع بلا عناء: تصنيفات مرتّبة، بحث وفلترة بالسعر، مفضلة تحفظ ما أعجبك، ومقاطع تريك العرض قبل أن تقرر. كل ذلك مجاناً، ثم تشتري من المتجر مباشرة وفق سياساته.',
  },
  {
    title: 'ما نؤمن به',
    body: 'أن التاجر الصغير يستحق واجهة بجودة الكبار. وأن العميل يستحق أن يرى خياراته كاملة قبل أن يقرر. وأن الوضوح — في السعر والمصدر والمسؤولية — أفضل من أي وعد.',
  },
];

export default function AboutPage() {
  return (
    <main className="max-w-3xl mx-auto px-4 py-14">
      <div className="text-center">
        <Image
          src="/logo.png"
          alt="رد ماركت"
          width={64}
          height={64}
          className="mx-auto object-contain"
        />
        <h1 className="text-3xl font-bold mt-5" style={{ color: BRAND }}>
          رد ماركت
        </h1>
        <p className="text-gray-500 mt-2 leading-8">
          عروض المتاجر في مكان واحد
        </p>
      </div>

      <div className="mt-14 space-y-10">
        {sections.map((s, i) => (
          <section key={i}>
            <h2 className="font-bold text-lg mb-2" style={{ color: BRAND }}>
              {s.title}
            </h2>
            <p className="text-gray-700 leading-8 text-sm">{s.body}</p>
          </section>
        ))}
      </div>

      <div className="mt-14 pt-10 border-t text-center">
        <p className="text-gray-600 text-sm leading-8 mb-5">
          لديك متجر وتريد عرض ما لديك؟
        </p>
        <Link
          href="/merchants"
          className="inline-block px-8 py-3 rounded-lg text-white font-bold hover:opacity-90 transition-opacity"
          style={{ backgroundColor: BRAND }}
        >
          خدمات التاجر
        </Link>
      </div>
    </main>
  );
}
