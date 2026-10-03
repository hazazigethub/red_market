// panel/lib/features/payments/charge_dialog.dart
// نافذة الدفع المنبثقة: صفحة الدفع المدمجة داخل إطار، ورمز التحقق يظهر داخلها.
// تُغلق تلقائياً عند النجاح وتعيد true.
import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'payments_api.dart';

Future<bool> showChargeDialog(BuildContext context, double amount) async {
  final paid = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _ChargeDialog(amount: amount),
  );
  return paid == true;
}

class _ChargeDialog extends StatefulWidget {
  final double amount;
  const _ChargeDialog({required this.amount});

  @override
  State<_ChargeDialog> createState() => _ChargeDialogState();
}

class _ChargeDialogState extends State<_ChargeDialog> {
  static const brandRed = Color(0xFFD32027);

  String? _viewType;
  String? _error;
  bool _loading = true;
  StreamSubscription<web.MessageEvent>? _sub;

  late final String _allowedOrigin = Uri.parse(kPaymentsApiBase).origin;

  @override
  void initState() {
    super.initState();
    _sub = web.EventStreamProviders.messageEvent
        .forTarget(web.window)
        .listen(_onMessage);
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// ينشئ دفعة وجلسة جديدتين ويعرض صفحة الدفع
  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _viewType = null;
    });

    final (url, error) = await createWalletCharge(widget.amount);
    if (!mounted) return;

    if (url == null) {
      setState(() {
        _error = error;
        _loading = false;
      });
      return;
    }

    final viewType = 'rm-checkout-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final frame = web.HTMLIFrameElement()
        ..src = url
        ..allow = 'payment'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return frame;
    });

    setState(() {
      _viewType = viewType;
      _loading = false;
    });
  }

  void _onMessage(web.MessageEvent e) {
    if (e.origin != _allowedOrigin) return;
    final data = e.data.dartify();
    if (data is! Map || data['type'] != 'rm-payment') return;

    switch (data['status']) {
      case 'success':
        if (mounted) Navigator.of(context).pop(true);
      case 'retry':
        _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 480,
        height: (size.height - 32).clamp(420.0, 680.0),
        child: Column(
          children: [
            // الرأس
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEDEFF3))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18, color: brandRed),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'الدفع الآمن',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),

            // المحتوى
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: brandRed))
                  : _error != null
                      ? _errorView()
                      : HtmlElementView(viewType: _viewType!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: brandRed, size: 44),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                ),
                child: const Text(
                  'المحاولة مرة أخرى',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
