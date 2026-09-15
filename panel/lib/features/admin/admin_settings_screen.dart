import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final supabase = Supabase.instance.client;

  final TextEditingController _maintenanceMessageController =
      TextEditingController();

  // بيانات التواصل — تظهر في تذييل الموقع، والفارغ منها لا يُعرض
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _urlX = TextEditingController();
  final _urlInstagram = TextEditingController();
  final _urlTiktok = TextEditingController();
  final _urlSnapchat = TextEditingController();

  bool _isMaintenanceMode = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _maintenanceMessageController.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _urlX.dispose();
    _urlInstagram.dispose();
    _urlTiktok.dispose();
    _urlSnapchat.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data =
          await supabase.from('system_settings').select().maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _isMaintenanceMode = data['is_maintenance'] ?? false;
          _maintenanceMessageController.text =
              data['maintenance_message'] ?? '';
          _whatsapp.text = data['whatsapp_number'] ?? '';
          _email.text = data['contact_email'] ?? '';
          _urlX.text = data['url_x'] ?? '';
          _urlInstagram.text = data['url_instagram'] ?? '';
          _urlTiktok.text = data['url_tiktok'] ?? '';
          _urlSnapchat.text = data['url_snapchat'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// الفارغ يُحفظ كـ null — فالتذييل يخفي ما كان فارغاً
  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await supabase.from('system_settings').upsert({
        'id': 1,
        'is_maintenance': _isMaintenanceMode,
        'maintenance_message': _maintenanceMessageController.text.trim(),
        'whatsapp_number': _clean(_whatsapp),
        'contact_email': _clean(_email),
        'url_x': _clean(_urlX),
        'url_instagram': _clean(_urlInstagram),
        'url_tiktok': _clean(_urlTiktok),
        'url_snapchat': _clean(_urlSnapchat),
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ الإعدادات بنجاح'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error saving settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذر الحفظ: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
                body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("حالة النظام"),
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: SwitchListTile(
                        title: const Text("وضع الصيانة",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold)),
                        subtitle: const Text(
                            "عند التفعيل، سيظهر للمستخدمين رسالة الصيانة",
                            style:
                                TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                        value: _isMaintenanceMode,
                        activeColor: brandRed,
                        onChanged: (val) =>
                            setState(() => _isMaintenanceMode = val),
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildSectionTitle("رسالة الصيانة"),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _maintenanceMessageController,
                      maxLines: 4,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: _buildInputDecoration(
                          "اكتب الرسالة التي ستظهر للمستخدمين أثناء الصيانة..."),
                    ),
                    const SizedBox(height: 30),
                    _buildSectionTitle("بيانات التواصل"),
                    const SizedBox(height: 4),
                    Text(
                      "تظهر في تذييل الموقع — والحقل الفارغ لا يُعرض للزوار",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),

                    _buildField(
                      controller: _whatsapp,
                      label: "رقم الواتساب",
                      hint: "966501234567",
                      icon: Icons.chat_outlined,
                      ltr: true,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: _email,
                      label: "بريد التواصل",
                      hint: "info@redmarket.pro",
                      icon: Icons.mail_outline,
                      ltr: true,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 26),

                    _buildSectionTitle("حسابات التواصل الاجتماعي"),
                    const SizedBox(height: 14),

                    _buildField(
                      controller: _urlX,
                      label: "إكس",
                      hint: "https://x.com/username",
                      icon: Icons.alternate_email,
                      ltr: true,
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: _urlInstagram,
                      label: "انستغرام",
                      hint: "https://www.instagram.com/username/",
                      icon: Icons.camera_alt_outlined,
                      ltr: true,
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: _urlTiktok,
                      label: "تيك توك",
                      hint: "https://www.tiktok.com/@username",
                      icon: Icons.music_note_outlined,
                      ltr: true,
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: _urlSnapchat,
                      label: "سناب شات",
                      hint: "https://www.snapchat.com/add/username",
                      icon: Icons.bolt_outlined,
                      ltr: true,
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Colors.white))
                            : const Text("حفظ الإعدادات",
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool ltr = false,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          textDirection: ltr ? TextDirection.ltr : null,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          decoration: _buildInputDecoration(hint),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32027))),
    );
  }
}
