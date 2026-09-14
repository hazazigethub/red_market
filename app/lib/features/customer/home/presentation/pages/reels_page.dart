import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/core/widgets/comments_sheet.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/features/customer/home/presentation/pages/reels_search_page.dart';
import 'package:flutter/services.dart';

class PhoneIcon extends StatelessWidget {
  final double size;
  final Color color;
  const PhoneIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.55, size),
      painter: PhoneIconPainter(color: color),
    );
  }
}

class PhoneIconPainter extends CustomPainter {
  final Color color;
  const PhoneIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;

    final double r = size.width * 0.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(r)),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.06),
      Offset(size.width * 0.7, size.height * 0.06),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(PhoneIconPainter old) => old.color != color;
}

class ReelsPage extends StatefulWidget {
  final List<ReelModel>? reels;
  const ReelsPage({super.key, this.reels});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final PageController _pageController = PageController();
  final TextEditingController _commentController = TextEditingController();

  bool _isCommenting = false;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentOffset = 0;
  final int _batchSize = 5;

  List<ReelModel> _reelsList = [];

  final Set<String> _viewedReelIds = <String>{};
  bool _viewsLoaded = false;
  bool _allReelsSeen = false;

  final Set<String> _markingNow = <String>{};
  final Random _rng = Random();

  int _currentPageIndex = 0;
  final Map<String, bool> _likedReels = {};
  final Map<String, int> _reelLikeCounts = {};
  final Map<String, int> _reelCommentCounts = {};
  final Map<String, int> _reelShareCounts = {};
  final Map<String, bool> _savedReels = {};
  final Map<String, int> _reelSaveCounts = {};
  final Map<String, int> _reelViewCounts = {};
  final Map<String, double?> _productPrices = {};
  final Map<String, double?> _productOldPrices = {};

  bool _isMuted = false;
  bool _isGridView = false;

  final Map<int, GlobalKey<_VideoPlayerWidgetState>> _videoKeys = {};

  @override
  void initState() {
    super.initState();
    // ✅ تغيير لون الشريط السفلي إلى الداكن
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    if (widget.reels != null && widget.reels!.isNotEmpty) {
      _reelsList = widget.reels!;
      _isLoadingInitial = false;
      _hasMoreData = false;
      _primeViewsAndSeenState();
    } else {
      _primeViewsAndSeenState().then((_) => _fetchReels(isLoadMore: false));
    }
  }

