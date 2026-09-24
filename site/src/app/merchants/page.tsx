import { supabase } from '@/lib/supabase';
import Image from 'next/image';
import Link from 'next/link';
import type { Metadata } from 'next';

export const revalidate = 60;

const BRAND = '#D32027';
const PANEL_URL =
  process.env.NEXT_PUBLIC_PANEL_URL ?? 'http://localhost:5000';

// ⚠️ قبل النشر: غيّره إلى 'https://panel.redmarket.sa'

export const metadata: Metadata = {
  title: 'خدمات التاجر — رد ماركت',
  description:
    'اعرض عروضك على رد ماركت وصل إلى عملاء يبحثون عن التخفيضات. بلا عمولة على مبيعاتك.',
};

type Plan = {
  id: number;
  name: string | null;
  price: number | null;
  duration_days: number | null;
  plan_type: string | null;
  product_limit: number | null;
  reels_limit: number | null;
  has_basic_reports: boolean | null;
  has_detailed_reports: boolean | null;
  discount_percent: number | null;
  features: string[] | null;
};

async function getPlans(yearly: boolean): Promise<Plan[]> {
  const { data } = await supabase
    .from('subscription_plans')
    .select('*')
    .eq('is_active', true)
    .eq('duration_days', yearly ? 365 : 30)
    .order('sort_order', { ascending: true });
  return (data as Plan[]) ?? [];
}

const steps = [
  {
    n: '1',
    title: 'سجّل متجرك',
    body: 'أرسل بياناتك وسجلك التجاري أو وثيقة العمل الحر، ونراجعها خلال يوم عمل.',
  },
  {
    n: '2',
    title: 'أضف عروضك',
    body: 'من لوحة التحكم، ارفع عروضك بصورها وأسعارها ونسب تخفيضها.',
  },
  {
    n: '3',
    title: 'استقبل عملاءك',
    body: 'تظهر عروضك للعملاء، ومن يهتم ينتقل مباشرة إلى متجرك ليُتم الشراء.',
  },
];

const features = [
  {
    icon: 'M4 6h16M4 12h16M4 18h7',
    title: 'واجهة عرض جاهزة',
    body: 'عروضك بصور وأسعار واضحة داخل التطبيق والموقع، بلا تكلفة تطوير ولا تصميم.',
  },
  {
    icon: 'M21 21l-4.35-4.35M11 19a8 8 0 100-16 8 8 0 000 16z',
    title: 'عملاء يبحثون فعلاً',
    body: 'يتصفّح العملاء حسب التصنيفات والبحث، فيصلون لمتجرك دون أن يعرفوا اسمه.',
  },
  {
    icon: 'M15 10l4.55-2.28A1 1 0 0121 8.62v6.76a1 1 0 01-1.45.9L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z',
    title: 'ريلز لعروضك',
    body: 'مقاطع قصيرة تعرض عرضك حيّاً، ويصل منها العميل لصفحة العرض بضغطة.',
  },
  {
    icon: 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z',
    title: 'تقارير تفهمها',
    body: 'زيارات متجرك، أعلى عروضك تفاعلاً، ومقارنة أدائك بمتوسط السوق.',
  },
  {
    icon: 'M15 17h5l-1.4-1.4A2 2 0 0118 14.2V11a6 6 0 00-4-5.66V5a2 2 0 10-4 0v.34A6 6 0 006 11v3.2a2 2 0 01-.6 1.4L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9',
    title: 'متابعون وإشعارات',
    body: 'العميل يتابع متجرك، فيصله إشعار فور إضافتك عرضاً جديداً.',
  },
  {
    icon: 'M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
    title: 'بلا عمولة',
    body: 'لا نأخذ نسبة من مبيعاتك. اشتراك شهري ثابت فقط، والباقي لك.',
  },
];

const faqs = [
  {
    q: 'هل تأخذون عمولة على مبيعاتي؟',
    a: 'لا. رد ماركت منصة عرض وإحالة فقط، والشراء يتم في متجرك. مقابل الخدمة اشتراك ثابت لا غير.',
  },
  {
    q: 'ما الذي أحتاجه للتسجيل؟',
    a: 'سجل تجاري ساري أو وثيقة عمل حر، ورقم جوال وبريد إلكتروني، ورابط متجرك.',
  },
  {
    q: 'هل يمكنني تجربة المنصة أولاً؟',
    a: 'نعم. للحسابات الجديدة فترة تجريبية مجانية، تستطيع خلالها رفع عروضك ومتابعة نتائجها قبل الاشتراك.',
  },
  {
    q: 'ماذا لو غيّرت رأيي بعد الاشتراك؟',
    a: 'تسترد مبلغك كاملاً خلال 7 أيام للباقة الشهرية و14 يوماً للسنوية، بلا خصم.',
  },
];

function Price({ value, strike = false }: { value: number; strike?: boolean }) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <span className={strike ? 'line-through' : undefined}>
        {value.toLocaleString('en-US')}
      </span>
      <Image
        src="/sar.svg"
        alt="ر.س"
        width={strike ? 13 : 20}
        height={strike ? 13 : 20}
        className="opacity-80"
      />
    </span>
  );
}

