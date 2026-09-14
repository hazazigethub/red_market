import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const Color brandRed = Color(0xFFD32027);

  static const _sections = <Map<String, dynamic>>[
    {
      'icon': Icons.folder_outlined,
      'title': '1. البيانات التي نجمعها',
      'body':
          'نجمع منك عند التسجيل: اسم المالك، الاسم التجاري، رقم الجوال، البريد '
              'الإلكتروني، رقم السجل التجاري أو وثيقة العمل الحر، والرقم الضريبي '
              'إن وُجد.\n\n'
              'ونجمع أثناء الاستخدام: بيانات متجرك وعروضك ومقاطعك، وسجل اشتراكاتك '
              'وفواتيرك، وإحصاءات الزيارات والتفاعل مع عروضك.\n\n'
              'ونجمع تلقائياً: نوع الجهاز والمتصفح وعنوان الشبكة وأوقات الدخول، '
              'لأغراض الأمان وتحسين الخدمة.',
    },
    {
      'icon': Icons.gavel_outlined,
      'title': '2. الأساس النظامي للمعالجة',
      'body':
          'نعالج بياناتك استناداً إلى:\n\n'
              '• تنفيذ العقد المبرم بينك وبين المنصة\n'
              '• الوفاء بالالتزامات النظامية والضريبية\n'
              '• المصلحة المشروعة في تشغيل الخدمة وحمايتها من إساءة الاستخدام\n'
              '• موافقتك الصريحة فيما يتعلق بالرسائل التسويقية',
    },
    {
      'icon': Icons.settings_outlined,
      'title': '3. أغراض الاستخدام',
      'body':
          'نستخدم بياناتك في:\n\n'
              '• إنشاء حسابك وإدارة متجرك واشتراكك\n'
              '• إظهار متجرك وعروضك أمام العملاء\n'
              '• إصدار الفواتير ومعالجة المدفوعات والاسترداد\n'
              '• تزويدك بالتقارير والإحصاءات في لوحة التحكم\n'
              '• التواصل معك بشأن حسابك أو التحديثات النظامية\n'
              '• كشف الاحتيال وحماية المنصة ومستخدميها',
    },
    {
      'icon': Icons.visibility_outlined,
      'title': '4. ما يظهر للعملاء',
      'body':
          'تُعرض للعملاء بيانات متجرك العامة فقط: الاسم التجاري، الشعار، الوصف، '
              'التصنيف، عروضك ومقاطعك، وعدد متابعيك.\n\n'
              'ولا تُعرض بياناتك الشخصية أو مستنداتك أو معلومات اشتراكك أو '
              'فواتيرك لأي عميل.',
    },
    {
      'icon': Icons.share_outlined,
      'title': '5. مشاركة البيانات',
      'body':
          'لا نبيع بياناتك ولا نؤجّرها لأي طرف.\n\n'
              'وقد نشاركها في الحالات الآتية فقط:\n\n'
              '• مزودو الخدمات التقنية الذين نستعين بهم لتشغيل المنصة، وبالقدر '
              'اللازم لأداء مهامهم، وبموجب التزامات سرية\n'
              '• مزودو خدمات الدفع لمعالجة اشتراكك واسترداده\n'
              '• الجهات المختصة عند وجود طلب أو أمر نظامي',
    },
    {
      'icon': Icons.lock_outline_rounded,
      'title': '6. حماية البيانات',
      'body':
          'نتخذ تدابير فنية وتنظيمية معقولة لحماية بياناتك، تشمل التشفير أثناء '
              'النقل، وتقييد الوصول للبيانات على من يحتاجها لأداء عمله، ومراجعة '
              'الصلاحيات دورياً.\n\n'
              'ومع ذلك، لا يمكن ضمان أمان مطلق لأي نقل عبر الإنترنت. وأنت مسؤول '
              'عن حماية بيانات دخولك وعدم مشاركتها.',
    },
    {
      'icon': Icons.schedule_outlined,
      'title': '7. مدة الاحتفاظ',
      'body':
          'نحتفظ ببياناتك طوال مدة نشاط حسابك.\n\n'
              'وعند طلب حذف الحساب، يُعطَّل فوراً وتُحذف بياناتك الشخصية نهائياً '
              'بعد 30 يوماً، مع إمكانية التراجع خلال هذه المدة.\n\n'
              'وتُستثنى السجلات المالية والضريبية والفواتير، فتُحفظ للمدد المقررة '
              'نظاماً حتى بعد حذف الحساب.',
    },
    {
      'icon': Icons.person_outline_rounded,
      'title': '8. حقوقك',
      'body':
          'وفقاً لنظام حماية البيانات الشخصية في المملكة العربية السعودية، لك '
              'الحق في:\n\n'
              '• العلم بكيفية جمع بياناتك واستخدامها\n'
              '• الوصول إلى بياناتك وطلب نسخة منها\n'
              '• تصحيح البيانات غير الدقيقة أو تحديثها\n'
              '• طلب حذف بياناتك، فيما لا يتعارض مع التزاماتنا النظامية\n'
              '• سحب موافقتك على الرسائل التسويقية في أي وقت\n\n'
              'ولممارسة أي من هذه الحقوق، تواصل معنا عبر صفحة "تواصل معنا".',
    },
    {
      'icon': Icons.campaign_outlined,
      'title': '9. الإشعارات والرسائل',
      'body':
          'نرسل لك إشعارات تشغيلية تتعلق بحسابك واشتراكك، ولا يمكن إيقافها لأنها '
              'جزء من الخدمة.\n\n'
              'أما الرسائل التسويقية فتخضع لموافقتك، ويمكنك إيقافها في أي وقت من '
              'إعدادات حسابك.',
    },
    {
      'icon': Icons.link_outlined,
      'title': '10. الروابط الخارجية',
      'body':
          'تحيل المنصة العملاء إلى رابط متجرك الخارجي لإتمام الشراء. ولا نتحمل '
              'مسؤولية سياسات الخصوصية في المواقع الخارجية، ونوصي بمراجعتها.',
    },
    {
      'icon': Icons.update_outlined,
      'title': '11. التعديل على السياسة',
      'body':
          'قد نُحدّث هذه السياسة من وقت لآخر. وتُنشر النسخة المحدّثة في هذه '
              'الصفحة مع بيان تاريخ التحديث. ويُعدّ استمرارك في استخدام المنصة '
              'بعد النشر قبولاً بالتعديل.',
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

                    // ===== الترويسة =====
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: brandRed.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: brandRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_outlined,
                                color: brandRed, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'سياسة الخصوصية',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: brandRed,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'كيف نجمع بياناتك ونستخدمها ونحميها، وفق نظام '
                                  'حماية البيانات الشخصية في المملكة العربية '
                                  'السعودية.',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11.5,
                                    height: 1.8,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    ..._sections.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _card(
                            icon: s['icon'] as IconData,
                            title: s['title'] as String,
                            body: s['body'] as String,
                            isDark: isDark,
                          ),
                        )),

                    const SizedBox(height: 12),

                    Center(
                      child: Text(
                        'آخر تحديث: أغسطس 2026',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color:
                              isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
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

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: brandRed, size: 17),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.9,
              color: isDark ? Colors.white70 : const Color(0xFF4A5468),
            ),
          ),
        ],
      ),
    );
  }
}
