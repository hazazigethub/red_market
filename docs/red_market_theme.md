# ثيم رد ماركت — مرجع معتمد

> كل ما في هذا الملف مأخوذ من ملفات المشروع مباشرة، وليس افتراضاً.

## مصدر الثيم الرسمي

الحزمة المشتركة `red_market_core`:

- `C:\Users\L\red_market\core\lib\config\app_colors.dart`
- `C:\Users\L\red_market\core\lib\config\app_theme.dart`

## الألوان الرسمية — `AppColors`

| الاسم | القيمة | الاستخدام |
|---|---|---|
| `brand` | `#D32027` | لون الهوية |
| `primary` | `#D32027` | اللون الأساسي |
| `secondary` | `#2D3E50` | لون مساعد |
| `backgroundLight` | `#F8F9FA` | خلفية الوضع الفاتح |
| `backgroundDark` | `#1A1A1A` | خلفية الوضع الداكن |
| `textPrimary` | `#212121` | النص الأساسي |
| `textSecondary` | `#757575` | النص الثانوي |
| `success` | `#4CAF50` | نجاح |
| `error` | `#E53935` | خطأ |
| `warning` | `#FFB74D` | تنبيه |

## إعدادات الثيم — `AppTheme`

**الوضع الفاتح (`AppTheme.light`):**

- Material 3
- `ColorScheme.fromSeed` من `AppColors.primary`، والسطح `backgroundLight`
- خلفية الصفحات `backgroundLight`
- بدون تأثير ضغط: `NoSplash`، و`splashColor` و`highlightColor` شفافة
- الخط: Cairo عبر `GoogleFonts.cairoTextTheme()`
- الشريط العلوي: بلا ظل، العنوان في الوسط، أسود عريض بحجم 18
- الأزرار `ElevatedButton`: خلفية `primary`، نص أبيض، بلا ظل، حواف 12، حشوة أفقية 24 وعمودية 12

**الوضع الداكن (`AppTheme.dark`):**

- Material 3
- `ColorScheme.fromSeed` من `primary` بسطوع داكن، والسطح `backgroundDark`
- خلفية الصفحات `backgroundDark`
- بدون تأثير ضغط
- الخط: Cairo على نصوص الوضع الداكن

## الخط

Cairo، ويُحمَّل من حزمة `google_fonts`. غير مسجّل كملف في `pubspec.yaml`.

## وضع لوحة التحكم (`panel`) حالياً

- `panel\lib\main.dart` **لا يستخدم `AppTheme`**، بل يبني ثيماً خاصاً:
  - Material 3، و`ColorScheme.fromSeed` من `AppColors.brand`، والسطح أبيض
  - خلفية الصفحات أبيض
  - Cairo عبر `GoogleFonts.cairoTextTheme`
  - اللغة عربية، والاتجاه RTL
- الصفحات تكتب ألوانها مباشرة. أكثر القيم استخداماً (من فحص كل ملفات `panel\lib`):

| اللون | عدد المرات | الاستخدام الفعلي |
|---|---|---|
| `#EDEFF3` | 121 | حدود البطاقات والحقول |
| `#F7F8FA` | 84 | خلفية الصفحات |
| `#D32027` | 80 | اللون الأساسي |
| `#1E1E1E` | 34 | الوضع الداكن |
| `#E5E7EB` | 32 | حدود ثانوية |
| `#F1F2F5` | 23 | خلفيات ثانوية وحالة "مغلق" |
| `#1F2937` | 21 | النص الأساسي |
| `#4CAF50` | 18 | الأخضر |
| `#121212` | 13 | الوضع الداكن |
| `#B71C1C` | 10 | أحمر داكن |

### فروقات بين الرسمي والمستخدم في اللوحة

| العنصر | الرسمي | المستخدم في الصفحات |
|---|---|---|
| خلفية الصفحات | `#F8F9FA` | `#F7F8FA` |
| النص الأساسي | `#212121` | `#1F2937` |
| خلفية الداكن | `#1A1A1A` | `#1E1E1E` و`#121212` |

