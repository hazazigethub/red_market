# CLEANUP-REPORT — رد ماركت

**التاريخ**: ٩ سبتمبر ٢٠٢٦
**المستودعات**: `red market` · `red_market_web` · `red_market_site` · `red_market_core`

---

## نقطة الرجوع

نُفِّذ `git commit -m "before cleanup"` في المستودعات الأربعة قبل أي تعديل.

| المستودع | النتيجة |
|---|---|
| `red market` | `nothing to commit` — كان نظيفاً |
| `red_market_web` | `659f8f2` — ملف واحد |
| `red_market_site` | `nothing to commit` |
| `red_market_core` | `nothing to commit` |

---

## ١. الملفات المحذوفة

| الملف | المستودع | سبب الحذف |
|---|---|---|
| `lib/core/network/api_client.dart` | التطبيق | طبقة `Dio` كاملة بعنوان قالبي وهمي `https://api.yourdomain.com/api/v1`، تقرأ `auth_token` من `SharedPreferences` — مفتاح لا يخزّنه المشروع. **صفر مراجع** |
| `lib/core/utils/payment_args.dart` | التطبيق | محتواه سطر واحد: `Map<String, dynamic> pendingPaymentArgs = {};` — **صفر مراجع** |
| `lib/features/customer/home/presentation/widgets/red_ocean_banner.dart` | التطبيق | بقية من المنصة السابقة — **صفر مراجع** |

**طريقة التحقق قبل كل حذف**: `grep -rl` عبر كل ملفات المشروع، مع استثناء الملف نفسه.

---

## ٢. الملفات المعدّلة

### أ. لون الهوية — ١٣٣ ملفاً

| التغيير | النطاق |
|---|---|
| `#C21815` → `#D32027` | **١٣١ ملفاً** عبر المستودعات الأربعة (`.dart` · `.tsx` · `.ts` · `.css`) |
| `AppColors.primary`: `#4DAD6E` → `#D32027` | ملفان: `red market/lib/core/config/app_colors.dart:5` و`red_market_core/lib/config/app_colors.dart:8` |

> **ملاحظة**: `AppColors.primary` كان أخضر ويُغذّي `seedColor` و`ColorScheme.primary` وخلفية كل `ElevatedButton` في `app_theme.dart` (٤ مواضع). كان مقرراً حذفه، لكنه **مستخدم فعلاً** — فغُيّرت قيمته بدل حذفه.

### ب. أخطاء ظاهرة للمستخدم

| الملف | التغيير |
|---|---|
| `core/models/product_model.dart` | `products-images` → `product-images` |
| `core/widgets/unified_product_card.dart` | نفسه — ٣ مواضع |
| `.../pages/product_details_page.dart` | نفسه — موضعان |

> **المخزن `products-images` غير موجود إطلاقاً**. المخزن الحقيقي `product-images`. المسار كان ميتاً (الصور تظهر لأن الروابط مخزّنة كاملة)، لكنه فخّ لأي كود مستقبلي.

### ج. الكود الميت

| الملف | ما حُذف |
|---|---|
| `pubspec.yaml` (التطبيق) | حزمة `dio` — لم تعد مستخدمة بعد حذف `api_client.dart` |
| `lib/core/routing/route_paths.dart` | `cart` · `checkout` · `reservations` · `shippingAddresses` — **صفر مراجع لكل منها** |
| `lib/core/models/product_model.dart` | حقل `stock` من ٦ مواضع: التعريف · الباني · `fromJson` · `toJson` · `copyWith` (المعامل والإسناد). لا وجود للعمود في جدول `products`، و`toJson()` غير مستدعى في أي ملف |
| `features/admin/admin_splash_ads_screen.dart` | `_previewImage` |
| `features/merchant/products_page.dart` | `_fetchAllCategoriesFallback` و`_buildProductImage` |
| `features/merchant/useful_links_page.dart` | صنف `_ComingSoonPage` |

### د. توحيد التكرار

