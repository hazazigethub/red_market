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
  bool _isMaintenanceMode = false;
  bool _isLoading = true;

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
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await supabase.from('system_settings').upsert({
        'id': 1,
        'is_maintenance': _isMaintenanceMode,
        'maintenance_message': _maintenanceMessageController.text.trim(),
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
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("حفظ الإعدادات",
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