## أنماط التصميم المتكررة في صفحات اللوحة

- البطاقة: خلفية بيضاء، حدود `#EDEFF3`، حواف 12 إلى 14
- الحقول: ارتفاع 44، خلفية بيضاء، حدود `#EDEFF3`، وعند التركيز حدود `#D32027` بسماكة 1.4، حواف 11
- التبويبات: ارتفاع 44، حواف 11، النشط أحمر بنص أبيض، وغير النشط أبيض بحدود `#EDEFF3`
- القوائم الفرعية تُعرض داخل نفس الصفحة مع زر "رجوع" (`arrow_back_ios_new` بحجم 15 ولون أحمر)، بدل فتح صفحة جديدة أو شاشة سفلية
- الأسهم في RTL: Flutter يقلب `chevron_left` و`chevron_right` تلقائياً، فالسهم الأيمن (السابق) يُكتب `chevron_left_rounded`، والأيسر (التالي) يُكتب `chevron_right_rounded`

## هيكل المشروع

| المجلد | المحتوى | يُنشر على |
|---|---|---|
| `C:\Users\L\red_market\core` | الحزمة المشتركة `red_market_core` (الثيم، النماذج) | — |
| `C:\Users\L\red_market\panel` | لوحة التحكم (Flutter Web) | Cloudflare Worker `red-market-panel` ← `panel.redmarket.pro` |
| `C:\Users\L\red_market\app` | تطبيق الجوال (Flutter) | — |
| `C:\Users\L\red_market\site` | الموقع (Next.js 16 عبر OpenNext) | Cloudflare Worker `red-market-site` ← `www.redmarket.pro` |
| `C:\Users\L\red_market\docs\sql` | توثيق كل تعديلات قاعدة البيانات المنفّذة | — |

- `redmarket.pro` (بدون www) **يحوّل** إلى `www.redmarket.pro`. أي طلب من اللوحة للموقع يجب أن يستخدم `www`، لأن المتصفح يرفض التحويل في طلبات الـ API.
- `expo.redmarket.pro` ← Worker `expo-redmarket`.
- مشاريع Vercel (`red-market-panel` و`red-market-site`) **قديمة ولا تخدم أي زائر**. لا تُنشر عليها.
- حساب Cloudflare: `redmarket.sa@outlook.com` — Account ID `4c825eab02d8f5ef4d4279b311edd6e9`.

## أوامر العمل

**الحفظ:**

```powershell
cd C:\Users\L\red_market
git add -A
git commit -m "وصف التعديل"
git push
```

**فحص اللوحة:**

```powershell
cd C:\Users\L\red_market\panel
flutter analyze 2>&1 | Select-String -Pattern " error "
```

**فحص الموقع:**

```powershell
cd C:\Users\L\red_market\site
npm run build
```

**نشر اللوحة (Cloudflare):**

```powershell
cd C:\Users\L\red_market\panel
flutter build web --release
npx wrangler deploy
```

- الإعدادات في `panel\wrangler.jsonc` (Worker `red-market-panel`، يرفع `build\web`).
- قبل النشر تأكد ألا يوجد داخل `build\web` مجلد `.vercel` أو ملف `.env.local`، لأن كل ما فيه يُرفع ملفاتٍ عامة.
- للتحقق أن النسخة المنشورة هي المحلية:
  ```powershell
  (Get-FileHash build\web\main.dart.js).Hash
  curl.exe -s "https://panel.redmarket.pro/main.dart.js" -o "$env:TEMP\r.js"; (Get-FileHash "$env:TEMP\r.js").Hash
  ```

**نشر الموقع (Cloudflare):**

```powershell
cd C:\Users\L\red_market\site
npm run build
npm run cf:deploy
```

- بعد النشر تحقق أن المفاتيح ما زالت تُقرأ: افتح `https://www.redmarket.pro/api/payments/checkout?pid=00000000-0000-0000-0000-000000000000` ← المتوقع **"الدفعة غير موجودة"**. إذا ظهر "الدفع غير متاح حالياً" فالمفاتيح سقطت: أعد إضافتها بـ `npx wrangler secret put` **بعد** النشر.

