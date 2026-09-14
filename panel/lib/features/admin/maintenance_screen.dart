import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String _message = "التطبيق تحت الصيانة، يرجى المحاولة لاحقاً.";

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
      if (mounted &&
          data != null &&
          data['maintenance_message'] != null &&
          data['maintenance_message'].toString().isNotEmpty) {
        setState(() => _message = data['maintenance_message']);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle_outlined,
                    size: 100, color: Color(0xFFD32027)),
                const SizedBox(height: 24),
                const Text("تحت الصيانة",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(_message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
