import 'package:flutter/material.dart';
import 'about_us_page.dart';
import 'contact_us_page.dart';
import 'faq_page.dart';
import 'privacy_policy_page.dart';
import 'acceptable_use_page.dart';
import 'terms_page.dart';

class UsefulLinksPage extends StatelessWidget {
  const UsefulLinksPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ اكتشاف وضع الثيم الحالي (داكن أم فاتح)
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, dynamic>> links = [
      {
        'title': 'من نحن',
        'icon': Icons.info_outline_rounded,
        'color': Colors.blue,
        'page': const AboutUsPage()
      },
      {
        'title': 'تواصل معنا',
        'icon': Icons.headset_mic_outlined,
        'color': Colors.orange,
        'page': const ContactUsPage()
      },
      {
        'title': 'الأسئلة الشائعة',
        'icon': Icons.quiz_outlined,
        'color': Colors.purple,
        'page': const FaqPage()
      },
      {
        'title': 'الخصوصية',
        'icon': Icons.lock_open_rounded,
        'color': Colors.teal,
        'page': const PrivacyPolicyPage()
      },
      {
        'title': 'الشروط',
        'icon': Icons.gavel_rounded,
        'color': Colors.brown,
        'page': const TermsPage()
      },
      {
        'title': 'الاستخدام',
        'icon': Icons.verified_user_outlined,
        'color': Colors.green,
        'page': const AcceptableUsePage()
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ✅ تحديث لون الخلفية بناءً على الوضع
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            "روابط تهمك",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF2D3436),
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
                height: 1, color: isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "الوصول السريع للمعلومات",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: links.length,
                  itemBuilder: (context, index) {
                    return _buildLinkItem(
                      context,
                      links[index]['title'],
                      links[index]['icon'],
                      links[index]['color'],
                      links[index]['page'],
                      isDark,
                    );
                  },
                ),
              ),
              _buildFooterInfo(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkItem(BuildContext context, String title, IconData icon,
      Color color, Widget page, bool isDark) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8))
              ],
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                width: 1,
              ),
            ),
            child: Icon(icon, size: 26, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF2D3436)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Icon(Icons.security_rounded, color: Colors.green[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "جميع الروابط والسياسات متوافقة مع الأنظمة واللوائح المحلية.",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

