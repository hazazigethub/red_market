import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// يجلب كل الصفوف على دفعات — يتجاوز حد الألف الافتراضي في Supabase
Future<List<dynamic>> fetchAllRows(String table, {String columns = '*'}) async {
  final supabase = Supabase.instance.client;
  final List<dynamic> out = [];
  const int pageSize = 1000;
  int from = 0;

  while (true) {
    final page = await supabase
        .from(table)
        .select(columns)
        .range(from, from + pageSize - 1);
    final rows = page as List;
    out.addAll(rows);
    if (rows.length < pageSize) break;
    from += pageSize;
    if (from > 50000) break;
  }
  return out;
}

class AdminAnalyticsMerchantsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsMerchantsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsMerchantsScreen> createState() =>
      _AdminAnalyticsMerchantsScreenState();
}

class _AdminAnalyticsMerchantsScreenState
    extends ConsumerState<AdminAnalyticsMerchantsScreen> {
  int _topMerchantCount = 5;
  final TextEditingController _countController =
      TextEditingController(text: '5');

  Future<Map<String, dynamic>> _fetchMerchantsStats() async {
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

    final List merchants = await fetchAllRows('merchants',
        columns:
            'id, store_name, logo_url, store_category_id, created_at, is_subscription_active');

    int totalMerchants = merchants.length;

    int newlyJoined = merchants.where((m) {
      final raw = m['created_at'];
      if (raw == null) return false;
      return DateTime.parse(raw).isAfter(twentyFourHoursAgo);
    }).length;

    int activeSub =
        merchants.where((m) => m['is_subscription_active'] == true).length;
    int inactiveSub = totalMerchants - activeSub;
    final plansRes =
        await supabase.from('subscription_plans').select('id, name');

    final merchantProfiles = await supabase
        .from('profiles')
        .select('plan_id, package_name')
        .eq('role', 'merchant')
        .not('plan_id', 'is', null);

    final Map<String, int> planCounts = {};
    final Map<String, String> planNames = {};
    for (var p in plansRes as List) {
      planNames[p['id'].toString()] = p['name'].toString();
    }
    for (var p in merchantProfiles as List) {
      final planId = p['plan_id'].toString();
      final planName = planNames[planId] ?? p['package_name'] ?? 'غير محدد';
      planCounts[planName] = (planCounts[planName] ?? 0) + 1;
    }

    final List visitsRes =
        await fetchAllRows('analytics_visits', columns: 'merchant_id');

    final Map<String, int> visitCounts = {};
    for (var v in visitsRes) {
      if (v['merchant_id'] == null) continue;
      final id = v['merchant_id'].toString();
      visitCounts[id] = (visitCounts[id] ?? 0) + 1;
    }

    var topVisited = List.from(merchants);
    for (var m in topVisited) {
      (m as Map)['visit_count'] = visitCounts[m['id'].toString()] ?? 0;
    }
    topVisited.sort(
        (a, b) => (b['visit_count'] ?? 0).compareTo(a['visit_count'] ?? 0));

    var topRated = List.from(merchants);
    topRated.sort((a, b) =>
        (b['average_rating'] ?? 0.0).compareTo(a['average_rating'] ?? 0.0));

    return {
      'total': totalMerchants,
      'newlyJoined': newlyJoined,
      'activeSub': activeSub,
      'inactiveSub': inactiveSub,
      'topVisited': topVisited.take(_topMerchantCount).toList(),
      'topRated': topRated.take(5).toList(),
      'planCounts': planCounts,
    };
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
                body: FutureBuilder<Map<String, dynamic>>(
          future: _fetchMerchantsStats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: brandRed));
            }
            if (snapshot.hasError) {
              debugPrint("Error: ${snapshot.error}");
              return Center(child: Text("خطأ: ${snapshot.error}"));
            }
            if (!snapshot.hasData)
              return const Center(child: Text("لا توجد بيانات متاجر"));

            final s = snapshot.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderStat(context, "إجمالي تجار المنصة",
                      "${s['total']}", Colors.purple, Icons.storefront),
                  const SizedBox(height: 20),
                  const Text("تحليل حالة المتاجر",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildStatusGrid(context, s),
                  const SizedBox(height: 30),
                  const Text("المتاجر حسب الباقة",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 10),
                  ...(s['planCounts'] as Map<String, int>)
                      .entries
                      .map((e) => _buildActivityTile(context, e.key, e.value))
                      .toList(),
                  const SizedBox(height: 30),
                  _buildDynamicHeader("المتاجر الأكثر زيارة", _countController,
                      (val) {
                    setState(() => _topMerchantCount = int.tryParse(val) ?? 5);
                  }),
                  const SizedBox(height: 10),
                  ...s['topVisited']
                      .map((m) => _buildMerchantRankRow(
                          context, m, Icons.visibility, Colors.blue))
                      .toList(),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ أضف context
  Widget _buildHeaderStat(BuildContext context, String title, String value,
      Color iconColor, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 45),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: iconColor,
                letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  // ✅ أضف context
  Widget _buildStatusGrid(BuildContext context, Map<String, dynamic> s) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildStatusBox(
            context, "جدد (24س)", "${s['newlyJoined']}", Colors.blue),
        _buildStatusBox(context, "فعالة", "${s['activeSub']}", Colors.green),
        _buildStatusBox(
            context, "غير فعالة", "${s['inactiveSub']}", Colors.red),
      ],
    );
  }

  // ✅ أضف context واستبدل Colors.white
  Widget _buildStatusBox(
      BuildContext context, String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  // ✅ أضف context واستبدل Colors.white
  Widget _buildActivityTile(BuildContext context, String name, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
            child: const Icon(Icons.business_center,
                color: Colors.blueGrey, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 5),
          Text("$count متجر",
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDynamicHeader(
      String title, TextEditingController controller, Function(String) onSub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        SizedBox(
          width: 80,
          height: 35,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
                hintText: "العدد",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.zero),
            onSubmitted: onSub,
          ),
        ),
      ],
    );
  }

  // ✅ أضف context واستبدل Colors.white
  Widget _buildMerchantRankRow(
      BuildContext context, dynamic m, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            backgroundImage:
                m['logo_url'] != null ? NetworkImage(m['logo_url']) : null,
            child: m['logo_url'] == null
                ? const Icon(Icons.store, size: 20)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['store_name'] ?? 'متجر غير معروف',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(m['store_category_id']?.toString() ?? 'غير محدد',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text("${m['visit_count'] ?? 0}",
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
