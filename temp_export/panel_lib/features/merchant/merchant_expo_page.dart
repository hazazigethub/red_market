import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:red_market_core/red_market_core.dart';

// =====================================================================
// المعارض في لوحة التاجر: بنر أقرب معرض + قسم «المعارض»
// يفتح موقع المعارض بدخول تلقائي (جلسة منفصلة، لا تؤثر على جلسة اللوحة)
// =====================================================================

/// أقرب معرض مفتوح للمشاركة (null = لا يوجد، أو بدأ، أو اكتمل، أو أُغلقت المشاركة)
Future<Map<String, dynamic>?> loadExpoBanner() async {
  try {
    final res =
        await Supabase.instance.client.schema('expo').rpc('merchant_expo_banner');
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  } catch (e) {
    debugPrint('Expo banner error: $e');
    return null;
  }
}

/// يفتح موقع المعارض على الصفحة المطلوبة، مسجّل الدخول تلقائياً
Future<void> openExpo(BuildContext context, String next) async {
  try {
    final res = await Supabase.instance.client.functions
        .invoke('expo-handoff', body: {'next': next});
    final url = (res.data is Map) ? (res.data as Map)['url'] as String? : null;
    if (url == null) throw 'no url';
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  } catch (e) {
    debugPrint('Expo handoff error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذر فتح موقع المعارض، حاول مرة أخرى'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

/// بنر المعارض — بنفس تصميم بنر الحملة الموسمية
class ExpoMerchantBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  const ExpoMerchantBanner({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final daysLeft = (data['days_left'] as num?)?.toInt() ?? 0;
    final remaining = (data['remaining'] as num?)?.toInt();
    final joined = data['joined'] == true;
    final next = joined ? '/merchant/booths/${data['booth_id']}/edit' : '/merchant';

    return InkWell(
      onTap: () => openExpo(context, next),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD32027), Color(0xFF8E1010)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32027).withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (data['title'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysLeft > 1 ? 'باقٍ $daysLeft يوم' : 'يبدأ قريباً',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              joined
                  ? 'أنت مشارك في المعرض — جهّز جناحك قبل الافتتاح'
                  : 'شارك بجناحك في المعرض أمام كل زوّار المنصة',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.9,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.storefront_outlined,
                    size: 15, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 7),
                Text(
                  remaining == null ? 'الأجنحة متاحة' : 'متبقٍ $remaining جناح',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        joined ? 'جناحي' : 'شارك الآن',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD32027),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.chevron_left_rounded,
                          size: 17, color: Color(0xFFD32027)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// قسم «المعارض» في قائمة التاجر
class MerchantExpoPage extends StatefulWidget {
  const MerchantExpoPage({super.key});

  @override
  State<MerchantExpoPage> createState() => _MerchantExpoPageState();
}

class _MerchantExpoPageState extends State<MerchantExpoPage> {
  late final Future<Map<String, dynamic>?> _banner = loadExpoBanner();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: _banner,
                builder: (context, snap) {
                  if (snap.data == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: ExpoMerchantBanner(data: snap.data!),
                  );
                },
              ),
              Text(
                'معارض Red Market',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'شارك بجناحك في المعارض، وابنِ جناحك، وتابع عملاءك من لوحة العارض',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => openExpo(context, '/merchant'),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('فتح لوحة العارض',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32027),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