**خطأ `The request to Cloudflare's API timed out` أو `fetch failed`:**

يحدث على نقطة اتصال الجوال (مشكلة IPv6 مع Node.js). شغّل هذا في نفس النافذة قبل `wrangler`:

```powershell
$env:NODE_OPTIONS="--dns-result-order=ipv4first"
```

وإذا فشل رفع `main.dart.js` (ملف كبير)، أعد الأمر فقط. النشر لا يكتمل إلا برفع كل الملفات، فالنسخة المنشورة لا تتأثر.

**التشغيل على الجهاز:**

```powershell
# الموقع
cd C:\Users\L\red_market\site
npm run dev

# اللوحة — تتصل بالموقع المحلي بدل المنشور
cd C:\Users\L\red_market\panel
flutter run -d chrome --web-port 7331 --dart-define=PAYMENTS_API=http://localhost:3000
```

## المفاتيح والإعدادات

| المكان | المحتوى | يُستخدم في |
|---|---|---|
| `site\.env.local` | `NEXT_PUBLIC_SUPABASE_URL` و`NEXT_PUBLIC_SUPABASE_ANON_KEY` فقط | البناء والتشغيل |
| `site\.env.development.local` | مفاتيح الخادم للتشغيل المحلي (Supabase السري، MyFatoorah، `SITE_URL`، `PANEL_URL`) | `npm run dev` فقط، ولا يدخل النشر |
| أسرار Cloudflare (Worker `red-market-site`) | `SUPABASE_SERVICE_ROLE_KEY`، `MYFATOORAH_BASE_URL`، `MYFATOORAH_API_KEY`، `MYFATOORAH_WEBHOOK_SECRET`، `SITE_URL`، `PANEL_URL`، `PANEL_ORIGINS` | الموقع المنشور |

- عرض الأسماء: `npx wrangler secret list` · إضافة أو تعديل: `npx wrangler secret put الاسم` (يطلب القيمة ولا تظهر على الشاشة).
- القيم المنشورة: `SITE_URL=https://www.redmarket.pro` · `PANEL_URL` و`PANEL_ORIGINS` = `https://panel.redmarket.pro`.
- **لا مفاتيح سرية في اللوحة إطلاقاً.** اللوحة تعمل في متصفح التاجر، وكل ما يحتاج مفتاحاً سرياً يمر عبر الموقع.
- عنوان خادم الدفع في اللوحة: `kPaymentsApiBase` في `panel\lib\features\payments\payments_api.dart`، افتراضياً `https://www.redmarket.pro`، ويُغيَّر محلياً بـ `--dart-define=PAYMENTS_API=...`.

## نظام الدفع

**المبدأ: الدفع يشحن رصيد المحفظة، وكل المشتريات من الرصيد.** المحفظة مرتبطة بمعرّف المستخدم (`auth.users`)، والدفعات والفواتير مرتبطة بالمتجر (`merchants.id`).

| العملية | أين |
|---|---|
| شحن الرصيد (MyFatoorah، بطاقات فقط، بدون حفظ بطاقات) | زر "شحن الرصيد" في `merchant_bank_account_page.dart` ← نافذة منبثقة `charge_dialog.dart` |
| إنشاء جلسة الدفع | `site\src\pages\api\payments\create.ts` (POST `/v3/sessions`) |
| صفحة الدفع داخل النافذة (حقول البطاقة + رمز التحقق) | `site\src\pages\api\payments\checkout.ts` |
| تأكيد الدفع وإضافة الرصيد | `confirm.ts` + `site\src\lib\myfatoorah.ts` (`syncPayment`) + دالة `credit_wallet_from_payment` |
| إشعار MyFatoorah (احتياط) | `site\src\pages\api\webhooks\payment.ts` — V2 بتوقيع `MyFatoorah-Signature` |
| شراء البنرات وإعلانات الافتتاح والحملات | دوال `purchase_banner` و`purchase_splash_ad` و`purchase_campaign_quota` |
| الاشتراك والترقية | `apply_upgrade` (يحسب المستحق من `calc_proration` ويخصم من الرصيد) |
| التجديد التلقائي | `renew_subscriptions` كل ساعة (cron `renew-subscriptions`)، بسعر الباقة الكامل، مع مهلة 3 أيام |
| الفواتير والإيصالات | تصدر تلقائياً بـ trigger على `wallet_transactions`. الطباعة: `invoice_print.dart` |
| صفحة "عمليات الدفع" للإدارة | `payment_dashboard.dart` + دالة `get_admin_payment_stats` |

