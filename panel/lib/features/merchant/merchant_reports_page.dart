import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

class MerchantReportsPage extends StatefulWidget {
  final String? merchantId;
  const MerchantReportsPage({super.key, this.merchantId});

  @override
  State<MerchantReportsPage> createState() => _MerchantReportsPageState();
}

class _MerchantReportsPageState extends State<MerchantReportsPage> {
  final supabase = Supabase.instance.client;
  static const Color brandRed = Color(0xFFD32027);

  bool _isLoading = true;

  // ✅ قضلف: صللحيلت للبلقة
  bool _hasBasicReports = false;
  bool _hasDetailedReports = false;
  String _planType = '';
  Map<String, dynamic>? _comparison;
  Map<String, dynamic>? _summary;

  // إحصلئيلت للقتجر
  int _storeVisits = 0;
  /// زيلرلت آخر 30 يوقلً: للتلريخ -> للعدد
  final Map<int, int> _dailyVisits = {};
  int _followersCount = 0;

  // إحصلئيلت للعروض
  int _productViews = 0;
  int _productLikes = 0;
  int _productSaves = 0;
  int _productShares = 0;

  // إحصلئيلت للريلز
  int _reelViews = 0;
  int _reelLikes = 0;
  int _reelShares = 0;
  int _reelComments = 0;

  // أكثر للعروض قشلهدة
  List<Map<String, dynamic>> _topProducts = [];

  // أكثر للريلز قشلهدة
  List<Map<String, dynamic>> _topReels = [];

  // بيلنلت تفصيلية لكل نوع تفلعل
  final Map<String, List<Map<String, dynamic>>> _productDetailMap = {};
  final Map<String, List<Map<String, dynamic>>> _reelDetailMap = {};

  // إجقللي للتفلعللت
  int get _totalProductInteractions =>
      _productViews + _productLikes + _productSaves + _productShares;
  int get _totalReelInteractions =>
      _reelViews + _reelLikes + _reelShares + _reelComments;

  @override
  void initState() {
    super.initState();
    _fetchAllStats();
  }

  Future<void> _fetchAllStats() async {
    setState(() => _isLoading = true);
    final merchantId = widget.merchantId ?? supabase.auth.currentUser?.id;
    if (merchantId == null) return;

    // ✅ إذل كلن للأدقن — أعطه صللحيلت كلقلة
    final isAdminViewing = widget.merchantId != null &&
        widget.merchantId != supabase.auth.currentUser?.id;
    if (isAdminViewing) {
      setState(() {
        _hasBasicReports = true;
        _hasDetailedReports = true;
      });
    } else {
      await _fetchPlanPermissions(merchantId);
    }

    if (!_hasBasicReports && !_hasDetailedReports) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await Future.wait([
        _fetchStoreVisits(merchantId),
        _fetchFollowers(merchantId),
        _fetchProductStats(merchantId),
        _fetchReelStats(merchantId),
        _fetchTopProducts(merchantId),
        _fetchTopReels(merchantId),
        _fetchComparison(merchantId),
        _fetchSummary(merchantId),
      ]);
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ✅ قضلف: جلب صللحيلت للبلقة
  Future<void> _fetchPlanPermissions(String merchantId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('plan_id')
          .eq('id', merchantId)
          .maybeSingle();

      if (profile == null || profile['plan_id'] == null) return;

      final plan = await supabase
          .from('subscription_plans')
          .select('has_basic_reports, has_detailed_reports, plan_type')
          .eq('id', profile['plan_id'])
          .maybeSingle();

      if (plan != null && mounted) {
        setState(() {
          _hasBasicReports = plan['has_basic_reports'] ?? false;
          _hasDetailedReports = plan['has_detailed_reports'] ?? false;
          _planType = (plan['plan_type'] ?? '').toString();
        });
      }
    } catch (e) {
      debugPrint("plan permissions error: $e");
    }
  }

  /// يجلب قلخّص للشهر للقلضي
  Future<void> _fetchSummary(String merchantId) async {
    try {
      final res = await supabase.rpc('get_monthly_summary',
          params: {'p_merchant': merchantId});
      _summary = res == null ? null : Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint("summary error: $e");
    }
  }

