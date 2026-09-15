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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : LayoutBuilder(
                builder: (context, c) {
                  // عمودان على الشاشات الواسعة، وعمود واحد على الضيقة
                  final wide = c.maxWidth >= 860;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _pageHeader(),
                            const SizedBox(height: 20),

                            _maintenanceCard(),
                            const SizedBox(height: 16),

                            _card(
                              icon: Icons.contact_support_outlined,
                              title: 'بيانات التواصل',
                              subtitle:
                                  'تظهر في تذييل الموقع — والحقل الفارغ لا يُعرض للزوار',
                              child: _grid(wide, [
                                _field(
                                  controller: _whatsapp,
                                  label: 'رقم الواتساب',
                                  hint: '966501234567',
                                  icon: Icons.chat_outlined,
                                  keyboard: TextInputType.phone,
                                ),
                                _field(
                                  controller: _email,
                                  label: 'بريد التواصل',
                                  hint: 'info@redmarket.pro',
                                  icon: Icons.mail_outline_rounded,
                                  keyboard: TextInputType.emailAddress,
                                ),
                              ]),
                            ),
                            const SizedBox(height: 16),

                            _card(
                              icon: Icons.share_outlined,
                              title: 'حسابات التواصل الاجتماعي',
                              subtitle:
                                  'ضع الرابط كاملاً — والحساب الفارغ تُخفى أيقونته',
                              child: _grid(wide, [
                                _field(
                                  controller: _urlX,
                                  label: 'إكس',
                                  hint: 'https://x.com/username',
                                  icon: Icons.alternate_email_rounded,
                                ),
                                _field(
                                  controller: _urlInstagram,
                                  label: 'انستغرام',
                                  hint: 'https://www.instagram.com/username/',
                                  icon: Icons.camera_alt_outlined,
                                ),
                                _field(
                                  controller: _urlTiktok,
                                  label: 'تيك توك',
                                  hint: 'https://www.tiktok.com/@username',
                                  icon: Icons.music_note_outlined,
                                ),
                                _field(
                                  controller: _urlSnapchat,
                                  label: 'سناب شات',
                                  hint:
                                      'https://www.snapchat.com/add/username',
                                  icon: Icons.bolt_outlined,
                                ),
                              ]),
                            ),

                            const SizedBox(height: 24),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SizedBox(
                                width: 220,
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _saveSettings,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.save_outlined,
                                          size: 18),
                                  label: Text(
                                      _isSaving
                                          ? 'جارٍ الحفظ...'
                                          : 'حفظ الإعدادات',
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _brand,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ===================== عناصر الواجهة =====================

  static const Color _brand = Color(0xFFD32027);
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _border = Color(0xFFE5E7EB);

  Widget _pageHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.settings_outlined, color: _brand, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('إعدادات المنصة',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// بطاقة بعنوان ووصف — نفس نمط بقية شاشات اللوحة
  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: Colors.grey.shade600),
              const SizedBox(width: 7),
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          Text(subtitle,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  height: 1.7,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _maintenanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _isMaintenanceMode
                ? _brand.withValues(alpha: 0.4)
                : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_circle_outlined,
                  size: 17,
                  color: _isMaintenanceMode ? _brand : Colors.grey.shade600),
              const SizedBox(width: 7),
              const Text('وضع الصيانة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _isMaintenanceMode,
                activeThumbColor: _brand,
                onChanged: (v) => setState(() => _isMaintenanceMode = v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isMaintenanceMode
                ? 'المنصة مغلقة الآن — يرى المستخدمون رسالة الصيانة'
                : 'عند التفعيل، يرى المستخدمون رسالة الصيانة بدل المحتوى',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                height: 1.7,
                color: _isMaintenanceMode ? _brand : Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          const Text('رسالة الصيانة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _maintenanceMessageController,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            decoration: _dec('اكتب ما يظهر للمستخدمين أثناء الصيانة...'),
          ),
        ],
      ),
    );
  }

  /// شبكة تتكيّف مع عرض الشاشة
  Widget _grid(bool wide, List<Widget> items) {
    if (!wide) {
      return Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: items[i]),
          const SizedBox(width: 16),
          Expanded(
              child: i + 1 < items.length
                  ? items[i + 1]
                  : const SizedBox.shrink()),
        ],
      ));
      if (i + 2 < items.length) rows.add(const SizedBox(height: 14));
    }
    return Column(children: rows);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          // الروابط والأرقام تُقرأ من اليسار
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 12.5),
          decoration: _dec(hint),
        ),
      ],
    );
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade400),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: _bg,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _brand, width: 1.4)),
    );
  }
}
