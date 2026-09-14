import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'features/auth/login_page.dart';
import 'features/admin/categories_page.dart';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ycuzwfsaxnfbdskerjfw.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InljdXp3ZnNheG5mYmRza2VyamZ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1Mjc2ODAsImV4cCI6MjA4NzEwMzY4MH0.Eh88kUtJGYaRyeYCunpKVteVARIP1i2V1mJCQYLgDtY',
  );
  runApp(const ProviderScope(child: RedMarketWebApp()));
}

class RedMarketWebApp extends StatelessWidget {
  const RedMarketWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
    );

    return MaterialApp(
      title: 'Red Market',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: base.copyWith(
        // ✅ خط Cairo على كل نصوص اللوحة
        textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
        primaryTextTheme: GoogleFonts.cairoTextTheme(base.primaryTextTheme),
      ),
      home: const LoginPage(),
    );
  }
}

class ConnectionTestPage extends StatefulWidget {
  const ConnectionTestPage({super.key});
  @override
  State<ConnectionTestPage> createState() => _ConnectionTestPageState();
}

class _ConnectionTestPageState extends State<ConnectionTestPage> {
  String _status = 'جاري الاتصال...';

  @override
  void initState() {
    super.initState();
    _test();
  }

  Future<void> _test() async {
    try {
      final res = await supabase.from('subscription_plans').select('name');
      setState(
        () => _status = 'الاتصال ناجح — عدد الباقات: ${(res as List).length}',
      );
    } catch (e) {
      setState(() => _status = 'فشل الاتصال: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        title: const Text('رد ماركت — لوحة التحكم'),
      ),
      body: Center(child: Text(_status, style: const TextStyle(fontSize: 20))),
    );
  }
}
