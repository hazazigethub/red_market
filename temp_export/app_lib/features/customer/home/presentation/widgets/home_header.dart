import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red_market/core/routing/route_paths.dart';

class HomeHeader extends StatelessWidget {
  final TextEditingController searchController;
  const HomeHeader({super.key, required this.searchController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Image.asset('assets/images/logo.png',
                  height: 35,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.store_mall_directory,
                      color: Color(0xFFD32027))),
              const SizedBox(width: 8),
              const Text("رد ماركت",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFFD32027))),
            ],
          ),
        ),
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ],
            ),
            child: TextField(
              controller: searchController,
              onSubmitted: (value) => value.isNotEmpty
                  ? context.push(RoutePaths.searchResults, extra: value)
                  : null,
              decoration: const InputDecoration(
                hintText: "عن ماذا تبحث اليوم؟",
                hintStyle: TextStyle(
                    color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Color(0xFFD32027), size: 24),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
