import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// يجلب كل الصفوف على دفعات — يتجاوز حد الألف الافتراضي في Supabase
Future<List<dynamic>> fetchAllRows(
  String table, {
  String columns = '*',
  void Function(dynamic q)? unused,
}) async {
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

class AdminAnalyticsUsersScreen extends StatelessWidget {
  const AdminAnalyticsUsersScreen({super.key});

  /// كل العملاء على دفعات
  Future<List<dynamic>> _fetchAllCustomers() async {
    final supabase = Supabase.instance.client;
    final List<dynamic> out = [];
    const int pageSize = 1000;
    int from = 0;
    while (true) {
      final page = await supabase
          .from('profiles')
          .select()
          .eq('role', 'customer')
          .range(from, from + pageSize - 1);
      final rows = page as List;
      out.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
      if (from > 50000) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
                body: FutureBuilder(
          future: Future.wait([
            _fetchAllCustomers(),
            fetchAllRows('analytics_visits', columns: 'id'),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: brandRed));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text("خطأ في جلب البيانات: ${snapshot.error}"));
            }

            final List users = snapshot.data![0] as List;
            final List visits = snapshot.data![1] as List;
            final now = DateTime.now();

            int newUsers24h = users.where((u) {
              final createdAt = DateTime.parse(u['created_at']);
              return now.difference(createdAt).inHours <= 24;
            }).length;

            int newUsers7d = users.where((u) {
              final createdAt = DateTime.parse(u['created_at']);
              return now.difference(createdAt).inDays <= 7;
            }).length;

            int activeUsers = 0;
            int inactiveUsers = 0;
            int dormantUsers = 0;

            for (var u in users) {
              if (u['last_sign_in_at'] == null) {
                dormantUsers++;
                continue;
              }
              final lastSeen = DateTime.parse(u['last_sign_in_at']);
              final difference = now.difference(lastSeen).inDays;
              if (difference < 7) {
                activeUsers++;
              } else if (difference <= 30) {
                inactiveUsers++;
              } else {
                dormantUsers++;
              }
            }

            int males = users.where((u) => u['gender'] == 'male').length;
            int females = users.where((u) => u['gender'] == 'female').length;
            double avgStoreVisits =
                visits.isEmpty ? 0 : visits.length / users.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderStat("إجمالي عملاء المنصة", "${users.length}",
                      Colors.green, Icons.people_alt),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildSmallStatCard(
                          context, "جدد (24س)", "$newUsers24h", Colors.blue),
                      const SizedBox(width: 10),
                      _buildSmallStatCard(context, "جدد (7أيام)", "$newUsers7d",
                          Colors.blue.shade800),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text("حالة نشاط العملاء",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildAnalysisRow(context, "عملاء نشطون (< 7 أيام)",
                      "$activeUsers", Colors.green),
                  _buildAnalysisRow(context, "غير نشطين (7 - 30 يوم)",
                      "$inactiveUsers", Colors.orange),
                  _buildAnalysisRow(context, "عملاء خاملون (> 30 يوم)",
                      "$dormantUsers", Colors.red),
                  const SizedBox(height: 25),
                  const Text("التوزيع النوعي",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildGenderCard(
                          context, "ذكور", "$males", Icons.male, Colors.blue),
                      const SizedBox(width: 10),
                      _buildGenderCard(context, "إناث", "$females",
                          Icons.female, Colors.pink),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text("تحليل السلوك وتفاعل المنصة",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildAnalysisRow(context, "متوسط زيارة المتاجر للعميل",
                      avgStoreVisits.toStringAsFixed(1), Colors.purple),
                  _buildAnalysisRow(
                      context, "متوسط وقت التصفح", "4.2 دقيقة", Colors.teal),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderStat(
      String title, String value, Color iconColor, IconData icon) {
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
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }

  // ✅ أضف context
  Widget _buildSmallStatCard(
      BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ✅ أضف context
  Widget _buildGenderCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text("$label: ", style: const TextStyle(fontFamily: 'Cairo')),
            Text(value,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ✅ أضف context
  Widget _buildAnalysisRow(
      BuildContext context, String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor)),
      child: Row(
        children: [
          Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 15),
          Text(title, style: const TextStyle(fontFamily: 'Cairo')),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
