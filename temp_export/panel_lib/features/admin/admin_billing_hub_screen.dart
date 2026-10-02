import 'package:flutter/material.dart';

import 'admin_plans_screen.dart';
import 'discount_codes_screen.dart';

/// قسم الباقات وأكواد الخصم
class AdminBillingHubScreen extends StatefulWidget {
  const AdminBillingHubScreen({super.key});

  @override
  State<AdminBillingHubScreen> createState() =>
      _AdminBillingHubScreenState();
}

class _AdminBillingHubScreenState extends State<AdminBillingHubScreen> {
  static const Color brandRed = Color(0xFFD32027);

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            // ===== التبويبان =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Row(
                    children: [
                      _tabChip(
                          0, 'الباقات', Icons.card_membership_outlined),
                      const SizedBox(width: 10),
                      _tabChip(
                          1, 'أكواد الخصم', Icons.local_offer_outlined),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  AdminPlansScreen(),
                  DiscountCodesScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(int index, String label, IconData icon) {
    final on = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: on ? brandRed : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: on ? brandRed : const Color(0xFFEDEFF3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17, color: on ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                color: on ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
