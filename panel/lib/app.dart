import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'app_config.dart';
import 'features/auth/login_page.dart';
import 'features/auth/account_recovery_page.dart';

final supabase = Supabase.instance.client;

/// تشغيل اللوحة لمدخل واحد: التاجر (main.dart) أو الإدارة (main_admin.dart)
Future<void> runPanel({
  required String role,
  required Widget Function() dashboard,
}) async {
  AppConfig.role = role;
  AppConfig.dashboard = dashboard;

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
      title: AppConfig.isAdmin ? 'Red Market — الإدارة' : 'Red Market',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      builder: (context, child) {
        final size = MediaQuery.sizeOf(context);
        const msgWidth = 380.0;
        final side = size.width > msgWidth + 32
            ? (size.width - msgWidth) / 2
            : 16.0;
        return Theme(
          data: Theme.of(context).copyWith(
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              insetPadding: EdgeInsets.fromLTRB(
                side,
                0,
                side,
                size.height / 2 - 30,
              ),
              backgroundColor: const Color(0xFF1F2937),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentTextStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ScaffoldMessenger(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset: false,
                body: child!,
              ),
            ),
          ),
        );
      },
      theme: base.copyWith(
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

      // كل مدخل يقبل دوره فقط
      if (role != AppConfig.role) {
        await supabase.auth.signOut();
        return const LoginPage();
      }

      // حساب مجدول للحذف: شاشة الاستعادة بدل اللوحة
      final raw = profile?['deletion_scheduled_at'];
      final scheduled = raw == null
          ? null
          : DateTime.tryParse(raw.toString())?.toLocal();

      if (scheduled != null) {
        return AccountRecoveryPage(
          scheduledAt: scheduled,
          onRestored: () {
            if (mounted) setState(() => _start = _resolve());
          },
        );
      }

      return AppConfig.dashboard();
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
