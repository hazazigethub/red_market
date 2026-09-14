import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/features/customer/home/presentation/pages/reels_page.dart';

// ✅ خيارات الترتيب
enum ReelSortOption { relevant, newest, mostLiked, mostViewed }

class ReelsSearchPage extends StatefulWidget {
  final List<ReelModel> allReels;
  final void Function(int index) onReelTap;

  const ReelsSearchPage({
    super.key,
    required this.allReels,
    required this.onReelTap,
  });

  @override
  State<ReelsSearchPage> createState() => _ReelsSearchPageState();
}

class _ReelsSearchPageState extends State<ReelsSearchPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<ReelModel> _results = [];
  List<ReelModel> _allReels = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  ReelSortOption _sortOption = ReelSortOption.relevant;

  // ✅ Realtime stream لمراقبة التغييرات في الريلز
  late final Stream<List<Map<String, dynamic>>> _reelsStream;

  @override
  void initState() {
    super.initState();
    _allReels = widget.allReels;

    // ✅ Realtime: يتابع أي تغيير في جدول reels
    _reelsStream = supabase
        .from('reels')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false);

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _performSearch(query);
  }

  // ✅ البحث الذكي في العنوان + الوصف + اسم المتجر
  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      final q = query.trim().toLowerCase();

      // ✅ أولاً: بحث في قاعدة البيانات مباشرة
      final response = await supabase
          .from('reels')
          .select('*, merchants:merchant_id(store_name, logo_url)')
          .eq('is_active', true)
          .or('title.ilike.%$q%,description.ilike.%$q%')
          .order('created_at', ascending: false)
          .limit(50);

      final List<ReelModel> dbResults = (response as List).map((row) {
        final merchant = row['merchants'];
        return ReelModel(
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
        );
      }).toList();

      // ✅ ثانياً: بحث في اسم المتجر من القائمة المحلية
      final merchantResults = _allReels.where((r) {
        return r.merchantName.toLowerCase().contains(q) &&
            !dbResults.any((d) => d.id == r.id);
      }).toList();

      // ✅ دمج النتائج
      final combined = [...dbResults, ...merchantResults];

      // ✅ تطبيق الترتيب
      final sorted = _applySorting(combined, q);

      if (mounted) {
        setState(() {
          _results = sorted;
          _hasSearched = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      // ✅ fallback: بحث محلي في القائمة
      final local = _allReels.where((r) {
        final title = (r.title ?? '').toLowerCase();
        final desc = (r.description ?? '').toLowerCase();
        final merchant = r.merchantName.toLowerCase();
        return title.contains(query.toLowerCase()) ||
            desc.contains(query.toLowerCase()) ||
            merchant.contains(query.toLowerCase());
      }).toList();

      if (mounted) {
        setState(() {
          _results = _applySorting(local, query.toLowerCase());
          _hasSearched = true;
          _isSearching = false;
        });
      }
    }
  }

  // ✅ دالة الترتيب الذكي
  List<ReelModel> _applySorting(List<ReelModel> list, String query) {
    switch (_sortOption) {
      case ReelSortOption.relevant:
        // ترتيب بالأهمية: العنوان أولاً ثم الوصف ثم المتجر
        list.sort((a, b) {
          int scoreA = _relevanceScore(a, query);
          int scoreB = _relevanceScore(b, query);
          return scoreB.compareTo(scoreA);
        });
        break;
      case ReelSortOption.newest:
        // لا نملك created_at في الموديل — نبقي الترتيب من السيرفر
        break;
      case ReelSortOption.mostLiked:
        list.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case ReelSortOption.mostViewed:
        list.sort((a, b) => (b.commentsCount).compareTo(a.commentsCount));
        break;
    }
    return list;
  }

  int _relevanceScore(ReelModel reel, String query) {
    int score = 0;
    final title = (reel.title ?? '').toLowerCase();
    final desc = (reel.description ?? '').toLowerCase();
    final merchant = reel.merchantName.toLowerCase();

    if (title == query)
      score += 100;
    else if (title.startsWith(query))
      score += 60;
    else if (title.contains(query)) score += 40;

    if (desc.contains(query)) score += 20;
    if (merchant.contains(query)) score += 15;

    // ✅ تعزيز بالتفاعل
    score += (reel.likesCount / 10).round();
    score += (reel.commentsCount / 5).round();

    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        // ✅ Realtime listener يحدث القائمة المحلية عند أي تغيير
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _reelsStream,
          builder: (context, snapshot) {
            // ✅ عند وصول بيانات جديدة، حدّث _allReels وأعد البحث
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final updated = snapshot.data!.map((row) {
                final merchant = row['merchants'];
                return ReelModel(
                  id: row['id'].toString(),
                  merchantId: row['merchant_id']?.toString() ?? '',
                  merchantName: merchant != null
                      ? merchant['store_name'] ?? 'متجر'
                      : 'متجر',
                  merchantProfileImage:
                      merchant != null ? merchant['logo_url'] ?? '' : '',
                  videoUrl: row['video_url'] ?? '',
                  title: row['title'] ?? '',
                  description: row['description'] ?? '',
                  thumbnailUrl: row['thumbnail_url'] ?? '',
                  likesCount: row['likes_count'] ?? 0,
                  commentsCount: row['comments_count'] ?? 0,
                  productId: row['product_id']?.toString(),
                );
              }).toList();

              if (updated.length != _allReels.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _allReels = updated);
                    final q = _searchController.text.trim();
                    if (q.isNotEmpty) _performSearch(q);
                  }
                });
              }
            }

            return SafeArea(
              child: Column(
                children: [
                  // ✅ شريط البحث
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: GoogleFonts.cairo(
                                  color: Colors.white, fontSize: 14),
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) =>
                                  _performSearch(_searchController.text.trim()),
                              decoration: InputDecoration(
                                hintText: "بحث في العنوان، الوصف، المتجر...",
                                hintStyle: GoogleFonts.cairo(
                                    color: Colors.white38, fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: Colors.white38, size: 20),
                                suffixIcon: _searchController.text
                                        .trim()
                                        .isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() {
                                            _results = [];
                                            _hasSearched = false;
                                          });
                                        },
                                        child: const Icon(Icons.close_rounded,
                                            color: Colors.white38, size: 18),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ خيارات الترتيب
                  if (_hasSearched && _results.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          _buildSortChip("الأكثر صلة", ReelSortOption.relevant),
                          const SizedBox(width: 8),
                          _buildSortChip("الأحدث", ReelSortOption.newest),
                          const SizedBox(width: 8),
                          _buildSortChip(
                              "الأكثر إعجاباً", ReelSortOption.mostLiked),
                          const SizedBox(width: 8),
                          _buildSortChip(
                              "الأكثر تعليقاً", ReelSortOption.mostViewed),
                        ],
                      ),
                    ),

                  // ✅ حالة التحميل
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(
                          color: Color(0xFFD32027), strokeWidth: 2),
                    )
                  // ✅ لا توجد نتائج
                  else if (_hasSearched && _results.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_rounded,
                                color: Colors.white24, size: 60),
                            const SizedBox(height: 16),
                            Text("لا توجد نتائج",
                                style: GoogleFonts.cairo(
                                    color: Colors.white54, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              'جرب كلمات مختلفة أو تحقق من الإملاء',
                              style: GoogleFonts.cairo(
                                  color: Colors.white24, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  // ✅ النتائج
                  else if (_results.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            child: Text(
                              "${_results.length} نتيجة",
                              style: GoogleFonts.cairo(
                                  color: Colors.white38, fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.6,
                              ),
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final reel = _results[index];
                                // ✅ إيجاد index الريل في القائمة الأصلية
                                final originalIndex = widget.allReels
                                    .indexWhere((r) => r.id == reel.id);
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    if (originalIndex >= 0) {
                                      widget.onReelTap(originalIndex);
                                    }
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        GridVideoWidget(
                                            videoUrl: reel.videoUrl),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.75),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          right: 8,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(reel.merchantName,
                                                  style: GoogleFonts.cairo(
                                                      color: Colors.white70,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              if (reel.title != null &&
                                                  reel.title!.isNotEmpty)
                                                Text(reel.title!,
                                                    style: GoogleFonts.cairo(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              const SizedBox(height: 4),
                                              // ✅ إحصائيات
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.favorite_rounded,
                                                      color: Colors.white38,
                                                      size: 11),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                      reel.likesCount
                                                          .toString(),
                                                      style: GoogleFonts.cairo(
                                                          color: Colors.white38,
                                                          fontSize: 10)),
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                      Icons
                                                          .chat_bubble_outline_rounded,
                                                      color: Colors.white38,
                                                      size: 11),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                      reel.commentsCount
                                                          .toString(),
                                                      style: GoogleFonts.cairo(
                                                          color: Colors.white38,
                                                          fontSize: 10)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Center(
                                          child: Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: Colors.white38,
                                              size: 36),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  // ✅ الحالة الافتراضية — اقتراحات
                  else
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_rounded,
                                color: Colors.white12, size: 70),
                            const SizedBox(height: 20),
                            Text("ابحث عن ريلز أو متجر",
                                style: GoogleFonts.cairo(
                                    color: Colors.white38, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              "يمكنك البحث بالعنوان أو الوصف أو اسم المتجر",
                              style: GoogleFonts.cairo(
                                  color: Colors.white24, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, ReelSortOption option) {
    final bool isSelected = _sortOption == option;
    return GestureDetector(
      onTap: () {
        setState(() => _sortOption = option);
        final q = _searchController.text.trim();
        if (q.isNotEmpty) _performSearch(q);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD32027)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD32027)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
