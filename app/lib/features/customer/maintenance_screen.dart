import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// شاشة الصيانة: تُعرض للمستخدم عند تفعيل وضع الصيانة من لوحة الإدارة
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  static const Color brandRed = Color(0xFFD32027);

  String _message = 'نقوم حالياً بأعمال صيانة لتحسين التجربة.';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    try {
      final data = await Supabase.instance.client
          .from('system_settings')
          .select('maintenance_message')
          .eq('id', 1)
          .maybeSingle();
      final msg = data?['maintenance_message']?.toString();
      if (msg != null && msg.trim().isNotEmpty && mounted) {
        setState(() => _message = msg);
      }
    } catch (e) {
      debugPrint('Maintenance message error: $e');
    }
  }

  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final data = await Supabase.instance.client
          .from('system_settings')
          .select('is_maintenance')
          .eq('id', 1)
          .maybeSingle();
      final stillOn = (data?['is_maintenance'] as bool?) ?? false;
      if (!mounted) return;
      if (stillOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ما زالت الصيانة جارية، نعتذر عن الانتظار',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('انتهت الصيانة — أعد تشغيل التطبيق',
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر الاتصال، تحقق من الشبكة',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 90,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront_rounded,
                        size: 80,
                        color: brandRed),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: brandRed.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.build_circle_outlined,
                        size: 52, color: brandRed),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'التطبيق تحت الصيانة',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        color: Colors.black),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        fontFamily: 'Cairo',
                        color: Colors.grey),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
