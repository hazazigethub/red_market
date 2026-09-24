import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_profile_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  /// نص البحث — يأتي من الغلاف
  final String searchQuery;

  const AdminUsersScreen({super.key, this.searchQuery = ''});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final supabase = Supabase.instance.client;
  static const Color brandRed = Color(0xFFD32027);

  String get _searchQuery => widget.searchQuery;

  /// عرض قائمة المحظورين داخل نفس الصفحة
  bool _showBanned = false;

  /// كل العملاء على دفعات — يتجاوز حد الألف الافتراضي
  Future<List<Map<String, dynamic>>> _fetchAllCustomers() async {
    final List<Map<String, dynamic>> out = [];
    const int pageSize = 1000;
    int from = 0;
    while (true) {
      final page = await supabase
          .from('profiles')
          .select()
          .eq('role', 'customer')
          .range(from, from + pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(page as List);
      out.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
      if (from > 50000) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchAllCustomers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: brandRed));
                  }

                  final rawData = snapshot.data ?? [];
                  final now = DateTime.now();
                  final fourteenDaysAgo =
                      now.subtract(const Duration(days: 14));

                  // --- منطق فرز البيانات (تم تحسينه للأداء) ---
                  final bannedUsers =
                      rawData.where((u) => u['is_banned'] == true).toList();

                  final activeUsers = rawData.where((u) {
                    if (u['is_banned'] == true) return false;
                    return _checkIfActive(u, fourteenDaysAgo);
                  }).toList();

                  final inactiveUsers = rawData.where((u) {
                    if (u['is_banned'] == true) return false;
                    return !_checkIfActive(u, fourteenDaysAgo);
                  }).toList();

                  final filteredUsers = rawData.where((u) {
                    final name = (u['full_name'] ?? u['name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final phone = (u['phone'] ?? '').toString();
                    return name.contains(_searchQuery.toLowerCase()) ||
                        phone.contains(_searchQuery);
                  }).toList();

                  if (_showBanned) {
                    return _buildBannedList(bannedUsers, fourteenDaysAgo);
                  }

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSummaryCard("إجمالي عملاء المنصة",
                          "${rawData.length}", Colors.purple, Icons.group),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                              child: _buildSmallStatCard(
                                  "نشطون",
                                  "${activeUsers.length}",
                                  Colors.green,
                                  Icons.person)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _buildSmallStatCard(
                                  "غير نشط",
                                  "${inactiveUsers.length}",
                                  Colors.orange,
                                  Icons.person_off_rounded)),
                          const SizedBox(width: 10),

                          // بطاقة المحظورين — تفتح القائمة داخل الصفحة
                          Expanded(
                            child: InkWell(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () => setState(() => _showBanned = true),
                              child: _buildSmallStatCard(
                                  "محظورون",
                                  "${bannedUsers.length}",
                                  Colors.black,
                                  Icons.block),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // نتائج البحث
                      if (_searchQuery.isNotEmpty) ...[
                        const Text("نتائج البحث",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 10),
                        if (filteredUsers.isEmpty)
                          const Center(
                              child: Text("لا توجد نتائج مطابقة",
                                  style: TextStyle(fontFamily: 'Cairo')))
                        else
                          ...filteredUsers
                              .map((user) =>
                                  _buildUserCard(user, fourteenDaysAgo))
                              .toList(),
                      ] else
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Text(
                                "استخدم خانة البحث أعلاه للوصول للعملاء",
                                style: TextStyle(
                                    fontFamily: 'Cairo', color: Colors.grey)),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لفحص حالة النشاط
  bool _checkIfActive(Map<String, dynamic> u, DateTime threshold) {
    if (u['last_sign_in_at'] != null) {
      try {
        final lastSignIn = DateTime.parse(u['last_sign_in_at'].toString());
        return lastSignIn.isAfter(threshold);
      } catch (e) {
        return u['user_status'] == 'active';
      }
    }
    return u['user_status'] == 'active';
  }

  /// قائمة العملاء المحظورين داخل نفس الصفحة — بدل الشاشة السفلية
  Widget _buildBannedList(
      List<Map<String, dynamic>> bannedUsers, DateTime threshold) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _showBanned = false),
              icon: const Icon(Icons.arrow_back_ios_new, size: 15),
              label: const Text(
                'رجوع',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: brandRed),
            ),
            const SizedBox(width: 6),
            const Text(
              'العملاء المحظورون',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${bannedUsers.length}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (bannedUsers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'لا يوجد عملاء محظورون حالياً',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
              ),
            ),
          )
        else
          ...bannedUsers.map((u) => _buildUserCard(u, threshold)),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
          ]),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color)),
          const SizedBox(width: 15),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, DateTime threshold) {
    bool isActive = _checkIfActive(user, threshold);
    bool isBanned = user['is_banned'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerProfileScreen(
              userId: user['id'].toString(),
              userData: user,
            ),
          ),
        ),
        leading: Stack(
          children: [
            CircleAvatar(
                backgroundColor: brandRed.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: brandRed)),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isBanned
                      ? Colors.black
                      : (isActive ? Colors.green : Colors.grey),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(user['full_name'] ?? user['name'] ?? 'بدون اسم',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        subtitle: Text(user['phone'] ?? 'لا يوجد هاتف',
            style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
