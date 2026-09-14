import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final supabase = Supabase.instance.client;
  static const Color brandRed = Color(0xFFD32027);

  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> announcements =
          List<Map<String, dynamic>>.from(data);

      for (final ann in announcements) {
        try {
          final views = await supabase
              .from('announcement_views')
              .select('user_id, profiles!inner(role)')
              .eq('announcement_id', ann['id']);

          int customerViews = 0;
          int merchantViews = 0;
          for (final v in (views as List)) {
            final role = v['profiles']?['role']?.toString() ?? '';
            if (role == 'customer') customerViews++;
            if (role == 'merchant') merchantViews++;
          }
          ann['customer_views'] = customerViews;
          ann['merchant_views'] = merchantViews;
        } catch (_) {
          ann['customer_views'] = 0;
          ann['merchant_views'] = 0;
        }
      }

      if (mounted) {
        setState(() {
          _announcements = announcements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> ann) async {
    await supabase
        .from('announcements')
        .update({'is_active': !(ann['is_active'] ?? true)}).eq('id', ann['id']);
    _fetchAnnouncements();
  }

  Future<void> _deleteAnnouncement(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("حذف الإعلان",
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text("هل أنت متأكد من حذف هذا الإعلان؟",
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("حذف",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await supabase.from('announcements').delete().eq('id', id);
      _fetchAnnouncements();
    }
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String targetRole = 'all';
    int maxViews = 1;
    Uint8List? imageBytes;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("إضافة إعلان جديد",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 80);
                    if (img != null) {
                      final bytes = await img.readAsBytes();
                      setModal(() => imageBytes = bytes);
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(imageBytes!, fit: BoxFit.cover))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 40, color: Colors.grey[400]),
                              const Text("أضف صورة (اختياري)",
                                  style: TextStyle(
                                      fontFamily: 'Cairo', color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: _inputDec("عنوان الإعلان", Icons.title),
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  maxLines: 3,
                  decoration: _inputDec("نص الرسالة", Icons.message_outlined),
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: targetRole,
                  decoration:
                      _inputDec("الفئة المستهدفة", Icons.people_outline),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("الكل")),
                    DropdownMenuItem(
                        value: 'customer', child: Text("العملاء فقط")),
                    DropdownMenuItem(
                        value: 'merchant', child: Text("التجار فقط")),
                  ],
                  onChanged: (val) => setModal(() => targetRole = val ?? 'all'),
                  style:
                      const TextStyle(fontFamily: 'Cairo', color: Colors.black),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text("عدد مرات الظهور:",
                        style: TextStyle(fontFamily: 'Cairo')),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => setModal(
                          () => maxViews = (maxViews - 1).clamp(1, 99)),
                      icon: const Icon(Icons.remove_circle_outline,
                          color: brandRed),
                    ),
                    Text("$maxViews",
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    IconButton(
                      onPressed: () => setModal(
                          () => maxViews = (maxViews + 1).clamp(1, 99)),
                      icon:
                          const Icon(Icons.add_circle_outline, color: brandRed),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandRed,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isUploading
                        ? null
                        : () async {
                            if (!ctx.mounted) return;
                            setModal(() => isUploading = true);
                            try {
                              String? imageUrl;
                              if (imageBytes != null) {
                                final fileName =
                                    'ann_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                await supabase.storage
                                    .from('announcements')
                                    .uploadBinary(
                                        fileName, imageBytes!,
                                        fileOptions: const FileOptions(
                                            contentType: 'image/jpeg'));
                                imageUrl = supabase.storage
                                    .from('announcements')
                                    .getPublicUrl(fileName);
                              }
                              await supabase.from('announcements').insert({
                                'title': titleCtrl.text.trim(),
                                'message': messageCtrl.text.trim(),
                                'image_url': imageUrl,
                                'target_role': targetRole,
                                'max_views': maxViews,
                                'is_active': true,
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _fetchAnnouncements();
                            } catch (e) {
                              if (ctx.mounted)
                                setModal(() => isUploading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("خطأ: $e")),
                              );
                            }
                          },
                    child: isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("نشر الإعلان",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            color: Colors.grey.shade400),
        prefixIcon: Icon(icon, size: 19, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFEDEFF3))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFEDEFF3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: brandRed, width: 1.4)),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          backgroundColor: brandRed,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("إعلان جديد",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : _announcements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 58, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text("لا توجد إعلانات بعد",
                            style: TextStyle(
                                fontFamily: 'Cairo', color: Colors.grey)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _fetchAnnouncements(),
                    color: brandRed,
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 330,
                      ),
                      itemCount: _announcements.length,
                      itemBuilder: (context, index) {
                        final ann = _announcements[index];
                        final bool isActive = ann['is_active'] ?? true;
                        final int customerViews = ann['customer_views'] ?? 0;
                        final int merchantViews = ann['merchant_views'] ?? 0;

                        return Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isActive
                                  ? brandRed.withValues(alpha: 0.35)
                                  : const Color(0xFFEDEFF3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ✅ صورة الإعلان
                                if (ann['image_url'] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      ann['image_url'],
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                if (ann['image_url'] != null)
                                  const SizedBox(height: 10),

                                // ✅ العنوان + إحصائيات + سويتش
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ann['title'] ?? '',
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                    ),
                                    _buildChip(
                                        "عملاء: $customerViews", Colors.green),
                                    const SizedBox(width: 4),
                                    _buildChip(
                                        "تجار: $merchantViews", Colors.purple),
                                    Switch(
                                      value: isActive,
                                      activeColor: brandRed,
                                      onChanged: (_) => _toggleActive(ann),
                                    ),
                                  ],
                                ),

                                // ✅ نص الرسالة
                                if ((ann['message'] ?? '').isNotEmpty)
                                  Text(ann['message'],
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          color: Colors.grey,
                                          fontSize: 13)),
                                const SizedBox(height: 8),

                                // ✅ الشرائح + زر الحذف
                                Row(
                                  children: [
                                    _buildChip(
                                        ann['target_role'] == 'all'
                                            ? 'الكل'
                                            : ann['target_role'] == 'customer'
                                                ? 'العملاء'
                                                : 'التجار',
                                        Colors.blue),
                                    const SizedBox(width: 8),
                                    _buildChip("يظهر ${ann['max_views']} مرة",
                                        Colors.orange),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      onPressed: () =>
                                          _deleteAnnouncement(ann['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: color)),
      );
}
