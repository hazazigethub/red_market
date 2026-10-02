import type { Metadata } from 'next';
import Link from 'next/link';

const BRAND = '#D32027';

export const metadata: Metadata = {
  title: 'الأسئلة الشائعة — رد ماركت',
  description: 'إجابات على أكثر الأسئلة شيوعاً حول منصة رد ماركت',
};

const groups = [
  {
    title: 'عن المنصة',
    faqs: [
      {
        q: 'ما هو رد ماركت؟',
        a: 'منصة تجمع لك عروض متاجر متعددة في مكان واحد، لتتصفحها وتقارن بينها بسهولة، ثم تنتقل مباشرة إلى صفحة العرض في متجره لإتمام الشراء.',
      },
      {
        q: 'هل استخدام المنصة مجاني؟',
        a: 'نعم، مجاني بالكامل للعملاء. لا رسوم على التصفّح ولا على التسجيل ولا على أي ميزة.',
      },
    ],
  },
  {
    title: 'الشراء والطلبات',
    faqs: [
      {
        q: 'كيف أحصل على العروض؟',
        a: 'اختر العرض الذي يعجبك، ثم اضغط زر الانتقال للمتجر. سيفتح لك موقع المتجر مباشرة لتكمل عملية الشراء لديه.',
      },
      {
        q: 'هل يتم الشراء والدفع داخل رد ماركت؟',
        a: 'لا. رد ماركت منصة عرض وإحالة فقط. الشراء والدفع والشحن والإرجاع تتم لدى المتجر نفسه ووفق سياساته.',
      },
      {
        q: 'عندي مشكلة في طلب اشتريته، بمن أتواصل؟',
        a: 'تواصل مع المتجر مباشرة، فهو الطرف المسؤول عن طلبك وتسليمه وضمانه. ويمكنك الإبلاغ عن المتجر لدينا إن كانت المشكلة تتعلق بمخالفة أو تضليل.',
      },
      {
        q: 'هل الأسعار والعروض محدّثة؟',
        a: 'يضيف كل تاجر عروضه ويحدّث أسعارها بنفسه. ننصح بالتأكد من السعر والتوفر في صفحة العرض داخل المتجر قبل الشراء.',
      },
    ],
  },
  {
    title: 'حسابك وميزاته',
    faqs: [
      {
        q: 'كيف أحفظ عرضاً للرجوع إليه لاحقاً؟',
        a: 'سجّل الدخول ثم أضف العرض إلى المفضلة، وستجده في أي وقت داخل حسابك.',
      },
      {
        q: 'ما فائدة متابعة المتاجر؟',
        a: 'حين تتابع متجراً، يصلك إشعار فور إضافته عرضاً أو مقطعاً جديداً. وتجد جديد المتاجر التي تتابعها في قسم خاص بالصفحة الرئيسية. ويمكنك إلغاء المتابعة في أي وقت.',
      },
      {
        q: 'ما هي النشرة الدورية؟',
        a: 'مجموعة عروض مختارة نرسلها بين حين وآخر لمن لديه حساب، تجمع أبرز التخفيضات المتاحة في مكان واحد.',
      },
      {
        q: 'ما فائدة الريلز؟',
        a: 'مقاطع قصيرة يعرض فيها التجار عروضهم بشكل حيّ. تشاهدها في قسم الريلز، ويمكنك الانتقال لصفحة العرض مباشرة من المقطع.',
      },
      {
        q: 'كيف أحذف حسابي؟',
        a: 'من إعدادات حسابك اطلب الحذف. يُعطَّل حسابك فوراً ويُحذف نهائياً بعد ثلاثين يوماً، ويمكنك التراجع خلال هذه المدة بالدخول إلى حسابك.',
      },
    ],
  },
  {
    title: 'الخصوصية',
    faqs: [
      {
        q: 'هل يرى التاجر بياناتي الشخصية؟',
        a: 'لا. لا يرى التاجر اسمك ولا رقم جوالك ولا بريدك. وما يراه إحصاءات مجمّعة عن متجره فقط. أما تعليقاتك فيظهر معها اسم حسابك.',
      },
      {
        q: 'هل تبيعون بياناتي؟',
        a: 'لا نبيع بياناتك ولا نؤجّرها لأي طرف. تفاصيل أوفى في سياسة الخصوصية.',
      },
    ],
  },
  {
    title: 'للتجار',
    faqs: [
      {
        q: 'لدي متجر، كيف أضيف عروضي؟',
        a: 'اطّلع على صفحة خدمات التاجر لمعرفة الباقات والمزايا وطريقة التسجيل.',
        link: { href: '/merchants', label: 'خدمات التاجر' },
      },
    ],
  },
];

export default function FaqPage() {
  return (
    <main className="max-w-3xl mx-auto px-4 py-12">
      <h1 className="text-2xl font-bold mb-3">الأسئلة الشائعة</h1>
      <p className="text-sm text-gray-500 mb-10">
        إجابات لأكثر ما يُسأل عنه
      </p>

      <div className="space-y-10">
        {groups.map((g, gi) => (
          <section key={gi}>
            <h2
              className="text-sm font-bold mb-4"
              style={{ color: BRAND }}
            >
              {g.title}
            </h2>

            <div className="space-y-3">
              {g.faqs.map((f, i) => (
                <details
                  key={i}
                  className="border border-gray-200 rounded-xl p-5 group bg-white"
                >
                  <summary className="font-bold cursor-pointer list-none flex items-center justify-between text-sm">
                    {f.q}
                    <span className="text-gray-500 group-open:rotate-180 transition-transform shrink-0 mr-3">
                      ⌄
                    </span>
                  </summary>

                  <p className="mt-3 text-gray-600 leading-7 text-sm">
                    {f.a}
                  </p>

                  {'link' in f && f.link && (
                    <Link
                      href={f.link.href}
                      className="inline-block mt-3 text-xs font-bold hover:underline"
                      style={{ color: BRAND }}
                    >
                      {f.link.label} ←
                    </Link>
                  )}
                </details>
              ))}
            </div>
          </section>
        ))}
      </div>

      <div className="mt-12 pt-8 border-t text-center">
        <p className="text-sm text-gray-600 mb-4">لم تجد إجابتك؟</p>
        <Link
          href="/support"
          className="inline-block px-8 py-3 rounded-lg text-white font-bold text-sm hover:opacity-90 transition-opacity"
          style={{ backgroundColor: BRAND }}
        >
          تواصل معنا
        </Link>
      </div>
    </main>
  );
}