| الملف | التغيير |
|---|---|
| **`lib/core/services/visit_logger.dart`** | **ملف جديد** — خدمة موحّدة لتسجيل الزيارات. `pageName` إلزامي في التوقيع، والمنصة تُحسب داخلها فلا يمكن نسيانها |
| `lib/main.dart` | `logVisit()` من ٢٢ سطراً إلى ٤ — تستدعي `VisitLogger.log()`. حُذف استيراد `foundation` |
| `.../pages/home_screen.dart` | حُذف منطق المنصة المكرر — يستدعي الخدمة |
| `.../pages/store_details_page.dart` | حُذفت `_platformName` و`_recordStoreVisit` — تستدعي الخدمة |
| `.../widgets/category_grid.dart` | نفسه، مع تمرير `categoryId` و`categoryName` |
| `lib/app/app.dart` | حُذف `isDarkModeProvider` البسيط (السطر ٤٤) |

### هـ. `withOpacity` المهجورة

**٤١ ملفاً** عبر المستودعات الثلاثة (التطبيق · اللوحة · الحزمة):

```
withOpacity(0.3)  →  withValues(alpha: 0.3)
```

### و. سكربتات Next.js

| الملف | التغيير |
|---|---|
| `package.json` | إضافة `"lint": "eslint ."` و`"type-check": "tsc --noEmit"`. وحزمتان: `eslint@^9` و`eslint-config-next@16.3.1` |
| **`eslint.config.mjs`** | **ملف جديد** — flat config |

> **`next lint` أُزيل في Next 16**، فالسكربت يستدعي `eslint` مباشرة.
>
> **محاولة أولى فشلت**: استخدمت `FlatCompat` من `@eslint/eslintrc`، فأنتجت `TypeError: Converting circular structure to JSON`. السبب أن `eslint-config-next@16` يصدّر flat config جاهزاً، فتحويله يُنشئ بنية دائرية. الحل: الاستيراد المباشر من `eslint-config-next/core-web-vitals` و`eslint-config-next/typescript`، وحذف `@eslint/eslintrc`.

---

## ٣. نتائج البناء

| المستودع | `flutter analyze` / `build` |
|---|---|
| `red market` | ✅ **نجح — صفر أخطاء** |
| `red_market_web` | ✅ **نجح — صفر أخطاء** |
| `red_market_core` | ✅ (يُبنى ضمن المشروعين) |
| `red_market_site` | ✅ `npm install` نجح · `type-check` و`lint` يعملان |

---

## ٤. عدد التحذيرات — قبل وبعد

| المستودع | قبل | بعد | الفرق |
|---|---|---|---|
| `red_market_web` | **٢٥٢** | **١٣٥** | **−١١٧** (−٤٦٪) |
| `red market` | لم يُقَس | **٦٨** | — |

> عدد التطبيق قبل التنظيف لم يُسجَّل — قياسه فات قبل بدء الاستبدال الآلي.

---

## ٥. ما توقفت عنده ولم أحذفه

### 🔴 `AppColors.primary`

**السبب**: مستخدم في `app_theme.dart` — ٤ مواضع:

```dart
seedColor: AppColors.primary,        // السطر 12 — الثيم الفاتح
primary: AppColors.primary,          // السطر 13
backgroundColor: AppColors.primary,  // السطر 34 — كل ElevatedButton
seedColor: AppColors.primary,        // السطر 51 — الثيم الداكن
```

حذفه كان سيكسر ثيم التطبيق كاملاً. **بقرارك: غُيّرت قيمته إلى `#D32027` بدل حذفه.**

### 🔴 `go_router` من لوحة التحكم

**السبب**: مستخدم فعلاً في موضعين:

```dart
admin_customer_screen.dart:281   context.push('/customer-profile/${user['id']}', extra: user)
admin_products_screen.dart:462   context.push('/product-details', extra: p)
```

**⚠️ لكن هذان السطران معطوبان أصلاً**: `main.dart:35` يستخدم `MaterialApp` لا `MaterialApp.router`، فلا `GoRouter` في شجرة الواجهة. أي ضغط على عميل أو منتج في هاتين الشاشتين يرمي `GoError: No GoRouter found in context`.

**لم أعدّلهما** — خارج نطاق المهام المذكورة. **ينتظر قرارك.**

### 🔴 `_completePayment`

**مستثناة صراحةً بطلبك** — معطّلة عمداً وتنتظر ربط بوابة الدفع. لم تُلمس.

### ⚪ مسارات لم تُحذف بطلبك

