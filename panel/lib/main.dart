import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'features/auth/login_page.dart';
import 'features/auth/account_recovery_page.dart';

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
      home: const AuthGate(),
    );
  }
}

/// يفحص الجلسة المحفوظة عند كل تحميل — فلا يخرج التاجر بتحديث الصفحة
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Widget>? _start;

  @override
  void initState() {
    super.initState();
    _start = _resolve();
  }

  Future<Widget> _resolve() async {
    final session = supabase.auth.currentSession;
    if (session == null) return const LoginPage();

    try {
      final profile = await supabase
          .from('profiles')
          .select('role, deletion_scheduled_at')
          .eq('id', session.user.id)
          .maybeSingle();

      final role = profile?['role']?.toString();

      // اللوحة للتجار والإدارة فقط
      if (role != 'super_admin' && role != 'merchant') {
        await supabase.auth.signOut();
        return const LoginPage();
      }

      // حساب مجدول للحذف: شاشة الاستعادة بدل اللوحة
      final raw = profile?['deletion_scheduled_at'];
      final scheduled =
          raw == null ? null : DateTime.tryParse(raw.toString());

      if (scheduled != null) {
        return AccountRecoveryPage(
          scheduledAt: scheduled,
          onRestored: () {
            if (mounted) setState(() => _start = _resolve());
          },
        );
      }

      return buildDashboardFor(role!);
    } catch (_) {
      // تعذّر التحقّق — نعود لصفحة الدخول بلا إسقاط التطبيق
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _start,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          );
        }
        return snap.data ?? const LoginPage();
      },
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