**الضريبة:** مربوطة بالرقم الضريبي في **الإعدادات ← بيانات المنشأة للفواتير**. بدون رقم: لا ضريبة، وفواتير عادية. مع رقم: 15% تُضاف تلقائياً على الإعلانات والحملات، وفواتير ضريبية مع رمز QR. الدالة `current_vat_rate()`، وفي اللوحة `panel\lib\shared\vat.dart`. أسعار الباقات شاملة.

**الحالة:** الشحن **موقوف** (حُذف `MYFATOORAH_API_KEY`) حتى يُفعّل حساب MyFatoorah للتحصيل الحقيقي. عند التفعيل:
1. `npx wrangler secret put MYFATOORAH_API_KEY` (المفتاح الحقيقي بصلاحيات `GetPayments` و`PostPayments` و`PostSessions`).
2. `npx wrangler secret put MYFATOORAH_BASE_URL` ← `https://api-sa.myfatoorah.com`
3. تصفير بيانات التجربة (أرصدة، حركات، دفعات، فواتير، إيصالات، اشتراكات وبلاغات تجريبية).
4. شحن حقيقي بـ 10 ريال والتحقق من الرصيد والإيصال وجدول `payment_webhooks`.
5. تغيير رسالة "إعدادات الخادم ناقصة" إلى "الشحن غير متاح حالياً".

## البلاغات

- العميل يبلغ عن العرض أو المتجر من التطبيق والموقع (`site\src\components\ReportButton.tsx`)، بنفس الأسباب، ويتطلب تسجيل الدخول.
- الإدارة (إدارة العروض): **حظر** يُخفي العرض، **إلغاء الحظر** يعيده ويغلق بلاغاته، **رفض البلاغ** يغلق البلاغات ويُبقي العرض ظاهراً.
- جدول `reports` مفعّل للتحديث المباشر (`supabase_realtime`). أي جدول تستخدمه اللوحة بـ `.stream()` يجب أن يكون مفعّلاً، وإلا يظهر العدد ثم يصير صفراً.

## قواعد العمل مع Claude

- افحص قبل أي تعديل. لا افتراضات بدون معلومة كافية.
- الإجابة تكون المعلومة المطلوبة تحديداً، بلا كلام جانبي.
- أوامر SQL تُنفَّذ في Supabase ← SQL Editor، وليس في PowerShell.
- الأسابيع الإعلانية: 52 أسبوعاً في السنة (أو 53 إذا كان فيها 53 يوم أحد)، تبدأ يوم الأحد، وأسبوع 1 هو أول أحد في السنة. الأسبوع يُحسب على شهر يوم بدايته.
- ملفات `.tsx` التي فيها وسم الرابط تُسلَّم كملف للتحميل، لأن واجهة المحادثة تُخفي وسم الفتح عند العرض.
- خطوة واحدة في كل رد، وانتظار النتيجة قبل التالية.
- قبل نسخ ملف من Downloads: احذف النسخ القديمة بنفس الاسم أولاً، لأن المتصفح يحفظ الجديد باسم `(1)` أو `(2)`، فيُنسخ القديم بالخطأ.
- أوامر النسخ تُكتب بالمسار الكامل `C:\Users\L\Downloads\...` حتى تعمل من أي مجلد.
- المسارات التي فيها `[id]` تحتاج `-LiteralPath` في PowerShell.
- محرر SQL في Supabase يعرض نتيجة **آخر استعلام فقط**، فالاستعلامات المتعددة تُرسل واحداً واحداً.