  @override
  void dispose() {
    // ✅ إعادة لون الشريط السفلي عند الخروج
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _primeViewsAndSeenState() async {
    await _loadViewedReelIds();
    await _checkAllReelsSeen();
    await _loadLikedReels();
    await _loadSavedReels();
    await _loadShareCounts();
  }

  Future<void> _loadLikedReels() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await supabase
          .from('reel_likes')
          .select('reel_id')
          .eq('user_id', userId);
      for (final row in res as List) {
        _likedReels[row['reel_id'].toString()] = true;
      }
    } catch (e) {
      debugPrint("Error loading liked reels: $e");
    }
  }

  Future<void> _loadSavedReels() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await supabase
          .from('reel_saves')
          .select('reel_id')
          .eq('user_id', userId);
      for (final row in res as List) {
        _savedReels[row['reel_id'].toString()] = true;
      }
    } catch (e) {
      debugPrint("Error loading saved reels: $e");
    }
  }

  Future<void> _loadShareCounts() async {
    try {
      final res = await supabase.from('reel_shares').select('reel_id');
      final Map<String, int> counts = {};
      for (final row in res as List) {
        final id = row['reel_id'].toString();
        counts[id] = (counts[id] ?? 0) + 1;
      }
      if (mounted)
        setState(() => counts.forEach((k, v) => _reelShareCounts[k] = v));
    } catch (e) {
      debugPrint("Error loading share counts: $e");
    }
  }

  Future<void> _loadRealCounts(List<String> reelIds) async {
    if (reelIds.isEmpty) return;
    try {
      final views = await supabase
          .from('reel_views')
          .select('reel_id')
          .inFilter('reel_id', reelIds);
      final Map<String, int> viewCounts = {};
      for (final row in views as List) {
        final id = row['reel_id'].toString();
        viewCounts[id] = (viewCounts[id] ?? 0) + 1;
      }

      final likes = await supabase
          .from('reel_likes')
          .select('reel_id')
          .inFilter('reel_id', reelIds);
      final Map<String, int> likeCounts = {};
      for (final row in likes as List) {
        final id = row['reel_id'].toString();
        likeCounts[id] = (likeCounts[id] ?? 0) + 1;
      }

      final comments = await supabase
          .from('reel_comments')
          .select('reel_id')
          .inFilter('reel_id', reelIds);
      final Map<String, int> commentCounts = {};
      for (final row in comments as List) {
        final id = row['reel_id'].toString();
        commentCounts[id] = (commentCounts[id] ?? 0) + 1;
      }

      final saves = await supabase
          .from('reel_saves')
          .select('reel_id')
          .inFilter('reel_id', reelIds);
      final Map<String, int> saveCounts = {};
      for (final row in saves as List) {
        final id = row['reel_id'].toString();
        saveCounts[id] = (saveCounts[id] ?? 0) + 1;
      }

      final shares = await supabase
          .from('reel_shares')
          .select('reel_id')
          .inFilter('reel_id', reelIds);
      final Map<String, int> shareCounts = {};
      for (final row in shares as List) {
        final id = row['reel_id'].toString();
        shareCounts[id] = (shareCounts[id] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          likeCounts.forEach((k, v) => _reelLikeCounts[k] = v);
          commentCounts.forEach((k, v) => _reelCommentCounts[k] = v);
          saveCounts.forEach((k, v) => _reelSaveCounts[k] = v);
          shareCounts.forEach((k, v) => _reelShareCounts[k] = v);
          viewCounts.forEach((k, v) => _reelViewCounts[k] = v);
        });
      }
    } catch (e) {
      debugPrint("Error loading real counts: $e");
    }
  }

  Future<void> _toggleReelSave(ReelModel reel) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final bool currentSaved = _savedReels[reel.id] ?? false;
    final int currentCount = _reelSaveCounts[reel.id] ?? 0;
    final int newCount = currentSaved
        ? (currentCount > 0 ? currentCount - 1 : 0)
        : currentCount + 1;
    setState(() {
      _savedReels[reel.id] = !currentSaved;
      _reelSaveCounts[reel.id] = newCount;
    });
    try {
      if (!currentSaved) {
        await supabase.from('reel_saves').insert({
          'reel_id': reel.id,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String()
        });
      } else {
        await supabase
            .from('reel_saves')
            .delete()
            .eq('reel_id', reel.id)
            .eq('user_id', userId);
      }
    } catch (e) {
      setState(() {
        _savedReels[reel.id] = currentSaved;
        _reelSaveCounts[reel.id] = currentCount;
      });
    }
  }

  Future<void> _loadViewedReelIds() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await supabase
          .from('reel_views')
          .select('reel_id')
          .eq('viewer_id', userId);
      _viewedReelIds
        ..clear()
        ..addAll((res as List).map((e) => e['reel_id'].toString()));
      _viewsLoaded = true;
    } catch (e) {
      debugPrint("Error loading reel views: $e");
      _viewsLoaded = false;
    }
  }

  Future<void> _checkAllReelsSeen() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final reelsRes =
          await supabase.from('reels').select('id').eq('is_active', true);
      final int totalActive = (reelsRes as List).length;
      if (mounted) {
        setState(() {
          _allReelsSeen =
              (totalActive > 0 && _viewedReelIds.length >= totalActive);
        });
      }
    } catch (e) {
      debugPrint("Error checking all reels seen: $e");
    }
  }

  Future<void> _markReelAsViewed(String reelId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (_markingNow.contains(reelId)) return;
    _markingNow.add(reelId);
    try {
      await supabase.from('reel_views').insert({
        'viewer_id': userId,
        'reel_id': reelId,
        'viewed_at': DateTime.now().toIso8601String()
      });
      final countRes =
          await supabase.from('reel_views').select('id').eq('reel_id', reelId);
      if (mounted)
        setState(() {
          _reelViewCounts[reelId] = (countRes as List).length;
        });
    } catch (e) {
      debugPrint("Error marking reel viewed: $e");
    } finally {
      _markingNow.remove(reelId);
    }
  }

  Future<void> _fetchReels({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (_isLoadingMore || !_hasMoreData) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoadingInitial = true;
        _hasMoreData = true;
        _currentOffset = 0;
      });
    }

    try {
      if (!_viewsLoaded) {
        await _loadViewedReelIds();
        await _checkAllReelsSeen();
      }

      final activeProfiles = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'merchant')
          .eq('is_subscription_active', true);
      final List<String> activeMerchantIds =
          (activeProfiles as List).map((p) => p['id'].toString()).toList();

      if (activeMerchantIds.isEmpty) {
        if (mounted)
          setState(() {
            _isLoadingInitial = false;
            _isLoadingMore = false;
          });
        return;
      }

      final response = await supabase
          .from('reels')
          .select('*, merchants:merchant_id(store_name, logo_url)')
          .eq('is_active', true)
          .inFilter('merchant_id', activeMerchantIds)
          .range(_currentOffset, _currentOffset + _batchSize - 1)
          .order('created_at', ascending: false);

      final List data = response as List;
      if (data.length < _batchSize) _hasMoreData = false;
      if (!mounted) return;

      final List<_IndexedReel> fetchedIndexed = [];
      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        final merchant = row['merchants'];
        fetchedIndexed.add(_IndexedReel(
          reel: ReelModel(
            id: row['id'].toString(),
            merchantId: row['merchant_id'].toString(),
            merchantName: merchant != null ? merchant['store_name'] : "متجر",
            merchantProfileImage: merchant != null ? merchant['logo_url'] : "",
            videoUrl: row['video_url'],
            title: row['title'] ?? "",
            description: row['description'] ?? "",
            thumbnailUrl: row['thumbnail_url'] ?? "",
            likesCount: row['likes_count'] ?? 0,
            commentsCount: row['comments_count'] ?? 0,
            productId: row['product_id']?.toString(),
          ),
          index: i,
        ));
      }

      List<ReelModel> fetchedReels;
      if (_allReelsSeen) {
        fetchedReels = fetchedIndexed.map((e) => e.reel).toList()
          ..shuffle(_rng);
      } else {
        fetchedIndexed.sort((a, b) {
          final aSeen = _viewedReelIds.contains(a.reel.id);
          final bSeen = _viewedReelIds.contains(b.reel.id);
          if (!aSeen && bSeen) return -1;
          if (aSeen && !bSeen) return 1;
          return a.index.compareTo(b.index);
        });
        fetchedReels = fetchedIndexed.map((e) => e.reel).toList();
      }

      final reelsWithProducts = fetchedReels
          .where((r) => r.productId != null && r.productId!.isNotEmpty)
          .toList();
      final reelsWithoutProducts = fetchedReels
          .where((r) => r.productId == null || r.productId!.isEmpty)
          .toList();

      Set<String> validProductIds = {};
      if (reelsWithProducts.isNotEmpty) {
        final productIds = reelsWithProducts.map((r) => r.productId!).toList();
        final productsRes = await supabase
            .from('products')
            .select('id')
            .inFilter('id', productIds)
            .eq('is_available', true)
            .or('is_banned.eq.false,is_banned.is.null');
        validProductIds =
            (productsRes as List).map((p) => p['id'].toString()).toSet();
      }

      final filteredReels = [
        ...reelsWithoutProducts,
        ...reelsWithProducts.where((r) => validProductIds.contains(r.productId))
      ];

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _reelsList.addAll(filteredReels);
          } else {
            _reelsList = filteredReels;
          }
          _currentOffset += data.length;
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
      }

      final ids = _reelsList.map((r) => r.id).toList();
      await _loadRealCounts(ids);

      final productIds = _reelsList
          .where((r) => r.productId != null && r.productId!.isNotEmpty)
          .map((r) => r.productId!)
          .toList();
      if (productIds.isNotEmpty) {
        final pricesRes = await supabase
            .from('products')
            .select('id, price, old_price')
            .inFilter('id', productIds);
        if (mounted) {
          for (final p in pricesRes as List) {
            _productPrices[p['id'].toString()] =
                (p['price'] as num?)?.toDouble();
            _productOldPrices[p['id'].toString()] =
                (p['old_price'] as num?)?.toDouble();
          }
        }
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      if (mounted)
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPageIndex = index);
    if (index >= 0 && index < _reelsList.length)
      _markReelAsViewed(_reelsList[index].id);
    if (index >= _reelsList.length - 2 && _hasMoreData && !_isLoadingMore)
      _fetchReels(isLoadMore: true);
  }

  Future<void> _toggleReelLike(ReelModel reel) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final bool currentLiked = _likedReels[reel.id] ?? false;
    final int currentCount = _reelLikeCounts[reel.id] ?? reel.likesCount;
    final int newCount = currentLiked
        ? (currentCount > 0 ? currentCount - 1 : 0)
        : currentCount + 1;
    setState(() {
      _likedReels[reel.id] = !currentLiked;
      _reelLikeCounts[reel.id] = newCount;
    });
    try {
      if (!currentLiked) {
        await supabase.from('reel_likes').insert({
          'reel_id': reel.id,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String()
        });
        await supabase
            .from('reels')
            .update({'likes_count': newCount}).eq('id', reel.id);
      } else {
        await supabase
            .from('reel_likes')
            .delete()
            .eq('reel_id', reel.id)
            .eq('user_id', userId);
        await supabase
            .from('reels')
            .update({'likes_count': newCount}).eq('id', reel.id);
      }
    } catch (e) {
      setState(() {
        _likedReels[reel.id] = currentLiked;
        _reelLikeCounts[reel.id] = currentCount;
      });
    }
  }

  Future<void> _shareReel(ReelModel reel) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      await supabase.from('reel_shares').insert({
        'reel_id': reel.id,
        'merchant_id': reel.merchantId,
        'user_id': userId,
        'shared_at': DateTime.now().toIso8601String()
      });
      if (mounted)
        setState(() =>
            _reelShareCounts[reel.id] = (_reelShareCounts[reel.id] ?? 0) + 1);
    } catch (e) {
      debugPrint("Share error: $e");
    }
  }

  void _pauseCurrentVideo() {
    _videoKeys[_currentPageIndex]?.currentState?.pause();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _isLoadingInitial
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD32027)))
              : _reelsList.isEmpty
                  ? _buildEmptyState()
                  : Stack(
                      children: [
                        _isGridView
                            ? _buildGridView()
                            : PageView.builder(
                                controller: _pageController,
                                scrollDirection: Axis.vertical,
                                itemCount: _reelsList.length,
                                onPageChanged: _onPageChanged,
                                itemBuilder: (context, index) =>
                                    _buildReelItem(_reelsList[index], index),
                              ),
                        if (_isLoadingMore && !_isGridView)
                          const Positioned(
                              bottom: 20,
                              left: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)),
                        _buildTopBar(),
                        if (_isCommenting) _buildDirectCommentInput(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 44,
      left: 12,
      right: 12,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _pauseCurrentVideo();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReelsSearchPage(
                        allReels: _reelsList,
                        onReelTap: (index) {
                          setState(() {
                            _isGridView = false;
                            _currentPageIndex = index;
                          });
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _pageController.jumpToPage(index);
                          });
                        },
                      ),
                    ));
              },
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFD32027).withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search_rounded,
                        color: Colors.white38, size: 18),
                    const SizedBox(width: 8),
                    Text("بحث عن ريلز أو متجر...",
                        style: GoogleFonts.cairo(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _isGridView = false),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: !_isGridView
                    ? const Color(0xFFD32027)
                    : Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child:
                  const Center(child: PhoneIcon(size: 26, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _isGridView = true),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _isGridView
                    ? const Color(0xFFD32027)
                    : Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      PhoneIcon(size: 14, color: Colors.white),
                      const SizedBox(width: 2),
                      PhoneIcon(size: 14, color: Colors.white)
                    ]),
                    const SizedBox(height: 2),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      PhoneIcon(size: 14, color: Colors.white),
                      const SizedBox(width: 2),
                      PhoneIcon(size: 14, color: Colors.white)
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return Column(
      children: [
        const SizedBox(height: 105),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.6),
            itemCount: _reelsList.length,
            itemBuilder: (context, index) {
              final reel = _reelsList[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _isGridView = false;
                    _currentPageIndex = index;
                  });
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _pageController.jumpToPage(index);
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GridVideoWidget(videoUrl: reel.videoUrl),
                      Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7)
                          ]))),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(reel.merchantName,
                                style: GoogleFonts.cairo(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (reel.title != null && reel.title!.isNotEmpty)
                              Text(reel.title!,
                                  style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white38, size: 36)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle),
            child:
                const Icon(Icons.videocam_off, size: 48, color: Colors.white24),
          ),
          const SizedBox(height: 20),
          Text("لا توجد مقاطع ريلز متاحة حالياً",
              style: GoogleFonts.cairo(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _fetchReels(isLoadMore: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFD32027),
                  borderRadius: BorderRadius.circular(20)),
              child: Text("تحديث",
                  style: GoogleFonts.cairo(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelItem(ReelModel reel, int index) {
    _videoKeys[index] ??= GlobalKey<_VideoPlayerWidgetState>();
    return GestureDetector(
      onTap: () {
        setState(() => _isMuted = !_isMuted);
        _videoKeys[index]?.currentState?.setMuted(_isMuted);
      },
      onDoubleTap: () => _toggleReelLike(reel),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayerWidget(
              key: _videoKeys[index],
              videoUrl: reel.videoUrl,
              isMuted: _isMuted),
          _buildBottomGradient(),
          _buildRightSidebar(reel),
          _buildBottomInfo(reel),
        ],
      ),
    );
  }

  Widget _buildBottomGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.5, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.3),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.85)
          ],
        ),
      ),
    );
  }

  Widget _buildRightSidebar(ReelModel reel) {
    final bool liked = _likedReels[reel.id] ?? false;
    final bool saved = _savedReels[reel.id] ?? false;
    final int likesCount = _reelLikeCounts[reel.id] ?? reel.likesCount;
    final int commentsCount = _reelCommentCounts[reel.id] ?? reel.commentsCount;
    final int sharesCount = _reelShareCounts[reel.id] ?? 0;
    final int savesCount = _reelSaveCounts[reel.id] ?? 0;

    return Positioned(
      right: 12,
      bottom: 90,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _isMuted = !_isMuted);
              _videoKeys[_currentPageIndex]?.currentState?.setMuted(_isMuted);
            },
            child: Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: _isMuted ? const Color(0xFFD32027) : Colors.white,
                  size: 22),
            ),
          ),
          _buildProfileIcon(reel),
          const SizedBox(height: 24),
          _buildActionItemWithLabel(
              icon: Icons.remove_red_eye_rounded,
              count: _reelViewCounts[reel.id] ?? 0,
              color: Colors.white,
              onTap: () {}),
          const SizedBox(height: 4),
          _buildActionItemWithLabel(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              count: likesCount,
              color: liked ? const Color(0xFFD32027) : Colors.white,
              onTap: () => _toggleReelLike(reel)),
          const SizedBox(height: 4),
          _buildActionItemWithLabel(
              icon: Icons.chat_bubble_outline_rounded,
              count: commentsCount,
              color: Colors.white,
              onTap: () => _showComments(reel)),
          const SizedBox(height: 4),
          _buildActionItemWithLabel(
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              count: savesCount,
              color: saved ? Colors.amber : Colors.white,
              onTap: () => _toggleReelSave(reel)),
          const SizedBox(height: 4),
          _buildActionItemWithLabel(
            icon: Icons.reply_rounded,
            count: sharesCount,
            color: Colors.white,
            onTap: () async {
              await Share.share('${reel.title ?? ''}\n${reel.videoUrl}');
              await _shareReel(reel);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItemWithLabel(
      {required IconData icon,
      required int? count,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1)),
            child: Icon(icon, color: color, size: 22),
          ),
          if (count != null) ...[
            const SizedBox(height: 4),
            Text(count.toString(),
                style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileIcon(ReelModel reel) {
    return GestureDetector(
      onTap: () => _navigateToMerchant(reel),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD32027), width: 2),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFD32027).withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1)
          ],
        ),
        child: ClipOval(
          child: reel.merchantProfileImage.isNotEmpty
              ? Image.network(reel.merchantProfileImage, fit: BoxFit.cover)
              : Container(
                  color: Colors.grey[900],
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 22)),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(ReelModel reel) {
    return Positioned(
      left: 16,
      bottom: 24,
      right: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _navigateToMerchant(reel),
            child: Text(reel.merchantName,
                style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (reel.title != null && reel.title!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(reel.title!,
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          if (reel.description != null && reel.description!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(reel.description!,
                style: GoogleFonts.cairo(
                    color: Colors.white60, fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (reel.productId != null && reel.productId!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                _pauseCurrentVideo();
                context.push('/product-details/${reel.productId}');
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: const Color(0xFFD32027),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFD32027).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_rounded,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 6),
                    Text("فتح العرض",
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (_productPrices[reel.productId] != null) ...[
                      const SizedBox(width: 6),
                      Container(width: 1, height: 12, color: Colors.white38),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PriceWidget(
                              price: _productPrices[reel.productId]!,
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                          if (_productOldPrices[reel.productId] != null &&
                              _productOldPrices[reel.productId]! >
                                  _productPrices[reel.productId]!) ...[
                            const SizedBox(width: 6),
                            PriceWidget(
                                price: _productOldPrices[reel.productId]!,
                                fontSize: 10,
                                color: Colors.white54,
                                decoration: TextDecoration.lineThrough),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                  "${(((_productOldPrices[reel.productId]! - _productPrices[reel.productId]!) / _productOldPrices[reel.productId]!) * 100).round()}%",
                                  style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectCommentInput() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 15,
            top: 15,
            left: 15,
            right: 15),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                autofocus: true,
                style: GoogleFonts.cairo(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "اكتب تعليقك هنا...",
                  hintStyle: GoogleFonts.cairo(color: Colors.white38),
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                setState(() => _isCommenting = false);
                _commentController.clear();
              },
              child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: Color(0xFFD32027), shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToMerchant(ReelModel reel) async {
    _pauseCurrentVideo();
    try {
      final data = await supabase
          .from('merchants')
          .select()
          .eq('id', reel.merchantId)
          .single();
      if (mounted) {
        final merchant = MerchantModel.fromMap(data);
        context.push(RoutePaths.storeDetails, extra: merchant);
      }
    } catch (e) {
      debugPrint("Merchant details error: $e");
    }
  }

  void _showComments(ReelModel reel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CommentsSheet(targetId: reel.id, targetType: 'reel', isDark: true),
    );
  }
}

class GridVideoWidget extends StatefulWidget {
  final String videoUrl;
  const GridVideoWidget({super.key, required this.videoUrl});

  @override
  State<GridVideoWidget> createState() => _GridVideoWidgetState();
}

class _GridVideoWidgetState extends State<GridVideoWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl.trim()))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
                _controller.setLooping(false);
                _controller.setVolume(0.0);
                _controller.play();
              });
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) _controller.pause();
              });
            }
          }).catchError((Object e) {
            debugPrint("Grid video error: $e");
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? SizedBox.expand(
            child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller))))
        : Container(
            color: Colors.grey[900],
            child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white24)));
  }
}

class _IndexedReel {
  final ReelModel reel;
  final int index;
  _IndexedReel({required this.reel, required this.index});
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isMuted;
  const VideoPlayerWidget(
      {super.key, required this.videoUrl, this.isMuted = false});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMuted != widget.isMuted)
      _controller.setVolume(widget.isMuted ? 0.0 : 1.0);
  }

  void _initializePlayer() {
    try {
      final cleanUrl = widget.videoUrl.trim();
      _controller = VideoPlayerController.networkUrl(Uri.parse(cleanUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _controller.setLooping(true);
              _controller.setVolume(widget.isMuted ? 0.0 : 1.0);
              _controller.play();
            });
          }
        }).catchError((Object error) {
          debugPrint("Player error: $error");
        });
    } catch (e) {
      debugPrint("Invalid URL: $e");
    }
  }

  void pause() {
    if (_isInitialized) _controller.pause();
  }

  void setMuted(bool muted) {
    if (_isInitialized) _controller.setVolume(muted ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? SizedBox.expand(
            child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller))))
        : const Center(child: CircularProgressIndicator(color: Colors.white24));
  }
}