export default async function MerchantsPage({
  searchParams,
}: {
  searchParams: Promise<{ billing?: string }>;
}) {
  const { billing } = await searchParams;
  const yearly = billing === 'yearly';
  const plans = await getPlans(yearly);

  return (
    <main>
      {/* ===== الواجهة ===== */}
      <section className="relative overflow-hidden border-b bg-white">
        <div
          className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage:
              'radial-gradient(circle at 20% 20%, #D32027 0%, transparent 45%), radial-gradient(circle at 80% 30%, #D32027 0%, transparent 40%)',
          }}
        />
        <div className="relative max-w-4xl mx-auto px-4 py-20 text-center">
          <span
            className="inline-block text-[11px] font-bold px-3 py-1.5 rounded-full mb-6"
            style={{ backgroundColor: `${BRAND}12`, color: BRAND }}
          >
            بلا عمولة على مبيعاتك
          </span>

          <h1 className="text-3xl sm:text-4xl font-bold leading-[1.6]">
            عروضك أمام عملاء
            <br className="sm:hidden" />{' '}
            <span style={{ color: BRAND }}>يبحثون عن التخفيضات</span>
          </h1>

          <p className="mt-5 text-gray-600 leading-8 max-w-2xl mx-auto">
            رد ماركت يجمع عروض المتاجر في مكان واحد. يتصفّح العميل ويقارن، ثم
            ينتقل مباشرة إلى متجرك لإتمام الشراء. أنت تعرض، ونحن نوصل.
          </p>

          <div className="mt-9 flex flex-wrap gap-3 justify-center">
            <a
              href={PANEL_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="px-9 py-3.5 rounded-lg text-white font-bold hover:opacity-90 transition-opacity"
              style={{ backgroundColor: BRAND }}
            >
              ابدأ الآن
            </a>
            <a
              href="#plans"
              className="px-9 py-3.5 rounded-lg border border-gray-300 text-gray-700 font-bold hover:border-gray-400 transition-colors"
            >
              الباقات والأسعار
            </a>
          </div>
        </div>
      </section>

      {/* ===== كيف تبدأ ===== */}
      <section className="max-w-5xl mx-auto px-4 py-16">
        <h2 className="text-2xl font-bold mb-3 text-center">كيف تبدأ</h2>
        <p className="text-sm text-gray-500 text-center mb-12">
          ثلاث خطوات، وتصير عروضك أمام العملاء
        </p>

        <div className="grid sm:grid-cols-3 gap-6">
          {steps.map((s) => (
            <div key={s.n} className="text-center">
              <div
                className="w-11 h-11 rounded-full mx-auto flex items-center justify-center font-bold text-white mb-4"
                style={{ backgroundColor: BRAND }}
              >
                {s.n}
              </div>
              <h3 className="font-bold mb-2">{s.title}</h3>
              <p className="text-sm text-gray-600 leading-7">{s.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ===== المزايا ===== */}
      <section className="bg-gray-50 border-y">
        <div className="max-w-5xl mx-auto px-4 py-16">
          <h2 className="text-2xl font-bold mb-3 text-center">
            ما الذي تحصل عليه
          </h2>
          <p className="text-sm text-gray-500 text-center mb-12">
            أدوات تعرض متجرك وتقيس نتائجه
          </p>

          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
            {features.map((f, i) => (
              <div
                key={i}
                className="bg-white border border-gray-200 rounded-xl p-6 hover:border-gray-300 transition-colors"
              >
                <div
                  className="w-10 h-10 rounded-lg flex items-center justify-center mb-4"
                  style={{ backgroundColor: `${BRAND}0F` }}
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
                    <path d={f.icon} />
                  </svg>
                </div>
                <h3 className="font-bold mb-2">{f.title}</h3>
                <p className="text-sm text-gray-600 leading-7">{f.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ===== الباقات ===== */}
      {plans.length > 0 && (
        <section id="plans" className="max-w-5xl mx-auto px-4 py-16">
          <h2 className="text-2xl font-bold mb-3 text-center">الباقات</h2>
          <p className="text-sm text-gray-500 text-center mb-8">
            اختر ما يناسب حجم متجرك — والأسعار شاملة الضريبة
          </p>

          <div className="flex justify-center mb-12">
            <div className="inline-flex bg-gray-100 rounded-full p-1">
              <Link
                href="/merchants?billing=monthly#plans"
                className="px-5 py-2 rounded-full text-sm font-bold transition-colors"
                style={
                  !yearly
                    ? { backgroundColor: BRAND, color: '#fff' }
                    : { color: '#4B5563' }
                }
              >
                شهرياً
              </Link>
              <Link
                href="/merchants?billing=yearly#plans"
                className="px-5 py-2 rounded-full text-sm font-bold transition-colors"
                style={
                  yearly
                    ? { backgroundColor: BRAND, color: '#fff' }
                    : { color: '#4B5563' }
                }
              >
                سنوياً
              </Link>
            </div>
          </div>

          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5 items-stretch">
            {plans.map((p) => {
              const original = p.price ?? 0;
              const discount = p.discount_percent ?? 0;
              const final =
                discount > 0
                  ? Math.floor(original * (1 - discount / 100))
                  : original;
              const isPro = p.plan_type === 'pro';
              const list = p.features ?? [];

              return (
                <div
                  key={p.id}
                  className={`relative bg-white rounded-xl p-7 flex flex-col ${
                    isPro
                      ? 'border-2 shadow-sm'
                      : 'border border-gray-200'
                  }`}
                  style={isPro ? { borderColor: BRAND } : undefined}
                >
                  {isPro && (
                    <span
                      className="absolute -top-3 right-6 text-[11px] font-bold px-3 py-1 rounded-full text-white"
                      style={{ backgroundColor: BRAND }}
                    >
                      الأكثر اختياراً
                    </span>
                  )}

                  <h3 className="text-lg font-bold">{p.name ?? 'باقة'}</h3>

                  <div className="mt-4 flex items-end gap-2.5">
                    <span
                      className="text-3xl font-bold"
                      style={{ color: BRAND }}
                    >
                      <Price value={final} />
                    </span>
                    {discount > 0 && (
                      <span className="text-sm text-gray-500 mb-1.5">
                        <Price value={original} strike />
                      </span>
                    )}
                  </div>

                  <p className="text-xs text-gray-500 mt-1.5">
                    {p.duration_days === 365 ? 'سنوياً' : 'شهرياً'}
                    {discount > 0 && (
                      <span className="text-green-700 font-bold">
                        {' '}
                        · وفّر {discount}%
                      </span>
                    )}
                  </p>

                  <div className="h-px bg-gray-100 my-6" />

                  <ul className="space-y-3 text-sm text-gray-700 flex-1">
                    {list.length > 0
                      ? list.map((f, i) => (
                          <li key={i} className="flex gap-2.5">
                            <svg
                              className="w-4 h-4 mt-0.5 shrink-0"
                              fill="none"
                              stroke={BRAND}
                              strokeWidth={2.5}
                              viewBox="0 0 24 24"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                            >
                              <path d="M5 13l4 4L19 7" />
                            </svg>
                            <span className="leading-6">{f}</span>
                          </li>
                        ))
                      : (
                        <>
                          {p.product_limit != null && (
                            <li className="flex gap-2.5">
                              <span style={{ color: BRAND }}>•</span>
                              <span>
                                حتى{' '}
                                <b>
                                  {p.product_limit === -1
                                    ? 'غير محدود'
                                    : p.product_limit}
                                </b>{' '}
                                عرض
                              </span>
                            </li>
                          )}
                          {p.reels_limit != null && (
                            <li className="flex gap-2.5">
                              <span style={{ color: BRAND }}>•</span>
                              <span>
                                حتى{' '}
                                <b>
                                  {p.reels_limit === -1
                                    ? 'غير محدود'
                                    : p.reels_limit}
                                </b>{' '}
                                ريلز
                              </span>
                            </li>
                          )}
                          {p.has_basic_reports && (
                            <li className="flex gap-2.5">
                              <span style={{ color: BRAND }}>•</span>
                              <span>تقارير أساسية</span>
                            </li>
                          )}
                          {p.has_detailed_reports && (
                            <li className="flex gap-2.5">
                              <span style={{ color: BRAND }}>•</span>
                              <span>تقارير تفصيلية</span>
                            </li>
                          )}
                        </>
                      )}
                  </ul>

                  <Link
                    href="/support"
                    className={`mt-7 block text-center py-3 rounded-lg font-bold text-sm transition-colors ${
                      isPro
                        ? 'text-white hover:opacity-90'
                        : 'border border-gray-300 text-gray-700 hover:border-gray-400'
                    }`}
                    style={isPro ? { backgroundColor: BRAND } : undefined}
                  >
                    اشترك في {p.name ?? 'الباقة'}
                  </Link>
                </div>
              );
            })}
          </div>
        </section>
      )}

      {/* ===== الأسئلة ===== */}
      <section className="bg-gray-50 border-y">
        <div className="max-w-3xl mx-auto px-4 py-16">
          <h2 className="text-2xl font-bold mb-12 text-center">
            أسئلة يسألها التجار
          </h2>

          <div className="space-y-4">
            {faqs.map((f, i) => (
              <div
                key={i}
                className="bg-white border border-gray-200 rounded-xl p-6"
              >
                <h3 className="font-bold mb-2.5">{f.q}</h3>
                <p className="text-sm text-gray-600 leading-7">{f.a}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ===== الدعوة الأخيرة ===== */}
      <section className="max-w-3xl mx-auto px-4 py-20 text-center">
        <h2 className="text-2xl font-bold mb-4">جاهز للبدء؟</h2>
        <p className="text-gray-600 mb-8 leading-8">
          تواصل معنا وسنساعدك في تجهيز متجرك ورفع أول عروضك.
        </p>

        <a
          href={PANEL_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-block px-12 py-4 rounded-lg text-white font-bold hover:opacity-90 transition-opacity"
          style={{ backgroundColor: BRAND }}
        >
          ابدأ الآن
        </a>
      </section>
    </main>
  );
}
