import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const CustomerProfileScreen(
      {super.key, required this.userId, required this.userData});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _reasonController = TextEditingController();
  bool _isProcessing = false;
  late bool _isBanned;

  @override
  void initState() {
    super.initState();
    _isBanned = widget.userData['is_banned'] ?? false;
  }

  // --- دالة تحديث حالة الحظر في قاعدة البيانات ---
  Future<void> _updateBanStatus(bool ban, {String? reason}) async {
    setState(() => _isProcessing = true);
    try {
      await supabase.from('profiles').update({
        'is_banned': ban,
        'ban_reason':
            ban ? reason : null, // نفترض وجود عمود ban_reason في جدولك
      }).eq('id', widget.userId);

      if (!mounted) return;
      setState(() => _isBanned = ban);

      Navigator.pop(context); // إغلاق الدايالوج
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ban ? "تم حظر العميل" : "تم فك الحظر"),
            backgroundColor: ban ? Colors.black : Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("حدث خطأ أثناء التحديث"),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- نافذة إدخال سبب الحظر ---
  void _showBanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حظر العميل", style: TextStyle(fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("الرجاء كتابة سبب الحظر ليظهر للعميل:"),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "مثلاً: مخالفة شروط الاستخدام...",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () =>
                _updateBanStatus(true, reason: _reasonController.text),
            child: const Text("تأكيد الحظر",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title:
              const Text("إدارة الحساب", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: const Color(0xFFD32027),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // كرت معلومات العميل
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade200,
                      child: const Icon(Icons.person,
                          size: 50, color: Color(0xFFD32027)),
                    ),
                    const SizedBox(height: 10),
                    Text(widget.userData['full_name'] ?? 'بدون اسم',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                    Text(widget.userData['phone'] ?? '',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              const Text("الإجراءات الإدارية",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Cairo')),
              const Divider(),

              if (_isBanned) ...[
                // إذا كان محظوراً نُظهر سبب الحظر وزر فك الحظر
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text("هذا الحساب محظور حالياً.",
                            style: TextStyle(
                                color: Colors.red.shade900,
                                fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  title: "فك حظر الحساب",
                  icon: Icons.refresh,
                  color: Colors.green,
                  onPressed: () => _updateBanStatus(false),
                ),
              ] else ...[
                // إذا كان نشطاً نُظهر زر الحظر
                _buildActionButton(
                  title: "حظر العميل",
                  icon: Icons.block,
                  color: Colors.black,
                  onPressed: _showBanDialog,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _isProcessing ? null : onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
