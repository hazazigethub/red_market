import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red_market/core/routing/route_paths.dart'; // ✅ استيراد المسارات

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final List<Map<String, String>> _faqs = [
    {
      "q": "ما هو رد ماركت؟",
      "a":
          "منصة تجمع لك عروض وتخفيضات متاجر متعددة في مكان واحد، لتتصفحها وتقارن بينها بسهولة، ثم تنتقل مباشرة إلى صفحة العرض في متجره لإتمام الشراء."
    },
    {
      "q": "كيف أشتري عرضاً؟",
      "a":
          "اختر العرض الذي يعجبك، ثم اضغط على زر الانتقال للمتجر. سيفتح لك موقع المتجر مباشرة لتكمل عملية الشراء لديه."
    },
    {
      "q": "هل يتم الشراء والدفع داخل رد ماركت؟",
      "a":
          "لا. رد ماركت منصة عرض وإحالة فقط. الشراء والدفع والشحن والإرجاع تتم لدى المتجر نفسه ووفق سياساته."
    },
    {
      "q": "هل الأسعار والعروض محدّثة؟",
      "a":
          "يقوم كل تاجر بإضافة عروضه وتحديث أسعارها بنفسه. ننصح دائماً بالتأكد من السعر والتوفر في صفحة العرض داخل المتجر قبل الشراء."
    },
    {
      "q": "كيف أحفظ عرضاً للرجوع إليه لاحقاً؟",
      "a":
          "سجّل الدخول ثم أضف العرض إلى المفضلة، وستجده في أي وقت داخل حسابك."
    },
    {
      "q": "لدي متجر، كيف أضيف عروضي؟",
      "a":
          "يمكنك تسجيل متجرك عبر موقع رد ماركت وإدارة عروضك من لوحة التاجر. تواصل معنا عبر خدمة العملاء لمعرفة التفاصيل."
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text("الأسئلة الشائعة",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.quiz_outlined, size: 80, color: brandRed),
            const SizedBox(height: 20),
            Text(
              "كيف يمكننا مساعدتك اليوم؟",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 30),
            ..._faqs.map((faq) => Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                  ),
                  child: ExpansionTile(
                    iconColor: brandRed,
                    collapsedIconColor: Colors.grey,
                    shape: const Border(),
                    title: Text(faq['q']!,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(faq['a']!,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.grey,
                                fontSize: 13,
                                height: 1.6)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
