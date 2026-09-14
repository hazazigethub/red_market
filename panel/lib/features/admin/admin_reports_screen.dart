import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_merchants_screen.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  final Color brandRed = const Color(0xFFD32027);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('البلاغات والدعم',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'اختر القسم لمراجعة الوارد واتخاذ إجراء مباشر',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade500),
                  ),

                  const SizedBox(height: 22),

                  LayoutBuilder(
                    builder: (context, c) {
                      const gap = 12.0;
                      final cols = c.maxWidth < 620 ? 1 : 3;
                      final w = (c.maxWidth - gap * (cols - 1)) / cols;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: w,
                            child: _buildNavigationCard(
                              context,
                              "بلاغات المتاجر",
                              Icons.storefront_outlined,
                              Colors.indigo,
                              'merchant',
                              'reports',
                            ),
                          ),
                          SizedBox(
                            width: w,
                            child: _buildNavigationCard(
                              context,
                              "خدمة العملاء",
                              Icons.support_agent,
                              Colors.green,
                              'user_support',
                              'reports',
                            ),
                          ),
                          SizedBox(
                            width: w,
                            child: _buildNavigationCard(
                              context,
                              "دعم المتاجر",
                              Icons.contact_support_outlined,
                              Colors.teal,
                              'merchant_support',
                              'reports',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationCard(BuildContext context, String title, IconData icon,
      Color color, String filterValue, String tableName) {
    final supabase = Supabase.instance.client;
    final String filterColumn = 'target_type';
    const Color brandRed = Color(0xFFD32027);

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportsDetailsPage(
                filterValue: filterValue,
                title: title,
                tableName: tableName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.1),
                    radius: 30,
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              Positioned(
                top: -15,
                right: -5,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: supabase
                      .from(tableName)
                      .stream(primaryKey: ['id']).map((items) => items
                          .where((item) =>
                              item[filterColumn] == filterValue &&
                              item['status'] == 'pending')
                          .toList()),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      child: Center(
                        child: Text(
                          '${snapshot.data!.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class ReportsDetailsPage extends StatelessWidget {
  /// يفتح شاشة إدارة التاجر المُبلَّغ عنه بعد جلب بياناته
  Future<void> _openMerchant(BuildContext context, dynamic merchantId) async {
    if (merchantId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final data = await Supabase.instance.client
          .from('merchants')
          .select()
          .eq('id', merchantId.toString())
          .maybeSingle();
      if (data == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text('لم يُعثر على بيانات المتجر')));
        return;
      }
      navigator.push(MaterialPageRoute(
          builder: (_) => MerchantControlScreen(merchant: data)));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('تعذر فتح المتجر: ' + e.toString())));
    }
  }

  final String filterValue;
  final String title;
  final String tableName;

  /// عند التضمين داخل غلاف: بلا ترويسة
  final bool embedded;

  const ReportsDetailsPage({
    super.key,
    required this.filterValue,
    required this.title,
    required this.tableName,
    this.embedded = false,
  });

  void _showAdvancedBanDialog(BuildContext context, Map<String, dynamic> item) {
    String selectedReason = 'محتوى مخالف';
    int selectedDays = 3;
    bool isPermanent = false;
    final supabase = Supabase.instance.client;
    const Color brandRed = Color(0xFFD32027);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: brandRed,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: const Text("إجراء حظر متقدم",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("سبب الحظر:",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedReason,
                    icon: const Icon(Icons.arrow_drop_down, color: brandRed),
                    items: [
                      'محتوى مخالف',
                      'احتيال',
                      'سوء سلوك',
                      'بلاغات متكررة'
                    ]
                        .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: const TextStyle(
                                    fontFamily: 'Cairo', fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => selectedReason = v!),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("حظر دائم نهائي",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                value: isPermanent,
                onChanged: (v) => setState(() => isPermanent = v!),
                activeColor: brandRed,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (!isPermanent) ...[
                const Divider(),
                const Text("مدة الحظر المؤقت:",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedDays,
                      icon: const Icon(Icons.timer_outlined, color: brandRed),
                      items: [3, 7, 30, 90]
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text("$e يوم",
                                  style: const TextStyle(
                                      fontFamily: 'Cairo', fontSize: 14))))
                          .toList(),
                      onChanged: (v) => setState(() => selectedDays = v!),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("إلغاء",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: Colors.black54))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      final banUntil = isPermanent
                          ? null
                          : DateTime.now()
                              .add(Duration(days: selectedDays))
                              .toIso8601String();

                      await supabase.from('profiles').update({
                        'is_banned': true,
                        'ban_reason': selectedReason,
                        'ban_until': banUntil,
                      }).eq('id', item['target_id']);

                      await supabase
                          .from(tableName)
                          .update({'status': 'resolved'}).eq('id', item['id']);

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("تم تنفيذ إجراء الحظر بنجاح",
                              style: TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: Colors.green));
                    },
                    child: const Text("تأكيد الإجراء",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    const Color brandRed = Color(0xFFD32027);
    final String filterColumn = 'target_type';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: embedded
            ? null
            : AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                foregroundColor: const Color(0xFF1F2937),
                title: Text(title,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1F2937))),
              ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from(tableName)
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: false)
              .map((items) => items
                  .where((item) =>
                      item[filterColumn] == filterValue &&
                      item['status'] == 'pending')
                  .toList()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: brandRed));
            }
            final data = snapshot.data ?? [];
            if (data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 58, color: Colors.grey.shade300),
                    const SizedBox(height: 14),
                    const Text("لا توجد بلاغات قيد المراجعة حالياً",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            color: Colors.grey)),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 320,
              ),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final String content =
                    item['reason'] ?? 'لا توجد تفاصيل إضافية';
                final String storeDisplayName =
                    item['target_name'] ?? "غير معروف";

                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFEDEFF3)),
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(
                              Icons.pending_actions,
                              color: Colors.orange,
                              size: 18,
                            ),
                            Text(
                              item['created_at'].toString().substring(0, 10),
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(storeDisplayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: Colors.redAccent,
                                    elevation: 0,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon:
                                      const Icon(Icons.info_outline, size: 16),
                                  label: const Text("سبب البلاغ",
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        surfaceTintColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        titlePadding: EdgeInsets.zero,
                                        title: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: const BoxDecoration(
                                            color: brandRed,
                                            borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(20),
                                                topRight: Radius.circular(20)),
                                          ),
                                          child: const Text("تفاصيل البلاغ",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18)),
                                        ),
                                        content: SingleChildScrollView(
                                          child: Text(content,
                                              style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 14,
                                                  color: Colors.black87)),
                                        ),
                                        actions: [
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: brandRed,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10))),
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text("إغلاق",
                                                  style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      color: Colors.white)),
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Colors.indigo, width: 1.2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                  ),
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 18, color: Colors.indigo),
                                  label: const Text("معاينة المتجر",
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo)),
                                  onPressed: () {
                                    _openMerchant(
                                        context, item['target_id']);
                                  },
                                ),
                              ),
                              const SizedBox(height: 10),
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: _buildActionBtn(
                                        "تجاهل", Colors.blueGrey, () {
                                      _showIgnoreConfirmation(
                                          context, item, tableName);
                                    }),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _buildActionBtn("حظر", brandRed, () {
                                      _showAdvancedBanDialog(context, item);
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showIgnoreConfirmation(
      BuildContext context, Map<String, dynamic> item, String tableName) {
    final supabase = Supabase.instance.client;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("تأكيد التجاهل",
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            "هل أنت متأكد من رغبتك في حذف هذا البلاغ نهائياً؟ لا يمكن التراجع عن هذا الإجراء.",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await supabase.from(tableName).delete().eq('id', item['id']);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("تم حذف البلاغ بنجاح",
                        style: TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: Colors.blueGrey,
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("حدث خطأ أثناء محاولة الحذف"),
                  ));
                }
              }
            },
            child: const Text("تأكيد الحذف",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(label,
          style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold)),
    );
  }
}
