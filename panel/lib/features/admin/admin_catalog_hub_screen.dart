import 'package:flutter/material.dart';

import 'admin_products_screen.dart';
import 'categories_page.dart';

/// قسم العروض والتصنيفات
class AdminCatalogHubScreen extends StatefulWidget {
  const AdminCatalogHubScreen({super.key});

  @override
  State<AdminCatalogHubScreen> createState() =>
      _AdminCatalogHubScreenState();
}

class _AdminCatalogHubScreenState extends State<AdminCatalogHubScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final _searchCtrl = TextEditingController();

  int _tab = 0;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int i) {
    if (_tab == i) return;
    setState(() {
      _tab = i;
      _query = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            // ===== التبويبات والبحث =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 620;

                      final tabs = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _tabChip(0, 'العروض', Icons.inventory_2_outlined),
                          const SizedBox(width: 10),
                          _tabChip(1, 'التصنيفات', Icons.category_outlined),
                        ],
                      );

                      final search = _searchField();

                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            tabs,
                            const SizedBox(height: 12),
                            search,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          tabs,
                          const SizedBox(width: 14),
                          Expanded(child: search),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      AdminProductsScreen(searchQuery: _query),
                      AdminCategoriesScreen(searchQuery: _query),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
        decoration: InputDecoration(
          hintText: _tab == 0
              ? 'ابحث باسم العرض أو التاجر'
              : 'ابحث عن تصنيف',
          hintStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search_rounded,
              size: 19, color: Colors.grey.shade500),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 17, color: Colors.grey.shade500),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFEDEFF3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: brandRed, width: 1.4),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _tabChip(int index, String label, IconData icon) {
    final on = _tab == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
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