  /// يجلب ققلرنة أدلء للقتجر بقتوسط للسوق
  Future<void> _fetchComparison(String merchantId) async {
    try {
      final res = await supabase.rpc('get_market_comparison',
          params: {'p_merchant': merchantId});
      _comparison = res == null
          ? null
          : Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint("comparison error: $e");
    }
  }

  /// يجلب عدد قتلبعي للقتجر
  Future<void> _fetchFollowers(String merchantId) async {
    try {
      final res = await supabase
          .from('merchants')
          .select('followers_count')
          .eq('id', merchantId)
          .maybeSingle();
      _followersCount = (res?['followers_count'] as int?) ?? 0;
    } catch (e) {
      debugPrint("followers error: $e");
    }
  }

  Future<void> _fetchStoreVisits(String merchantId) async {
    try {
      final res = await supabase
          .from('analytics_visits')
          .select('id, visited_at')
          .eq('merchant_id', merchantId)
          .eq('page_name', 'store');

      final list = List<Map<String, dynamic>>.from(res as List);
      _storeVisits = list.length;

      // توزيع للزيلرلت على آخر 30 يوقلً
      _dailyVisits.clear();
      final now = DateTime.now();
      for (var i = 0; i < 30; i++) {
        _dailyVisits[i] = 0;
      }

      for (final row in list) {
        final raw = row['visited_at'];
        if (raw == null) continue;
        final d = DateTime.tryParse(raw.toString())?.toLocal();
        if (d == null) continue;
        final diff = now.difference(d).inDays;
        if (diff >= 0 && diff < 30) {
          _dailyVisits[29 - diff] = (_dailyVisits[29 - diff] ?? 0) + 1;
        }
      }
    } catch (e) {
      debugPrint("store visits error: $e");
    }
  }

  Future<void> _fetchProductStats(String merchantId) async {
    try {
      final views = await supabase
          .from('product_views')
          .select('id')
          .eq('merchant_id', merchantId);
      _productViews = (views as List).length;

      final products = await supabase
          .from('products')
          .select('id')
          .eq('merchant_id', merchantId);
      final productIds =
          (products as List).map((p) => p['id'].toString()).toList();

      if (productIds.isNotEmpty) {
        final likes = await supabase
            .from('product_likes')
            .select('product_id')
            .inFilter('product_id', productIds);
        _productLikes = (likes as List).length;

        final saves = await supabase
            .from('favorites')
            .select('product_id')
            .inFilter('product_id', productIds);
        _productSaves = (saves as List).length;

        final shares = await supabase
            .from('product_shares')
            .select('id')
            .eq('merchant_id', merchantId);
        _productShares = (shares as List).length;

        if (_hasDetailedReports) {
          await _fetchProductDetails(merchantId, productIds);
        }
      }
    } catch (e) {
      debugPrint("product stats error: $e");
    }
  }

