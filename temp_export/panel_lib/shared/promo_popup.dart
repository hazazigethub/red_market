import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// نافذة كود الخصم للتاجر
/// scope: banner | splash | campaign
/// الخادم يختار الكود ويعدّ مرات الظهور لكل تاجر
Future<void> showPromoPopup(BuildContext context, String scope) async {
  Map<String, dynamic>? promo;
  try {
    final res = await Supabase.instance.client
        .rpc('get_promo_popup', params: {'p_scope': scope});
    if (res == null) return;
    promo = Map<String, dynamic>.from(res as Map);
  } catch (e) {
    debugPrint('Promo popup error: $e');
    return;
  }

  if (!context.mounted) return;

  final code = '${promo['code'] ?? ''}';
  final pct = (promo['discount_percent'] as num?)?.toInt() ?? 0;
  if (code.isEmpty || pct <= 0) return;

  const brandRed = Color(0xFFD32027);

  await showDialog(
    context: context,
    builder: (ctx) {
      bool copied = false;
      return StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.fromLTRB(22, 26, 22, 10),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE9EA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.local_offer_rounded,
                          color: brandRed, size: 28),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'احصل على خصم $pct%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: brandRed),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'باستخدام الكود التالي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      setModal(() => copied = true);
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: const Color(0x73D32027),
                            width: 1.4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              size: 18,
                              color: copied ? Colors.green : brandRed),
                          const SizedBox(width: 6),
                          Text(copied ? 'تم النسخ' : 'نسخ',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      copied ? Colors.green : brandRed)),
                          const Spacer(),
                          Text(
                            code,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
            actions: [
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandRed,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('حسناً',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