`mapPicker` · `chat` · `merchantChat` · `onboarding` · `paymentSelection` — معلّقة على قرار لاحق.

### ⚪ `isDarkModeProvider` — النسخة الكاملة

حُذف البسيط فقط كما طلبت.

**⚠️ ملاحظة**: **النسختان كانتا ميتتين** — لا شيء يقرأ أياً منهما (`ref.watch` / `ref.read`: صفر نتائج). الثيم يُدار فعلياً بـ`appThemeModeProvider` في `app.dart:10`. النسخة الكاملة و`DarkModeNotifier` باقيتان في `app_providers.dart` — **معزولتان بلا مستهلك**.

---

## ٦. خطأ ارتكبته أثناء التنفيذ

عند حذف `_previewImage` من `admin_splash_ads_screen.dart`، حذفت من بداية الدالة **إلى نهاية الملف** ظناً أنها آخر عضو في الصنف. فأخذت معها `_revenueView` و`_emptyMsg` — وهما **مستخدمتان**.

كشفه `flutter analyze` فوراً:

```
error - The method '_revenueView' isn't defined ... :680:21
error - The method '_emptyMsg' isn't defined ... :1014:11
```

أُعيد الملف من نسخته الأصلية، وحُذفت `_previewImage` وحدها (الأسطر ١٣١٠–١٣٤٨).

---

## ٧. أخطاء Next.js المكتشفة — بلا إصلاح

### أ. `type-check` — خطآن

```
src/components/ProductCard.tsx:53:43
src/components/ProductCard.tsx:54:43
error TS2339: Property 'flash_sale_expiry' does not exist on type 'Product'
```

**خطأ حقيقي**: النوع `Product` في `src/lib/types.ts` ينقصه الحقل، والمكوّن يستخدمه لعرض العدّاد التنازلي.

### ب. `lint` — ٨ أخطاء

| # | الملف والسطر | القاعدة | المشكلة |
|---|---|---|---|
| ١ | `AccountRecoveryGate.tsx:68` | `react-hooks/purity` | `Date.now()` أثناء الرسم |
| ٢ | `CampaignProducts.tsx:21` | `react-hooks/purity` | `Math.random()` أثناء الرسم |
| ٣ | `CampaignProducts.tsx:75` | `react-hooks/set-state-in-effect` | `setOffset` داخل `useEffect` |
| ٤ | `CategoryShowcase.tsx:125` | نفسها | `load()` داخل `useEffect` |
| ٥ | `DiscoverMore.tsx:141` | نفسها | `loadMore()` |
| ٦ | `NotificationsBell.tsx:68` | نفسها | `load()` |
| ٧ | `ReelsViewer.tsx:205` | نفسها | `loadComments()` |
| ٨ | `SearchBox.tsx:42` | نفسها | `setHits([])` |

### ج. `lint` — ١٧ تحذيراً

جميعها من القاعدة نفسها: `@next/next/no-img-element` — استخدام `<img>` بدل `<Image />` من `next/image`.

**المواضع**: `campaign/page.tsx:36` · `favorites/page.tsx:181` · `product/[id]/page.tsx` (٣) · `search/page.tsx:162` · `store/[id]/page.tsx:70` · `CampaignBanner:17` · `CategoryShowcase` (٢) · `HeroBanner:52` · `MerchantStrip:17` · `ProductCard:41` · `ReelsViewer:521` · `RotatingMerchants:57` · `SearchBox:114` · `SmallBanners:105`

**أثرها**: أداء (LCP وعرض النطاق) — لا أعطال وظيفية.

### ⚠️ ملاحظة عن الخطأين ٢ و٣

`CampaignProducts.tsx` كُتب في هذه الجلسة نفسها. الخطآن من كتابتي، لا من كود سابق.

---

## ٨. ملخّص الحفظ

| المستودع | آخر commit |
|---|---|
| `red market` | `ec35933` — توحيد تسجيل الزيارة · ثم `withOpacity` |
| `red_market_web` | حذف الدوال غير المرجعة · ثم `withOpacity` |
| `red_market_site` | `4d175f4` — إضافة lint و type-check |
| `red_market_core` | `9ee5c16` — توحيد لون الهوية |