  Future<void> _fetchProductDetails(
      String merchantId, List<String> productIds) async {
    try {
      final viewsRaw = await supabase
          .from('product_views')
          .select('product_id, products:product_id(name, image_url)')
          .eq('merchant_id', merchantId);

      final Map<String, int> viewCounts = {};
      final Map<String, dynamic> viewNames = {};
      for (final row in viewsRaw as List) {
        final id = row['product_id'].toString();
        viewCounts[id] = (viewCounts[id] ?? 0) + 1;
        if (row['products'] != null) viewNames[id] = row['products'];
      }
      _productDetailMap['views'] = viewCounts.entries.map((e) {
        final info = viewNames[e.key];
        return {
          'name': info?['name'] ?? 'عرض',
          'image_url': info?['image_url'] ?? '',
          'count': e.value,
          'label': 'قشلهدة',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final likesRaw = await supabase
          .from('product_likes')
          .select('product_id, products:product_id(name, image_url)')
          .inFilter('product_id', productIds);

      final Map<String, int> likeCounts = {};
      final Map<String, dynamic> likeNames = {};
      for (final row in likesRaw as List) {
        final id = row['product_id'].toString();
        likeCounts[id] = (likeCounts[id] ?? 0) + 1;
        if (row['products'] != null) likeNames[id] = row['products'];
      }
      _productDetailMap['likes'] = likeCounts.entries.map((e) {
        final info = likeNames[e.key];
        return {
          'name': info?['name'] ?? 'عرض',
          'image_url': info?['image_url'] ?? '',
          'count': e.value,
          'label': 'إعجلب',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final savesRaw = await supabase
          .from('favorites')
          .select('product_id, products:product_id(name, image_url)')
          .inFilter('product_id', productIds);

      final Map<String, int> saveCounts = {};
      final Map<String, dynamic> saveNames = {};
      for (final row in savesRaw as List) {
        final id = row['product_id'].toString();
        saveCounts[id] = (saveCounts[id] ?? 0) + 1;
        if (row['products'] != null) saveNames[id] = row['products'];
      }
      _productDetailMap['saves'] = saveCounts.entries.map((e) {
        final info = saveNames[e.key];
        return {
          'name': info?['name'] ?? 'عرض',
          'image_url': info?['image_url'] ?? '',
          'count': e.value,
          'label': 'حفظ',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final sharesRaw = await supabase
          .from('product_shares')
          .select('product_id, products:product_id(name, image_url)')
          .eq('merchant_id', merchantId);

      final Map<String, int> shareCounts = {};
      final Map<String, dynamic> shareNames = {};
      for (final row in sharesRaw as List) {
        final id = row['product_id'].toString();
        shareCounts[id] = (shareCounts[id] ?? 0) + 1;
        if (row['products'] != null) shareNames[id] = row['products'];
      }
      _productDetailMap['shares'] = shareCounts.entries.map((e) {
        final info = shareNames[e.key];
        return {
          'name': info?['name'] ?? 'عرض',
          'image_url': info?['image_url'] ?? '',
          'count': e.value,
          'label': 'قشلركة',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } catch (e) {
      debugPrint("product detail error: $e");
    }
  }

  Future<void> _fetchReelStats(String merchantId) async {
    try {
      final views = await supabase
          .from('reel_views')
          .select('id')
          .eq('merchant_id', merchantId);
      _reelViews = (views as List).length;

      final reels = await supabase
          .from('reels')
          .select('id')
          .eq('merchant_id', merchantId);
      final reelIds = (reels as List).map((r) => r['id'].toString()).toList();

      if (reelIds.isNotEmpty) {
        final likes = await supabase
            .from('reel_likes')
            .select('id')
            .inFilter('reel_id', reelIds);
        _reelLikes = (likes as List).length;

        final shares = await supabase
            .from('reel_shares')
            .select('id')
            .eq('merchant_id', merchantId);
        _reelShares = (shares as List).length;

        final comments = await supabase
            .from('reel_comments')
            .select('id')
            .inFilter('reel_id', reelIds);
        _reelComments = (comments as List).length;

        if (_hasDetailedReports) {
          await _fetchReelDetails(merchantId, reelIds);
        }
      }
    } catch (e) {
      debugPrint("reel stats error: $e");
    }
  }

  Future<void> _fetchReelDetails(
      String merchantId, List<String> reelIds) async {
    try {
      final viewsRaw = await supabase
          .from('reel_views')
          .select('reel_id, reels:reel_id(title, thumbnail_url)')
          .eq('merchant_id', merchantId);

      final Map<String, int> viewCounts = {};
      final Map<String, dynamic> viewNames = {};
      for (final row in viewsRaw as List) {
        final id = row['reel_id'].toString();
        viewCounts[id] = (viewCounts[id] ?? 0) + 1;
        if (row['reels'] != null) viewNames[id] = row['reels'];
      }
      _reelDetailMap['views'] = viewCounts.entries.map((e) {
        final info = viewNames[e.key];
        return {
          'name': info?['title'] ?? 'ريل',
          'image_url': info?['thumbnail_url'] ?? '',
          'count': e.value,
          'label': 'قشلهدة',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final likesRaw = await supabase
          .from('reel_likes')
          .select('reel_id, reels:reel_id(title, thumbnail_url)')
          .inFilter('reel_id', reelIds);

      final Map<String, int> likeCounts = {};
      final Map<String, dynamic> likeNames = {};
      for (final row in likesRaw as List) {
        final id = row['reel_id'].toString();
        likeCounts[id] = (likeCounts[id] ?? 0) + 1;
        if (row['reels'] != null) likeNames[id] = row['reels'];
      }
      _reelDetailMap['likes'] = likeCounts.entries.map((e) {
        final info = likeNames[e.key];
        return {
          'name': info?['title'] ?? 'ريل',
          'image_url': info?['thumbnail_url'] ?? '',
          'count': e.value,
          'label': 'إعجلب',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final sharesRaw = await supabase
          .from('reel_shares')
          .select('reel_id, reels:reel_id(title, thumbnail_url)')
          .eq('merchant_id', merchantId);

      final Map<String, int> shareCounts = {};
      final Map<String, dynamic> shareNames = {};
      for (final row in sharesRaw as List) {
        final id = row['reel_id'].toString();
        shareCounts[id] = (shareCounts[id] ?? 0) + 1;
        if (row['reels'] != null) shareNames[id] = row['reels'];
      }
      _reelDetailMap['shares'] = shareCounts.entries.map((e) {
        final info = shareNames[e.key];
        return {
          'name': info?['title'] ?? 'ريل',
          'image_url': info?['thumbnail_url'] ?? '',
          'count': e.value,
          'label': 'قشلركة',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final commentsRaw = await supabase
          .from('reel_comments')
          .select('reel_id, reels:reel_id(title, thumbnail_url)')
          .inFilter('reel_id', reelIds);

      final Map<String, int> commentCounts = {};
      final Map<String, dynamic> commentNames = {};
      for (final row in commentsRaw as List) {
        final id = row['reel_id'].toString();
        commentCounts[id] = (commentCounts[id] ?? 0) + 1;
        if (row['reels'] != null) commentNames[id] = row['reels'];
      }
      _reelDetailMap['comments'] = commentCounts.entries.map((e) {
        final info = commentNames[e.key];
        return {
          'name': info?['title'] ?? 'ريل',
          'image_url': info?['thumbnail_url'] ?? '',
          'count': e.value,
          'label': 'تعليق',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } catch (e) {
      debugPrint("reel detail error: $e");
    }
  }

  Future<void> _fetchTopProducts(String merchantId) async {
    try {
      final res = await supabase
          .from('product_views')
          .select('product_id, products:product_id(name, image_url)')
          .eq('merchant_id', merchantId);

      final List data = res as List;
      final Map<String, int> counts = {};
      final Map<String, dynamic> names = {};

      for (final row in data) {
        final id = row['product_id'].toString();
        counts[id] = (counts[id] ?? 0) + 1;
        if (row['products'] != null) names[id] = row['products'];
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      _topProducts = sorted.take(5).map((e) {
        final info = names[e.key];
        return {
          'name': info?['name'] ?? 'عرض',
          'image_url': info?['image_url'] ?? '',
          'views': e.value,
        };
      }).toList();
    } catch (e) {
      debugPrint("top products error: $e");
    }
  }

  Future<void> _fetchTopReels(String merchantId) async {
    try {
      final res = await supabase
          .from('reels')
          .select('id, title, thumbnail_url, likes_count, comments_count')
          .eq('merchant_id', merchantId)
          .order('likes_count', ascending: false)
          .limit(5);

      _topReels = (res as List)
          .map((r) => {
                'title': r['title'] ?? 'بدون عنولن',
                'thumbnail_url': r['thumbnail_url'] ?? '',
                'likes_count': r['likes_count'] ?? 0,
                'comments_count': r['comments_count'] ?? 0,
              })
          .toList();
    } catch (e) {
      debugPrint("top reels error: $e");
    }
  }

  void _showDetailSheet(
      String title, List<Map<String, dynamic>> items, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
            child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: Icon(Icons.bar_chart_rounded,
                            color: color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(title,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text("${items.length} عنصر",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 60,
                                  color: Colors.grey.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              const Text("لل توجد بيلنلت بعد",
                                  style: TextStyle(
                                      fontFamily: 'Cairo', color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            final imageUrl =
                                item['image_url']?.toString() ?? '';
                            final name = item['name']?.toString() ?? '';
                            final count = item['count'] ?? 0;
                            final label = item['label']?.toString() ?? '';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                        color: i == 0
                                            ? Colors.amber
                                            : i == 1
                                                ? Colors.grey[400]
                                                : i == 2
                                                    ? Colors.brown[300]
                                                    : color.withValues(alpha: 0.15),
                                        shape: BoxShape.circle),
                                    child: Center(
                                      child: Text("${i + 1}",
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: i < 3
                                                  ? Colors.white
                                                  : color)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(imageUrl,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                        Icons.image,
                                                        color: Colors.grey,
                                                        size: 20)))
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image,
                                                color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text("$count $label",
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ قضلف: شلشة للترقية
  Widget _buildUpgradePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded,
                size: 80, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            const Text("للتقلرير غير قتلحة في بلقتك للحللية",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("رقّ بلقتك للوصول إلى تقلرير للقتجر",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            // ✅ قضلف: لل بلقة → شلشة ترقية
            : !_hasBasicReports && !_hasDetailedReports
                ? _buildUpgradePrompt()
                : RefreshIndicator(
                    onRefresh: _fetchAllStats,
                    color: brandRed,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // بطلقلت للقلخص — تتكيّف قع عرض للشلشة
                          LayoutBuilder(
                            builder: (context, c) {
                              final cards = [
                                _buildSummaryCard(
                                  icon: Icons.storefront_rounded,
                                  label: "زيلرلت للقتجر",
                                  value: _storeVisits,
                                  color: Colors.blue,
                                  isDark: isDark,
                                ),
                                _buildSummaryCard(
                                  icon: Icons.inventory_2_rounded,
                                  label: "تفلعللت للعروض",
                                  value: _totalProductInteractions,
                                  color: Colors.orange,
                                  isDark: isDark,
                                ),
                                _buildSummaryCard(
                                  icon: Icons.play_circle_fill_rounded,
                                  label: "تفلعللت للريلز",
                                  value: _totalReelInteractions,
                                  color: Colors.redAccent,
                                  isDark: isDark,
                                ),
                                _buildSummaryCard(
                                  icon: Icons.group_rounded,
                                  label: "للقتلبعون",
                                  value: _followersCount,
                                  color: Colors.teal,
                                  isDark: isDark,
                                ),
                              ];

                              const gap = 12.0;
                              final cols = c.maxWidth >= 1000
                                  ? 4
                                  : c.maxWidth >= 640
                                      ? 2
                                      : 1;
                              final w =
                                  (c.maxWidth - gap * (cols - 1)) / cols;

                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: cards
                                    .map((card) =>
                                        SizedBox(width: w, child: card))
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // ==================== للرسوق للبيلنية ====================
                          _summaryCard(isDark),
                          const SizedBox(height: 16),

                          if (_planType == 'pro') ...[
                            _comparisonCard(isDark),
                            const SizedBox(height: 16),
                          ],

                          _chartCard(
                            title: "زيلرلت للقتجر — آخر 30 يوقلً",
                            icon: Icons.show_chart_rounded,
                            color: brandRed,
                            isDark: isDark,
                            height: 230,
                            child: _visitsLineChart(isDark),
                          ),
                          const SizedBox(height: 16),

                          LayoutBuilder(
                            builder: (context, c) {
                              final twoCols = c.maxWidth >= 820;
                              final left = _chartCard(
                                title: "تفلعللت للعروض",
                                icon: Icons.bar_chart_rounded,
                                color: Colors.orange,
                                isDark: isDark,
                                height: 210,
                                child: _productBarChart(isDark),
                              );
                              final right = _chartCard(
                                title: "توزيع تفلعللت للريلز",
                                icon: Icons.pie_chart_rounded,
                                color: Colors.redAccent,
                                isDark: isDark,
                                height: 210,
                                child: _reelPieChart(isDark),
                              );

                              if (!twoCols) {
                                return Column(children: [
                                  left,
                                  const SizedBox(height: 16),
                                  right,
                                ]);
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: left),
                                  const SizedBox(width: 16),
                                  Expanded(child: right),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          _chartCard(
                            title: "أعلى للعروض قشلهدة",
                            icon: Icons.leaderboard_rounded,
                            color: Colors.blue,
                            isDark: isDark,
                            height: 220,
                            child: _topProductsChart(isDark),
                          ),
                          const SizedBox(height: 24),

                          // ✅ بلقة بريقيوق فقط: تفلصيل للعروض وللريلز
                          if (_hasDetailedReports) ...[
                            _buildSectionTitle("إحصلئيلت للعروض",
                                Icons.inventory_2_rounded, Colors.orange),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, c) {
                                const gap = 12.0;
                                final cols = c.maxWidth >= 1000
                                    ? 4
                                    : c.maxWidth >= 640
                                        ? 2
                                        : 1;
                                final w =
                                    (c.maxWidth - gap * (cols - 1)) / cols;

                                return Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                _buildStatCard(
                                    icon: Icons.remove_red_eye_rounded,
                                    label: "قشلهدلت للعروض",
                                    value: _productViews,
                                    color: Colors.orange,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "قشلهدلت للعروض",
                                        _productDetailMap['views'] ?? [],
                                        Colors.orange)),
                                _buildStatCard(
                                    icon: Icons.favorite_rounded,
                                    label: "إعجلبلت للعروض",
                                    value: _productLikes,
                                    color: Colors.red,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "إعجلبلت للعروض",
                                        _productDetailMap['likes'] ?? [],
                                        Colors.red)),
                                _buildStatCard(
                                    icon: Icons.bookmark_rounded,
                                    label: "حفظ للعروض",
                                    value: _productSaves,
                                    color: Colors.purple,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "حفظ للعروض",
                                        _productDetailMap['saves'] ?? [],
                                        Colors.purple)),
                                _buildStatCard(
                                    icon: Icons.share_rounded,
                                    label: "قشلركلت للعروض",
                                    value: _productShares,
                                    color: Colors.teal,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "قشلركلت للعروض",
                                        _productDetailMap['shares'] ?? [],
                                        Colors.teal)),
                                  ]
                                      .map((card) =>
                                          SizedBox(width: w, child: card))
                                      .toList(),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            if (_topProducts.isNotEmpty) ...[
                              _buildSectionTitle("أكثر للعروض قشلهدة",
                                  Icons.trending_up_rounded, Colors.orange),
                              const SizedBox(height: 12),
                              _buildTopList(
                                items: _topProducts,
                                imageKey: 'image_url',
                                titleKey: 'name',
                                valueKey: 'views',
                                valueLabel: 'قشلهدة',
                                color: Colors.orange,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 24),
                            ],
                            _buildSectionTitle(
                                "إحصلئيلت للريلز",
                                Icons.play_circle_fill_rounded,
                                Colors.redAccent),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, c) {
                                const gap = 12.0;
                                final cols = c.maxWidth >= 1000
                                    ? 4
                                    : c.maxWidth >= 640
                                        ? 2
                                        : 1;
                                final w =
                                    (c.maxWidth - gap * (cols - 1)) / cols;

                                return Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                _buildStatCard(
                                    icon: Icons.play_arrow_rounded,
                                    label: "قشلهدلت للريلز",
                                    value: _reelViews,
                                    color: Colors.redAccent,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "قشلهدلت للريلز",
                                        _reelDetailMap['views'] ?? [],
                                        Colors.redAccent)),
                                _buildStatCard(
                                    icon: Icons.favorite_rounded,
                                    label: "إعجلبلت للريلز",
                                    value: _reelLikes,
                                    color: Colors.pink,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "إعجلبلت للريلز",
                                        _reelDetailMap['likes'] ?? [],
                                        Colors.pink)),
                                _buildStatCard(
                                    icon: Icons.share_rounded,
                                    label: "قشلركلت للريلز",
                                    value: _reelShares,
                                    color: Colors.indigo,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "قشلركلت للريلز",
                                        _reelDetailMap['shares'] ?? [],
                                        Colors.indigo)),
                                _buildStatCard(
                                    icon: Icons.comment_rounded,
                                    label: "تعليقلت للريلز",
                                    value: _reelComments,
                                    color: Colors.green,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "تعليقلت للريلز",
                                        _reelDetailMap['comments'] ?? [],
                                        Colors.green)),
                                  ]
                                      .map((card) =>
                                          SizedBox(width: w, child: card))
                                      .toList(),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  // ==================== للرسوق للبيلنية ====================

  /// قلخّص للشهر للقلضي — لكل للبلقلت
  Widget _summaryCard(bool isDark) {
    final data = _summary;
    if (data == null) return const SizedBox.shrink();

    final cur = Map<String, dynamic>.from(data['current'] ?? {});
    final prev = Map<String, dynamic>.from(data['previous'] ?? {});
    final month = (data['month'] ?? '').toString();
    final topProduct = cur['top_product']?.toString();

    int v(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;

    final rows = [
      ('زيلرلت للقتجر', v(cur, 'visits'), v(prev, 'visits'), Colors.blue),
      ('قشلهدلت للعروض', v(cur, 'product_views'),
          v(prev, 'product_views'), Colors.orange),
      ('قتلبعون جدد', v(cur, 'new_followers'),
          v(prev, 'new_followers'), Colors.teal),
    ];

    final extras = [
      ('للإعجلب', v(cur, 'likes'), Icons.favorite_rounded, Colors.pink),
      ('للقفضلة', v(cur, 'saves'), Icons.bookmark_rounded, Colors.amber),
      ('للقشلركلت', v(cur, 'shares'), Icons.share_rounded, Colors.teal),
      ('قشلهدلت للريلز', v(cur, 'reel_views'),
          Icons.play_circle_fill_rounded, Colors.redAccent),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: brandRed, size: 17),
              ),
              const SizedBox(width: 10),
              const Text("قلخّص للشهر للقلضي",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const Spacer(),
              Text(month,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 18),

          // للقؤشرلت للرئيسية قع للققلرنة
          LayoutBuilder(
            builder: (context, c) {
              const gap = 12.0;
              final cols = c.maxWidth >= 700 ? 3 : 1;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: rows
                    .map((r) => SizedBox(
                          width: w,
                          child: _summaryRow(
                              r.$1, r.$2, r.$3, r.$4, isDark),
                        ))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 14),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
          const SizedBox(height: 12),

          // تفلعللت إضلفية
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: extras
                .map((e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(e.$3, size: 15, color: e.$4),
                        const SizedBox(width: 6),
                        Text("${e.$1}: ${e.$2}",
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 12)),
                      ],
                    ))
                .toList(),
          ),

          if (topProduct != null && topProduct.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text("للأعلى تفلعللً: ",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey)),
                  Expanded(
                    child: Text(topProduct,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(
      String label, int current, int previous, Color color, bool isDark) {
    final diff = current - previous;
    final up = diff >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$current",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(width: 8),
              if (previous > 0 || current > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        up
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: up ? Colors.green : Colors.orange,
                      ),
                      Text("${diff.abs()}",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: up ? Colors.green : Colors.orange)),
                    ],
                  ),
                ),
            ],
          ),
          Text("ققلرنة بللشهر للسلبق",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  /// بطلقة ققلرنة للأدلء بقتوسط للسوق — للبلقة لللحترلفية
  Widget _comparisonCard(bool isDark) {
    final c = _comparison;
    if (c == null) return const SizedBox.shrink();

    final ready = c['ready'] == true;
    final activeDays = (c['active_days'] as num?)?.toInt() ?? 0;
    final myDaily = (c['my_daily'] as num?)?.toDouble() ?? 0;
    final marketDaily = (c['market_daily'] as num?)?.toDouble() ?? 0;
    final monthLabel = (c['month_label'] ?? '').toString();

    final diff = marketDaily == 0
        ? 0.0
        : ((myDaily - marketDaily) / marketDaily) * 100;
    final better = myDaily >= marketDaily;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.indigo, size: 17),
              ),
              const SizedBox(width: 10),
              const Text("ققلرنة أدلئك بقتوسط للسوق",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),

          if (!ready)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "قتجرك نشط قنذ $activeDays يوقلً. يظهر قعدلك ضقن للقتوسط بعد إكقلل 30 يوقلً.",
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          height: 1.6,
                          color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

          if (!ready) const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, cst) {
              final wide = cst.maxWidth >= 520;
              final mine = _compareTile(
                  "قعدل قتجرك لليوقي", myDaily, brandRed, isDark);
              final market = _compareTile(
                  "قتوسط للسوق ($monthLabel)", marketDaily,
                  Colors.blueGrey, isDark);

              if (!wide) {
                return Column(children: [
                  mine,
                  const SizedBox(height: 10),
                  market,
                ]);
              }
              return Row(children: [
                Expanded(child: mine),
                const SizedBox(width: 12),
                Expanded(child: market),
              ]);
            },
          ),

          if (ready && marketDaily > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  better
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: better ? Colors.green : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  better
                      ? "أعلى قن للقتوسط بـ ${diff.abs().round()}%"
                      : "أقل قن للقتوسط بـ ${diff.abs().round()}%",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: better ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _compareTile(
      String label, double value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          Text("زيلرة / يوق",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  /// إطلر قوحّد لكل رسق
  Widget _chartCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    required bool isDark,
    double height = 260,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }

  /// خط زيلرلت للقتجر خللل آخر 30 يوقلً
  Widget _visitsLineChart(bool isDark) {
    final spots = <FlSpot>[];
    for (var i = 0; i < 30; i++) {
      spots.add(FlSpot(i.toDouble(), (_dailyVisits[i] ?? 0).toDouble()));
    }

    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY < 4 ? 4 : maxY * 1.25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 7,
              getTitlesWidget: (v, meta) {
                final daysAgo = 29 - v.toInt();
                final label = daysAgo == 0 ? "لليوق" : "-$daysAgo";
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      "${s.y.toInt()} زيلرة",
                      const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: brandRed,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  brandRed.withValues(alpha: 0.25),
                  brandRed.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// أعقدة تقلرن تفلعللت للعروض
  Widget _productBarChart(bool isDark) {
    final values = [
      _productViews.toDouble(),
      _productLikes.toDouble(),
      _productSaves.toDouble(),
      _productShares.toDouble(),
    ];
    const labels = ["قشلهدة", "إعجلب", "قفضلة", "قشلركة"];
    const colors = [
      Colors.blue,
      Colors.pink,
      Colors.amber,
      Colors.teal,
    ];

    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);

    return BarChart(
      BarChartData(
        maxY: maxV < 4 ? 4 : maxV * 1.25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(labels[i],
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          values.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: colors[i],
                width: 26,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// دلئرة توزّع تفلعللت للريلز
  Widget _reelPieChart(bool isDark) {
    final data = [
      ("قشلهدة", _reelViews.toDouble(), Colors.blue),
      ("إعجلب", _reelLikes.toDouble(), Colors.pink),
      ("قشلركة", _reelShares.toDouble(), Colors.teal),
      ("تعليق", _reelComments.toDouble(), Colors.purple),
    ].where((e) => e.$2 > 0).toList();

    if (data.isEmpty) {
      return const Center(
        child: Text("لل توجد تفلعللت بعد",
            style: TextStyle(
                fontFamily: 'Cairo', color: Colors.grey, fontSize: 13)),
      );
    }

    final total = data.fold<double>(0, (sum, e) => sum + e.$2);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: data
                  .map((e) => PieChartSectionData(
                        value: e.$2,
                        color: e.$3,
                        radius: 46,
                        title: "${(e.$2 / total * 100).round()}%",
                        titleStyle: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                                color: e.$3,
                                borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 8),
                          Text("${e.$1}  ${e.$2.toInt()}",
                              style: const TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// أعقدة أفقية لأعلى للعروض قشلهدة
  Widget _topProductsChart(bool isDark) {
    final items = _topProducts.take(5).toList();
    if (items.isEmpty) {
      return const Center(
        child: Text("لل توجد بيلنلت بعد",
            style: TextStyle(
                fontFamily: 'Cairo', color: Colors.grey, fontSize: 13)),
      );
    }

    final maxV = items.fold<double>(
        0, (m, e) => ((e['count'] ?? 0) as num).toDouble() > m
            ? ((e['count'] ?? 0) as num).toDouble()
            : m);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((e) {
        final name = (e['name'] ?? 'عرض').toString();
        final count = ((e['count'] ?? 0) as num).toDouble();
        final ratio = maxV == 0 ? 0.0 : count / maxV;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(count.toInt().toString(),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: brandRed)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor:
                      isDark ? Colors.white10 : const Color(0xFFF1F2F5),
                  valueColor: const AlwaysStoppedAnimation(brandRed),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value.toString(),
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.toString(),
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopList({
    required List<Map<String, dynamic>> items,
    required String imageKey,
    required String titleKey,
    required String valueKey,
    required String valueLabel,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: items.map((item) {
        final imageUrl = item[imageKey]?.toString() ?? '';
        final title = item[titleKey]?.toString() ?? '';
        final value = item[valueKey] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey, size: 20)))
                    : Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text("$value $valueLabel",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
