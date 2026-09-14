import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/services/visit_logger.dart';
import 'package:red_market/core/routing/route_paths.dart';

class CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final Function(Map<String, dynamic>)? onCategoryTap;

  const CategoryGrid({super.key, required this.categories, this.onCategoryTap});

  /// يسجّل زيارة التصنيف الرئيسي عند فتحه
  static Future<void> _logCategoryVisit(Map<String, dynamic> cat) =>
      VisitLogger.log(
        pageName: 'category',
        categoryId: cat['id']?.toString(),
        categoryName: cat['name']?.toString(),
      );

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 86,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final String catName = cat['name'] ?? '';

          return Padding(
            padding: const EdgeInsets.only(left: 12),
            child: InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () {
                _logCategoryVisit(cat);
                if (onCategoryTap != null) {
                  onCategoryTap!(cat);
                } else {
                  context.push(
                    RoutePaths.subCategories,
                    extra: {
                      'parentId': cat['id'],
                      'categoryName': cat['name'],
                    },
                  );
                }
              },
              child: Container(
                width: 85,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFD32027).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    catName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
