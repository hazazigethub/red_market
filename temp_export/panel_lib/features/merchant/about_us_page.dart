import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const Color brandRed = Color(0xFFD32027);

  static const _sections = <Map<String, dynamic>>[
    {
      'icon': Icons.lightbulb_outline_rounded,
      'title': 'الفكرة',
      'body':
          'كل متجر يعرض ما لديه في مكانه، والعميل يبحث في عشرة تطبيقات ليجد تخفيضاً يستحق. '
              'رد ماركت يقلب المعادلة: مكان واحد يجمع عروض المتاجر وتخفيضاتها، '
              'والعميل يتصفّح ويقارن ثم ينتقل مباشرة إلى المتجر الذي أعجبه.',
    },
    {
      'icon': Icons.storefront_outlined,
      'title': 'ما نفعله',
      'body':
          'نجمع عروض المتاجر وتخفيضاتها ومقاطعها القصيرة في واجهة واحدة منظّمة. '
              'حين يجد العميل ما يريد، نحيله إلى صفحة العرض في متجره ليُتم الشراء هناك. '
              'نحن جسر لا وسيط: لا نبيع ولا نشحن ولا نتدخل بين التاجر وعميله.',
    },
    {
      'icon': Icons.trending_up_rounded,
      'title': 'للتاجر',
      'body':
          'واجهة عرض جاهزة بلا تكلفة تطوير، ووصول إلى عملاء يتصفحون يومياً. '
              'تضيف عروضك من لوحة تحكم بسيطة، وتنشر مقاطع قصيرة تعرّف بها، '
              'وتتابع زياراتك — ويبقى متجرك وهويتك وأسعارك ملكك وحدك. '
              'وبلا عمولة على مبيعاتك.',
    },
    {
      'icon': Icons.shopping_bag_outlined,
      'title': 'للعميل',
      'body':
          'تصفّح واسع بلا عناء: تصنيفات مرتّبة، بحث وفلترة بالسعر، مفضلة تحفظ ما أعجبك، '
              'ومقاطع تريك العرض قبل أن تقرر. كل ذلك مجاناً، '
              'ثم يشتري من المتجر مباشرة وفق سياساته.',
    },
    {
      'icon': Icons.favorite_outline_rounded,
      'title': 'ما نؤمن به',
      'body':
          'أن التاجر الصغير يستحق واجهة بجودة الكبار. وأن العميل يستحق أن يرى '
              'خياراته كاملة قبل أن يقرر. وأن الوضوح — في السعر والمصدر والمسؤولية — '
              'أفضل من أي وعد.',
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

                    const SizedBox(height: 8),
                    _header(isDark),
                    const SizedBox(height: 34),

                    ..._sections.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _card(
                            icon: s['icon'] as IconData,
                            title: s['title'] as String,
                            body: s['body'] as String,
                            isDark: isDark,
                          ),
                        )),

                    const SizedBox(height: 20),
                    _footer(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    return Column(
      children: [
        Image.asset(
          'logo.png',
          width: 72,
          height: 72,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: brandRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded,
                color: brandRed, size: 32),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'رد ماركت',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: brandRed,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'عروض المتاجر في مكان واحد',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: isDark ? Colors.white38 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: brandRed, size: 19),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: brandRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              height: 1.9,
              color: isDark ? Colors.white70 : const Color(0xFF4A5468),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(bool isDark) {
    return Column(
      children: [
        Divider(color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
        const SizedBox(height: 16),
        Text(
          'الإصدار 1.0.0',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11.5,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}
