import 'dart:async';

import 'package:flutter/material.dart';
import 'package:red_market/core/services/splash_ad_service.dart';

/// شاشة إعلان الافتتاح — ثلاث ثوانٍ بزر تخطٍّ بعد ثانيتين
class SplashAdScreen extends StatefulWidget {
  final SplashAdData ad;
  final VoidCallback onFinish;
  final void Function(SplashAdData ad) onTap;

  const SplashAdScreen({
    super.key,
    required this.ad,
    required this.onFinish,
    required this.onTap,
  });

  @override
  State<SplashAdScreen> createState() => _SplashAdScreenState();
}

class _SplashAdScreenState extends State<SplashAdScreen> {
  static const _duration = 3;
  static const _skipAfter = 2;

  Timer? _timer;
  int _elapsed = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();

    // تسجيل الظهور فوراً
    SplashAdService.instance.trackImpression(widget.ad.id);
    SplashAdService.instance.markShown();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _duration) _finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onFinish();
  }

  void _skip() {
    if (_done) return;
    SplashAdService.instance.trackSkip(widget.ad.id);
    _finish();
  }

  void _open() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    SplashAdService.instance.trackClick(widget.ad.id);
    widget.onTap(widget.ad);
  }

  @override
  Widget build(BuildContext context) {
    final canSkip = _elapsed >= _skipAfter;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ===== الإعلان =====
          Positioned.fill(
            child: GestureDetector(
              onTap: _open,
              child: Image.file(
                widget.ad.file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  // إن تعذّر عرض الصورة نمضي فوراً
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _finish();
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),

          // ===== زر التخطي =====
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16,
            child: AnimatedOpacity(
              opacity: canSkip ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !canSkip,
                child: GestureDetector(
                  onTap: _skip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'تخطي',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.chevron_left_rounded,
                            color: Colors.white, size: 17),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ===== شارة إعلان =====
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'إعلان',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
