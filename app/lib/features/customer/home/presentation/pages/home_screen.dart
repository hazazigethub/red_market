import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:red_market/app/app.dart';
import 'package:red_market/main.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/core/services/campaign_service.dart';
import 'package:red_market/core/services/visit_logger.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/features/customer/home/presentation/providers/recently_viewed_provider.dart';

import 'package:red_market/features/customer/home/presentation/pages/reels_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/profile_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/favourites_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/notifications_page.dart';
import 'package:red_market/features/auth/presentation/login_screen.dart';

import '../widgets/logout_dialog.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/main_wide_banner.dart';
import '../widgets/small_banners_row.dart';
import '../widgets/category_grid.dart';
import '../widgets/product_card.dart';
import '../widgets/merchant_circle_list.dart';
import '../widgets/infinite_products_grid.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static bool _isSessionLogged = false;
  final supabase = Supabase.instance.client;
  int _bottomNavIndex = 0;
  String? _cachedRole;
  bool _roleTimeoutScheduled = false;

  final PageController _bannerPageController =
      PageController(viewportFraction: 0.93);
  final PageController _smallBannerPageController =
      PageController(viewportFraction: 0.48);
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _realCategories = [];


  /// الحملة الموسمية النشطة

  Map<String, dynamic>? _campaign;
  List<MerchantModel> _merchantsList = [];
  List<ProductModel> _followedProducts = [];
  int _unreadCount = 0;
  List<ProductModel> _flashSaleProducts = [];
  List<ProductModel> _newArrivals = [];

  /// عروض مختارة — أعلى عرض تفاعلاً لكل متجر احترافي
  List<ProductModel> _curatedProducts = [];

  /// خمسة تصنيفات عشوائية بعروضها
  List<Map<String, dynamic>> _categoryShowcase = [];
  List<ProductModel> _infiniteProducts = [];

  bool _isInfiniteLoading = false;
  int _currentOffset = 0;
  String? _merchantStoreName;
  final int _pageSize = 10;
  bool _isDataLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
    _initCachedRole();
    _loadRecentlyViewed();
    _loadMerchantName();
    _startAutoPlay();
    _checkAndShowAnnouncements();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendLogVisit();
      _checkTermsVersion();
    });
  }

  Future<void> _checkAndShowAnnouncements() async {
    final user = supabase.auth.currentUser;

    try {
      String role = 'customer';

      if (user != null) {
        final userProfile = await supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        role = userProfile?['role']?.toString() ?? 'customer';
      }

      final announcements = await supabase
          .from('announcements')
          .select()
          .eq('is_active', true)
          .or('target_role.eq.all,target_role.eq.$role')
          .order('created_at', ascending: true);

      // الزائر: عدّاد محلي على الجهاز
      final prefs =
          user == null ? await SharedPreferences.getInstance() : null;

      for (final ann in (announcements as List)) {
        final int maxViews = ann['max_views'] ?? 1;
        final String annId = ann['id'].toString();

        // ===== زائر =====
        if (user == null) {
          final key = 'ann_views_$annId';
          final int seen = prefs?.getInt(key) ?? 0;

          if (seen < maxViews) {
            await prefs?.setInt(key, seen + 1);
            if (mounted) {
              _showAnnouncementDialog(ann);
              break;
            }
          }
          continue;
        }

        // ===== مسجّل =====
        final viewRes = await supabase
            .from('announcement_views')
            .select()
            .eq('announcement_id', ann['id'])
            .eq('user_id', user.id)
            .maybeSingle();

        final int viewsCount = viewRes?['views_count'] ?? 0;

        if (viewsCount < maxViews) {
          if (viewRes == null) {
            await supabase.from('announcement_views').insert({
              'announcement_id': ann['id'],
              'user_id': user.id,
              'views_count': 1,
            });
          } else {
            await supabase
                .from('announcement_views')
                .update({
                  'views_count': viewsCount + 1,
                  'last_viewed_at': DateTime.now().toIso8601String(),
                })
                .eq('announcement_id', ann['id'])
                .eq('user_id', user.id);
          }

          if (mounted) {
            _showAnnouncementDialog(ann);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Announcement Error: $e");
    }
  }

  void _showAnnouncementDialog(Map<String, dynamic> ann) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFD32027), width: 2),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ann['image_url'] != null)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        ann['image_url'],
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.75,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 48,
                      height: MediaQuery.of(context).size.width - 48,
                    ),
                  if (ann['image_url'] == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        children: [
                          if ((ann['title'] ?? '').isNotEmpty)
                            Text(ann['title'],
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                                textAlign: TextAlign.center),
                          if ((ann['message'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(ann['message'],
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    color: Colors.grey),
                                textAlign: TextAlign.center),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              // ✅ زر الإغلاق في الأعلى
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32027),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkTermsVersion() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final userData = await supabase
          .from('profiles')
          .select('role, accepted_terms_version')
          .eq('id', user.id)
          .maybeSingle();

      if (userData != null) {
        final String role = userData['role']?.toString() ?? 'customer';
        final int userVersion =
            (userData['accepted_terms_version'] as num?)?.toInt() ?? 0;

        final latestTerms = await supabase
            .from('terms_content')
            .select('version, content')
            .eq('type', role.trim().toLowerCase())
            .maybeSingle();

        if (latestTerms != null) {
          final int serverVersion =
              int.tryParse(latestTerms['version']?.toString() ?? '0') ?? 0;
          if (userVersion < serverVersion) {
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => WillPopScope(
                onWillPop: () async => false,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text("تحديث الشروط والأحكام",
                        style: TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    content: const Text(
                        "لقد قمنا بتحديث الشروط والأحكام الخاصة بنا. يرجى مراجعتها والموافقة عليها للمتابعة.",
                        style: TextStyle(fontFamily: 'Cairo')),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32027),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(RoutePaths.customerTerms, extra: {
                            'content': latestTerms['content'],
                            'version': serverVersion
                          });
                        },
                        child: const Text("مراجعة وتحديث",
                            style: TextStyle(
                                fontFamily: 'Cairo', color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Terms Error: $e");
    }
  }

  Future<void> _sendLogVisit() async {
    final user = supabase.auth.currentUser;

    // تسجيل الزيارة مرة واحدة لكل تشغيل
    if (!isAppVisitLogged) {
      await VisitLogger.log(pageName: 'app_launch');
      isAppVisitLogged = true;
    }

    // تحديث آخر دخول مستقل عن حارس الزيارة
    if (user != null) {
      try {
        await supabase.from('profiles').update({
          'last_sign_in_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      } catch (e) {
        debugPrint("Last sign-in update error: $e");
      }
    }
  }

  @override
  void dispose() {
    _bannerPageController.dispose();
    _smallBannerPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerPageController.hasClients) {
        _bannerPageController.animateToPage(
            (_bannerPageController.page!.toInt() + 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut);
      }
      if (_smallBannerPageController.hasClients) {
        _smallBannerPageController.animateToPage(
            (_smallBannerPageController.page!.toInt() + 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut);
      }
    });
  }

  /// يجلب الحملة الموسمية النشطة
  Future<void> _loadCampaign() async {
    final c = await CampaignService.instance.getActive();
    if (!mounted) return;
    setState(() => _campaign = c);
  }

  Future<void> _fetchHomeData() async {
    _loadCampaign();

    _fetchFollowedProducts();
    _fetchUnreadCount();
    if (!mounted) return;
    setState(() => _isDataLoading = true);
    try {
      final catData = await supabase
          .from('store_categories')
          .select()
          .eq('is_visible', true);
      final activeProfiles = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'merchant')
          .eq('is_subscription_active', true);
      final List<String> activeMerchantIds =
          (activeProfiles as List).map((p) => p['id'].toString()).toList();
      // المتاجر: الاحترافية إن بلغت خمسة، وإلا الجميع
      List merchData;
      try {
        merchData = await supabase.rpc('get_featured_merchants') as List;
      } catch (e) {
        debugPrint('featured merchants error: $e');
        merchData = await supabase.from('merchants').select('*') as List;
      }
      final allProducts =
          await supabase.from('products').select('merchant_id, image_url');

      final nowIso = DateTime.now().toIso8601String();

      final flashData = activeMerchantIds.isEmpty
          ? []
          : await supabase
              .from('products')
              .select()
              .eq('is_flash_sale', true)
              .or('is_banned.eq.false,is_banned.is.null')
              // العروض المجدولة تُخفى حتى موعدها
              .or('flash_sale_start.is.null,flash_sale_start.lte.$nowIso')
              .gt('flash_sale_expiry', nowIso)
              .inFilter('merchant_id', activeMerchantIds)
              .limit(10);

      final fiveDaysAgo =
          DateTime.now().subtract(const Duration(days: 5)).toIso8601String();
      final newData = activeMerchantIds.isEmpty
          ? []
          : await supabase
              .from('products')
              .select()
              .eq('is_available', true)
              .or('is_banned.eq.false,is_banned.is.null')
              .or('flash_sale_start.is.null,flash_sale_start.lte.$nowIso')
              .gte('created_at', fiveDaysAgo)
              .inFilter('merchant_id', activeMerchantIds)
              .order('created_at', ascending: false)
              .limit(10);

      // عروض مختارة وتصنيفات عشوائية — من دوال قاعدة البيانات
      List curatedData = [];
      List showcaseData = [];
      try {
        curatedData = await supabase.rpc('get_curated_products') as List;
      } catch (e) {
        debugPrint('curated error: $e');
      }
      try {
        showcaseData = await supabase.rpc('get_category_showcase') as List;
      } catch (e) {
        debugPrint('showcase error: $e');
      }

      if (mounted) {
        setState(() {
          _realCategories = List<Map<String, dynamic>>.from(catData);
          _merchantsList = merchData
              .where((m) => activeMerchantIds.contains(m['id']?.toString()))
              .map((m) {
            final merchant = MerchantModel.fromJson(m);
            final List merchantProducts = (allProducts as List)
                .where((p) => p['merchant_id'] == merchant.id)
                .toList();
            final List<String> images = merchantProducts
                .map((p) => p['image_url']?.toString() ?? '')
                .where((url) => url.isNotEmpty)
                .take(3)
                .toList();
            return merchant.copyWith(showcaseImages: images);
          }).where((merchant) {
            return (allProducts as List)
                .any((p) => p['merchant_id'] == merchant.id);
          }).toList();

          _flashSaleProducts =
              (flashData as List).map((p) => ProductModel.fromJson(p)).toList();
          _newArrivals =
              (newData as List).map((p) => ProductModel.fromJson(p)).toList();

          _curatedProducts = curatedData
              .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
              .toList();

          _categoryShowcase = List<Map<String, dynamic>>.from(showcaseData);

          _isDataLoading = false;
        });
        _loadInfiniteProducts();
      }
    } catch (e) {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  Future<void> _loadInfiniteProducts() async {
    if (_isInfiniteLoading) return;
    setState(() => _isInfiniteLoading = true);
    try {
      final randomProducts = await supabase
          .from('products')
          .select()
          .or('flash_sale_start.is.null,flash_sale_start.lte.'
              '${DateTime.now().toIso8601String()}')
          .range(_currentOffset, _currentOffset + _pageSize - 1);
      if (mounted) {
        setState(() {
          _infiniteProducts.addAll((randomProducts as List)
              .map((p) => ProductModel.fromJson(p))
              .toList());
          _currentOffset += _pageSize;
          _isInfiniteLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isInfiniteLoading = false);
    }
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      // ✅ مسجل دخول — جلب من السوبابيس
      if (userId != null) {
        final fiveDaysAgo =
            DateTime.now().subtract(const Duration(days: 5)).toIso8601String();

        final data = await supabase
            .from('user_recently_viewed')
            .select('product_id, visited_at, products(*)')
            .eq('user_id', userId)
            .gte('visited_at', fiveDaysAgo)
            .order('visited_at', ascending: false)
            .limit(20);

        if (mounted) {
          final List<ProductModel> products = (data as List)
              .where((e) => e['products'] != null)
              .map((e) => ProductModel.fromJson(e['products']))
              .toList();
          ref.read(recentlyViewedProvider.notifier).state = products;
        }
        return;
      }

      // ✅ غير مسجل — جلب من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString('recently_viewed_data') ?? '[]';

      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));

      final now = DateTime.now();
      items = items.where((e) {
        final visitedAt = DateTime.tryParse(e['visited_at'] ?? '');
        return visitedAt != null && now.difference(visitedAt).inDays < 5;
      }).toList();

      await prefs.setString('recently_viewed_data', jsonEncode(items));

      final List<String> recentIds =
          items.map((e) => e['id'] as String).toList();

      if (recentIds.isNotEmpty) {
        final data = await supabase
            .from('products')
            .select()
            .filter('id', 'in', recentIds)
            .limit(20);

        if (mounted) {
          final List<ProductModel> products =
              (data as List).map((p) => ProductModel.fromJson(p)).toList();
          final byId = {for (final p in products) p.id: p};
          final sorted = recentIds
              .map((id) => byId[id])
              .whereType<ProductModel>()
              .toList();
          ref.read(recentlyViewedProvider.notifier).state = sorted;
        }
      }
    } catch (e) {
      debugPrint("Error loading recently viewed: $e");
    }
  }

  Future<void> _initCachedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    if (role != null && mounted) {
      setState(() => _cachedRole = role);
    }
  }

  Future<void> _loadMerchantName() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await supabase
          .from('merchants')
          .select('store_name')
          .eq('id', userId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _merchantStoreName = data['store_name']?.toString());
      }
    } catch (e) {
      debugPrint("Error loading merchant name: $e");
    }
  }

  Future<void> _handleLogout() async {
    await showLogoutDialog(context, ref, () {
      setState(() => _bottomNavIndex = 0);
    });
  }

  void _protectedAction(VoidCallback onSuccess) {
    if (supabase.auth.currentUser != null) {
      onSuccess();
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const LoginScreen(isBottomSheet: true),
      ).then((value) {
        if (value == true && mounted) {
          setState(() {});
          onSuccess();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentlyViewedItems = ref.watch(recentlyViewedProvider);
    final userRole = ref.watch(userRoleProvider);
    if (userRole != null) _cachedRole = userRole;
    final String? effectiveRole = userRole ?? _cachedRole;

    if (effectiveRole == null &&
        Supabase.instance.client.auth.currentUser != null) {
      // ✅ timeout: يُجدوَل مرة واحدة فقط، لا مع كل إعادة بناء
      if (!_roleTimeoutScheduled) {
        _roleTimeoutScheduled = true;
        Future.delayed(const Duration(seconds: 3), () async {
          if (mounted && ref.read(userRoleProvider) == null) {
            final userId = supabase.auth.currentUser?.id;
            if (userId != null) {
              final data = await supabase
                  .from('profiles')
                  .select('role')
                  .eq('id', userId)
                  .maybeSingle();
              if (data != null && mounted) {
                ref.read(userRoleProvider.notifier).state =
                    data['role']?.toString();
              }
            }
          }
          if (mounted) _roleTimeoutScheduled = false;
        });
      }
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png',
                    height: 60,
                    errorBuilder: (c, e, s) => const Icon(Icons.store,
                        color: Color(0xFFD32027), size: 60)),
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Color(0xFFD32027)),
              ],
            ),
          ),
        ),
      );
    }

    final bool isAdmin = effectiveRole == 'super_admin';
    final bool isMerchant = effectiveRole == 'merchant';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: _isDataLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD32027)))
              : _buildCurrentPage(isAdmin, isMerchant, recentlyViewedItems),
        ),
        floatingActionButton: (isAdmin || isMerchant) ? null : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildBottomNavBar(isAdmin, isMerchant),
      ),
    );
  }

  Widget _buildCurrentPage(
      bool isAdmin, bool isMerchant, List<ProductModel> recentlyViewedItems) {
    switch (_bottomNavIndex) {
      case 0:
        return _buildHomeContent(recentlyViewedItems);
      case 1:
        return const FavouritesPage();
      case 2:
        return const ReelsPage();
      case 3:
        return const NotificationsPage();
      case 4:
        return const ProfilePage();
      default:
        return _buildHomeContent(recentlyViewedItems);
    }
  }

  Widget _buildBottomNavBar(bool isAdmin, bool isMerchant) {
    return BottomAppBar(
      color: _bottomNavIndex == 2
          ? Colors.black
          : Theme.of(context).colorScheme.surface,
      shape: null,
      notchMargin: 0,
      elevation: 20,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.home_filled, "الرئيسية"),
            _buildNavItem(1, Icons.bookmark_border_rounded, "المفضلة"),
            _buildNavItem(2, Icons.play_circle_outline, "ريلز"),
            _buildNavItem(3, Icons.notifications_none, "الإشعارات"),
            if (!isAdmin && !isMerchant)
              _buildNavItem(4, Icons.person_outline, "حسابي"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _bottomNavIndex == index;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        if (index == 0) {
          setState(() => _bottomNavIndex = 0);
          _fetchUnreadCount();
        } else {
          _protectedAction(() {
            setState(() => _bottomNavIndex = index);
            if (index != 3) _fetchUnreadCount();
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon,
                  color: isSelected ? const Color(0xFFD32027) : Colors.grey,
                  size: 24),
              if (index == 3 && _unreadCount > 0)
                Positioned(
                  top: -4,
                  left: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32027),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFFD32027) : Colors.grey)),
        ],
      ),
    );
  }

  /// يحسب عدد الإشعارات غير المقروءة لهذا المستخدم
  Future<void> _fetchUnreadCount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _unreadCount = 0);
        return;
      }

      // إطلاق الإشعارات المجدولة التي حان موعدها
      try {
        await supabase.rpc('release_due_notifications');
      } catch (_) {}

      final notifs = await supabase
          .from('notifications_log')
          .select('id, target_type, target_id, segment_filter')
          .eq('status', 'sent')
          .limit(200);

      final reads = await supabase
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', userId);

      final readIds = List<Map<String, dynamic>>.from(reads)
          .map((r) => r['notification_id']?.toString())
          .whereType<String>()
          .toSet();

      final follows = await supabase
          .from('merchant_followers')
          .select('merchant_id')
          .eq('user_id', userId);

      final followedIds = List<Map<String, dynamic>>.from(follows)
          .map((f) => f['merchant_id']?.toString())
          .whereType<String>()
          .toSet();

      final mine = List<Map<String, dynamic>>.from(notifs).where((n) {
        final type = n['target_type'];
        final targetId = n['target_id'];
        final segment = n['segment_filter'];
        if (type == 'all') return true;
        if (type == 'specific' && targetId == userId) return true;
        if (type == 'segment' && segment != null) {
          return segment.toString().contains('users');
        }
        if (type == 'followers' && targetId != null) {
          return followedIds.contains(targetId.toString());
        }
        return false;
      });

      final count =
          mine.where((n) => !readIds.contains(n['id']?.toString())).length;

      if (mounted) setState(() => _unreadCount = count);
    } catch (e) {
      debugPrint('Unread count error: $e');
    }
  }

  /// يجلب أحدث عروض المتاجر التي يتابعها المستخدم
  Future<void> _fetchFollowedProducts() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _followedProducts = []);
        return;
      }

      final follows = await supabase
          .from('merchant_followers')
          .select('merchant_id')
          .eq('user_id', userId);

      final ids = List<Map<String, dynamic>>.from(follows)
          .map((f) => f['merchant_id']?.toString())
          .whereType<String>()
          .toList();

      if (ids.isEmpty) {
        if (mounted) setState(() => _followedProducts = []);
        return;
      }

      final data = await supabase
          .from('products')
          .select()
          .inFilter('merchant_id', ids)
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(12);

      final list = List<Map<String, dynamic>>.from(data)
          .map((e) => ProductModel.fromJson(e))
          .toList();

      if (mounted) setState(() => _followedProducts = list);
    } catch (e) {
      debugPrint('Followed products error: $e');
    }
  }

  Widget _buildHomeContent(List<ProductModel> recentlyViewedItems) {
    return RefreshIndicator(
      color: const Color(0xFFD32027),
      onRefresh: _fetchHomeData,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSmartHeader(),
            // ✅ SearchBarWidget مستقل
            const SearchBarWidget(),
            const SizedBox(height: 12),
            CategoryGrid(
              categories: _realCategories,
              onCategoryTap: (category) {
                context.push(
                  RoutePaths.subCategories,
                  extra: {
                    'parentId': category['id'],
                    'categoryName': category['name'],
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            MainWideBanner(bannerController: _bannerPageController),

            // ===== بنر الحملة الموسمية =====
            if (_campaign != null &&
                (_campaign!['banner_image'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/campaign'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: AspectRatio(
                      aspectRatio: 30 / 7,
                      child: Image.network(
                        _campaign!['banner_image'].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            if (_flashSaleProducts.isNotEmpty)
              _buildSection("عروض الـ 24 ساعة", _flashSaleProducts),

            // عروض مختارة — من المتاجر الاحترافية
            if (_curatedProducts.isNotEmpty)
              _buildSection("عروض مختارة", _curatedProducts),

            SmallBannersRow(smallBannerController: _smallBannerPageController),
            if (_merchantsList.isNotEmpty)
              MerchantCircleList(merchants: _merchantsList),
            if (_newArrivals.isNotEmpty)
              _buildSection("مضافة حديثاً", _newArrivals),
            if (_followedProducts.isNotEmpty)
              _buildSection("جديد متاجرك", _followedProducts),

            // خمسة تصنيفات عشوائية بعروضها
            ..._categoryShowcase.map((cat) {
              final products = (cat['products'] as List?) ?? [];
              if (products.isEmpty) return const SizedBox.shrink();
              final list = products
                  .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
                  .toList();
              return _buildSection((cat['name'] ?? 'تصنيف').toString(), list);
            }),
            if (recentlyViewedItems.isNotEmpty)
              _buildSection("شاهدتهـا مؤخـراً", recentlyViewedItems),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 25, 16, 10),
              child: Text("اكتشف المزيد",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo')),
            ),
            InfiniteProductsGrid(scrollController: _scrollController),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartHeader() {
    final user = supabase.auth.currentUser;
    final userRole = ref.watch(userRoleProvider);
    final bool isLoggedIn =
        user != null || (userRole != null && userRole != 'customer_guest');
    final bool isAdmin = userRole == 'super_admin';
    final bool isMerchant = userRole == 'merchant';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png',
              height: 35,
              errorBuilder: (c, e, s) =>
                  const Icon(Icons.store, color: Color(0xFFD32027))),
          const Spacer(),
          GestureDetector(
            onTap: () {
              final current = ref.read(appThemeModeProvider);
              ref.read(appThemeModeProvider.notifier).state =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFD32027).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ref.watch(appThemeModeProvider) == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: const Color(0xFFD32027),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () => isLoggedIn ? _handleLogout() : _protectedAction(() {}),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("مرحباً",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.grey,
                            height: 1)),
                    Text(
                      isLoggedIn && user != null
                          ? (isMerchant && _merchantStoreName != null
                              ? _merchantStoreName!
                              : (user.userMetadata?['full_name'] ?? "المستخدم"))
                          : "تسجيل الدخول",
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(isLoggedIn ? Icons.logout_rounded : Icons.person_outline,
                    color: const Color(0xFFD32027), size: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<ProductModel> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
        ),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) =>
                ProductCard(product: products[index], width: 140),
          ),
        ),
      ],
    );
  }
}
