import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  static const Color brandRed = Color(0xFFD32027);

  static const _groups = <Map<String, dynamic>>[
    {
      'title': 'العروض والتخفيضات',
      'icon': Icons.local_offer_outlined,
      'items': [
        {
          'q': 'كيف أضيف عرضاً جديداً؟',
          'a': 'من قسم "عروضي" في لوحة التحكم، اضغط "إضافة عرض"، ثم أدخل '
              'الاسم والوصف والسعر الأصلي ونسبة التخفيض، وارفع صورة واضحة، '
              'واختر التصنيف المناسب.',
        },
        {
          'q': 'لماذا لا أستطيع رفع عرض بلا تخفيض؟',
          'a': 'رد ماركت منصة مخصصة للعروض والتخفيضات. لذلك يجب أن يكون على كل '
              'عرض تخفيض سعري فعلي، وأن يكون السعر قبل التخفيض أعلى من السعر '
              'بعده.',
        },
        {
          'q': 'كم عرضاً أستطيع إضافته؟',
          'a': 'يختلف الحد حسب باقتك. تجد العدد المتاح والمستخدم أعلى صفحة '
              '"عروضي"، وتفاصيل كل باقة في صفحة الاشتراكات.',
        },
        {
          'q': 'كيف أنظّم عروضي؟',
          'a': 'يمكنك إنشاء تصنيفات خاصة بمتجرك من شريط التصنيفات أعلى صفحة '
              '"عروضي"، ثم إسناد كل عرض للتصنيف المناسب.',
        },
      ],
    },
    {
      'title': 'الريلز والتفاعل',
      'icon': Icons.play_circle_outline_rounded,
      'items': [
        {
          'q': 'ما فائدة الريلز؟',
          'a': 'مقاطع قصيرة تعرض عرضك بشكل حيّ. يشاهدها العملاء في قسم الريلز، '
              'ويمكنهم الانتقال لصفحة العرض مباشرة من المقطع.',
        },
        {
          'q': 'كيف أربط الريلز بعرض؟',
          'a': 'عند رفع المقطع، اختر العرض المرتبط من القائمة. ويمكنك تعديل '
              'الربط لاحقاً من أيقونة القلم على المقطع.',
        },
        {
          'q': 'ما المتابعون وكيف أستفيد منهم؟',
          'a': 'العميل الذي يتابع متجرك يصله إشعار عند إضافتك عرضاً أو مقطعاً '
              'جديداً. وتتيح بعض الباقات إرسال رسائل تسويقية مباشرة لمتابعيك.',
        },
      ],
    },
    {
      'title': 'الاشتراك والباقات',
      'icon': Icons.card_membership_outlined,
      'items': [
        {
          'q': 'كيف أختار الباقة المناسبة؟',
          'a': 'قارن الباقات في صفحة "الاشتراكات". يحدد الفرق بينها عدد العروض '
              'والريلز، ونوع التقارير، وميزات الوصول لمتابعيك.',
        },
        {
          'q': 'هل الأسعار شاملة الضريبة؟',
          'a': 'نعم. جميع الأسعار المعروضة شاملة ضريبة القيمة المضافة بنسبة 15%.',
        },
        {
          'q': 'كيف أرقّي باقتي؟',
          'a': 'اضغط "ترقية الباقة" على الباقة الأعلى. إن كنت في اشتراك مدفوع، '
              'يُحتسب رصيد الأيام المتبقية ويُخصم من تكلفة الباقة الجديدة.',
        },
        {
          'q': 'هل أستطيع الانتقال لباقة أقل؟',
          'a': 'لا يمكن تخفيض الباقة أثناء سريان الاشتراك. ويمكنك اختيار باقة '
              'أدنى عند التجديد بعد انتهاء المدة الحالية.',
        },
        {
          'q': 'ما الفترة التجريبية؟',
          'a': 'فترة مجانية تُمنح للحسابات الجديدة لمرة واحدة، تستطيع خلالها '
              'تجربة المنصة قبل الاشتراك المدفوع.',
        },
        {
          'q': 'كيف أوقف التجديد التلقائي؟',
          'a': 'من صفحة الاشتراكات، افتح كرت "التجديد التلقائي" وأوقف المفتاح. '
              'يبقى اشتراكك فعّالاً حتى نهاية المدة المدفوعة.',
        },
      ],
    },
    {
      'title': 'الاسترداد والإلغاء',
      'icon': Icons.replay_circle_filled_outlined,
      'items': [
        {
          'q': 'هل أستطيع استرداد مبلغ اشتراكي؟',
          'a': 'نعم، خلال 7 أيام للباقات الشهرية و14 يوماً للسنوية من تاريخ '
              'التفعيل. ويُعاد المبلغ كاملاً إلى وسيلة الدفع الأصلية.',
        },
        {
          'q': 'ماذا يحدث عند الاسترداد؟',
          'a': 'يُلغى اشتراكك فوراً وتختفي عروضك عن العملاء، مع بقاء بياناتك '
              'محفوظة في لوحة التحكم. وتتم معالجة الاسترداد خلال 48 ساعة.',
        },
        {
          'q': 'ماذا لو انتهت مدة الاسترداد؟',
          'a': 'يمكنك إلغاء التجديد التلقائي، وتستمر في الاستفادة من باقتك حتى '
              'نهاية المدة المدفوعة، ثم تتوقف الخدمة تلقائياً.',
        },
      ],
    },
    {
      'title': 'الحساب والتقارير',
      'icon': Icons.insights_outlined,
      'items': [
        {
          'q': 'ما الذي تعرضه التقارير؟',
          'a': 'زيارات متجرك، مشاهدات عروضك، والإعجاب والمفضلة والمشاركات. '
              'وتضيف الباقات الأعلى مخطط الزيارات ومقارنة أدائك بمتوسط السوق.',
        },
        {
          'q': 'كيف أعدّل بيانات متجري؟',
          'a': 'من "إعدادات المتجر" يمكنك تعديل الاسم والوصف والشعار ورابط '
              'المتجر. أما السجل التجاري والرقم الضريبي فيُعدَّلان عبر الدعم.',
        },
        {
          'q': 'كيف أحذف حسابي؟',
          'a': 'من "إعدادات المتجر" اختر "طلب حذف الحساب". يُوقف حسابك فوراً '
              'ويُحذف نهائياً بعد 30 يوماً، ويمكنك التراجع خلالها.',
        },
        {
          'q': 'كيف أتواصل مع الدعم؟',
          'a': 'من صفحة "تواصل معنا" في روابط مفيدة. نرد على الطلبات خلال 24 '
              'ساعة في أيام العمل.',
        },
      ],
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
                constraints: const BoxConstraints(maxWidth: 860),
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

                    Text(
                      'الأسئلة الشائعة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'إجابات لأكثر ما يسأل عنه التجار',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 26),

                    ..._groups.map((g) => _group(g, isDark)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(Map<String, dynamic> g, bool isDark) {
    final items = (g['items'] as List).cast<Map<String, String>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(g['icon'] as IconData,
                    color: brandRed, size: 17),
              ),
              const SizedBox(width: 11),
              Text(
                g['title'] as String,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: brandRed,
                ),
              ),
            ],
          ),
        ),

        ...items.map((it) => _tile(it['q']!, it['a']!, isDark)),

        const SizedBox(height: 18),
      ],
    );
  }

  Widget _tile(String question, String answer, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: brandRed,
          collapsedIconColor: Colors.grey.shade400,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          title: Text(
            question,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                answer,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.9,
                  color: isDark ? Colors.white70 : const Color(0xFF4A5468),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
