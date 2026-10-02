import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/routing/route_paths.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  static const Color brandRed = Color(0xFFD32027);
  static const Color oceanBlue = Color(0xFF2196F3);
  static const Color amberGold = Color(0xFFFFC107);
  static const Color purpleDeep = Color(0xFF673AB7);
  static const Color tealOcean = Color(0xFF009688);

  void _showLanguagePicker(BuildContext context, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                const Text("اختر اللغة",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo')),
                const SizedBox(height: 20),
                _buildLanguageOption(
                    context, "العربية", "ar", true, primaryColor),
                _buildLanguageOption(
                    context, "English", "en", false, primaryColor),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String title, String code,
      bool isSelected, Color primaryColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(title,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? primaryColor : Colors.black87)),
      trailing:
          isSelected ? Icon(Icons.check_circle, color: primaryColor) : null,
      onTap: () => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color primaryAppColor = Theme.of(context).colorScheme.primary;

    final user = Supabase.instance.client.auth.currentUser;
    final String userName = user?.userMetadata?['full_name'] ?? "مستخدم جديد";
    final String? userImageUrl = user?.userMetadata?['avatar_url'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: const Text(
              "إعدادات الحساب",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: RefreshIndicator(
          color: brandRed,
          onRefresh: () async {
            await Supabase.instance.client.auth.refreshSession();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(
                    context, primaryAppColor, userName, userImageUrl),
                const SizedBox(height: 32),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _buildSquareTile(Icons.person_outline, "المعلومات",
                        oceanBlue, () => context.push(RoutePaths.personalInfo)),

                    _buildSquareTile(Icons.favorite_border, "الاهتمامات",
                        brandRed, () => context.push(RoutePaths.interests)),

                    _buildSquareTile(Icons.help_outline, "الأسئلة الشائعة",
                        brandRed, () => context.push(RoutePaths.faq)),
                    _buildSquareTile(
                        Icons.headset_mic_outlined,
                        "الدعم الفني",
                        amberGold,
                        () => context.push(RoutePaths.customerService)),
                    _buildSquareTile(Icons.language, "اللغة", tealOcean,
                        () => _showLanguagePicker(context, primaryAppColor)),
                    _buildSquareTile(
                        Icons.privacy_tip_outlined,
                        "الخصوصية",
                        purpleDeep,
                        () => context.push(RoutePaths.privacyPolicy)),
                    _buildSquareTile(
                        Icons.gavel_outlined, "الشروط", Colors.blueGrey, () {
                      context.push(RoutePaths.customerTerms);
                    }),
                    // تم نقل خانة حذف الحساب هنا لتكون متوافقة مع التصميم
                    _buildSquareTile(
                        Icons.delete_forever_outlined,
                        "حذف الحساب",
                        Colors.red.shade600,
                        () => context.push(RoutePaths.deleteAccount)),
                  ],
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSquareTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, Color primaryColor, String name, String? imageUrl) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final String? avatarUrl = user?.userMetadata?['avatar_url'] ?? imageUrl;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: primaryColor.withValues(alpha: 0.2), width: 4)),
          child: CircleAvatar(
            radius: 55,
            backgroundColor: const Color(0xFFF5F5F5),
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Icon(Icons.person, size: 50, color: primaryColor)
                : null,
          ),
        ),
        const SizedBox(height: 18),
        Text(name,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'Cairo',
                color: Colors.black)),
      ],
    );
  }
}
