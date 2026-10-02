import 'package:flutter/material.dart';

class AcceptableUsePage extends StatelessWidget {
  const AcceptableUsePage({super.key});

  static const Color brandRed = Color(0xFFD32027);

  static const _guidelines = <Map<String, String>>[
    {
      'title': 'دقة المعلومات',
      'desc': 'زوّد المنصة ببيانات صحيحة ومحدّثة عن متجرك وعروضك، '
          'وحدّثها فور تغيّرها.',
    },
    {
      'title': 'صدق التخفيض',
      'desc': 'يجب أن يكون السعر قبل التخفيض سعراً حقيقياً كان معمولاً به فعلاً، '
          'ولا يجوز رفعه صورياً لإظهار تخفيض غير حقيقي.',
    },
    {
      'title': 'مطابقة السعر',
      'desc': 'يجب أن يطابق السعر المعروض هنا السعر في متجرك الخارجي، '
          'وأن يكون العرض متاحاً فعلياً للشراء.',
    },
    {
      'title': 'جودة المحتوى',
      'desc': 'استخدم صوراً واضحة تعبّر عن العرض فعلاً. ويُمنع المحتوى المضلّل '
          'أو المسيء للمنافسين أو العملاء.',
    },
    {
      'title': 'النشاط المشروع',
      'desc': 'يقتصر استخدام المتجر على الأنشطة التجارية المشروعة والمسجّلة '
          'نظاماً في المملكة العربية السعودية.',
    },
    {
      'title': 'الرسائل التسويقية',
      'desc': 'استخدم رسائل المتابعين في التعريف بعروضك فقط، ولا تُرسل محتوى '
          'مخالفاً أو غير متصل بنشاط متجرك.',
    },
    {
      'title': 'حساب واحد',
      'desc': 'يُمنع إنشاء حسابات متعددة بهدف تكرار الفترة التجريبية '
          'أو استغلال سياسة الاسترداد.',
    },
    {
      'title': 'أمن المنصة',
      'desc': 'يُمنع محاولة الوصول غير المصرح به لأي جزء من الأنظمة، '
          'أو استخدام أدوات آلية للتلاعب بالإحصاءات أو الترتيب.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ===== الترويسة =====
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: brandRed.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: brandRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_user_outlined,
                                color: brandRed, size: 26),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'سياسة الاستخدام المقبول',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: brandRed,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'نلتزم بتوفير بيئة موثوقة للتجار والعملاء. '
                            'وهذه الضوابط تحفظ جودة المنصة وحقوق الجميع.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              height: 1.9,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== الضوابط =====
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFEDEFF3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: brandRed.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(Icons.rule_rounded,
                                    color: brandRed, size: 17),
                              ),
                              const SizedBox(width: 11),
                              const Text(
                                'ضوابط الاستخدام للمتاجر',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: brandRed,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          ..._guidelines.map((g) => _row(
                                g['title']!,
                                g['desc']!,
                                isDark,
                              )),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ===== التحذير =====
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'مخالفة هذه الضوابط قد تؤدي إلى إزالة العروض '
                              'المخالفة، أو تعليق الحساب مؤقتاً، أو إنهائه '
                              'نهائياً دون استرداد.',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                height: 1.8,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.orange.shade200
                                    : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded,
                color: brandRed, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    height: 1.8,
                    color: isDark ? Colors.white38 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
