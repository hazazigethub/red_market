import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCategoriesScreen extends StatefulWidget {
  /// نص البحث — يأتي من الغلاف
  final String searchQuery;

  const AdminCategoriesScreen({super.key, this.searchQuery = ''});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedStoreCategoryId;
  String? _selectedStoreCategoryName;
  String? _selectedProductCategoryId;
  String? _selectedProductCategoryName;
  bool _isProcessing = false;

  /// التصنيفات المعروضة في المستوى الحالي — بترتيب ظهورها في الموقع
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _loadedKey;
  int _loadSeq = 0;

  /// يتغير عند الانتقال بين المستويات، فيُعاد التحميل
  String get _viewKey =>
      '$_level|${_selectedStoreCategoryId ?? ''}|${_selectedProductCategoryId ?? ''}';

  /// ١ رئيسي · ٢ فرعي · ٣ فرعي الفرعي
  int get _level {
    if (_selectedProductCategoryId != null) return 3;
    if (_selectedStoreCategoryId != null) return 2;
    return 1;
  }

  String _tableForLevel(int level) {
    switch (level) {
      case 2:
        return 'product_categories';
      case 3:
        return 'sup_product_subcategories';
      default:
        return 'store_categories';
    }
  }

  String get _searchQuery => widget.searchQuery;

  /// يجلب تصنيفات المستوى الحالي مرتبة حسب sort_order
  Future<void> _load() async {
    final level = _level;
    final key = _viewKey;
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _loadedKey = key;
    });

    var query = supabase.from(_tableForLevel(level)).select();
    if (level == 2) {
      query = query.eq('parent_id', _selectedStoreCategoryId as Object);
    } else if (level == 3) {
      query = query.eq('parent_id', _selectedProductCategoryId as Object);
    }

    try {
      final data = await query
          .order('sort_order', ascending: true)
          .order('name', ascending: true);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  /// نقل تصنيف إلى مكان تصنيف آخر، ثم حفظ الترتيب كاملاً
  Future<void> _moveCategory(String fromId, String toId) async {
    final from = _items.indexWhere((e) => e['id'].toString() == fromId);
    final to = _items.indexWhere((e) => e['id'].toString() == toId);
    if (from < 0 || to < 0 || from == to) return;

    final before = List<Map<String, dynamic>>.from(_items);
    final moved = List<Map<String, dynamic>>.from(_items);
    final item = moved.removeAt(from);
    moved.insert(to, item);
    setState(() => _items = moved);

    try {
      await supabase.rpc(
        'reorder_categories',
        params: {
          'p_table': _tableForLevel(_level),
          'p_ids': moved.map((e) => e['id'].toString()).toList(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = before);
      _showSnackBar('تعذر حفظ الترتيب، حاول مجدداً', Colors.red);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ قاموس الأيقونات الرمادية الذكي
  IconData _getIcon(String name) {
    name = name.toLowerCase();
    if (name.contains("ملابس") || name.contains("أزياء")) {
      return Icons.checkroom_rounded;
    }
    if (name.contains("قهوه") || name.contains("قهوة")) {
      return Icons.local_cafe_rounded;
    }
    if (name.contains("عناية")) return Icons.auto_awesome_rounded;
    if (name.contains("إلكترونيات")) return Icons.devices_rounded;
    if (name.contains("ملحقات")) return Icons.mouse_rounded;
    if (name.contains("كهربائية")) return Icons.power_rounded;
    if (name.contains("أثاث")) return Icons.chair_alt_rounded;
    if (name.contains("مطبخ")) return Icons.soup_kitchen_rounded;
    if (name.contains("منظفات")) return Icons.cleaning_services_rounded;
    if (name.contains("رياضة")) return Icons.fitness_center_rounded;
    if (name.contains("مكملات")) return Icons.medication_liquid_rounded;
    if (name.contains("طبية")) return Icons.medical_services_rounded;
    if (name.contains("طفل")) return Icons.child_care_rounded;
    if (name.contains("ألعاب")) return Icons.videogame_asset_rounded;
    if (name.contains("رحلات")) return Icons.terrain_rounded;
    if (name.contains("حيوان")) return Icons.pets_rounded;
    if (name.contains("كتب") || name.contains("قرطاسية")) {
      return Icons.menu_book_rounded;
    }
    if (name.contains("سيارات")) return Icons.directions_car_filled_rounded;
    if (name.contains("هدايا")) return Icons.redeem_rounded;
    if (name.contains("سفر")) return Icons.flight_takeoff_rounded;
    if (name.contains("حرف")) return Icons.brush_rounded;
    if (name.contains("سلامة")) return Icons.security_rounded;
    return Icons.grid_view_rounded; // أيقونة افتراضية
  }

  Future<void> _deleteCategory(String id, int level) async {
    setState(() => _isProcessing = true);
    try {
      if (level < 3) {
        // نمنع حذف مستوى له فروع — فرعي الفرعي لا فروع له
        final childTable = level == 1
            ? 'product_categories'
            : 'sup_product_subcategories';
        final children = await supabase
            .from(childTable)
            .select('id')
            .eq('parent_id', id)
            .limit(1);

        if (children.isNotEmpty) {
          _showSnackBar(
            "لا يمكن حذف قسم يحتوي على أقسام فرعية!",
            Colors.orange,
          );
          return;
        }
      }
      await supabase.from(_tableForLevel(level)).delete().eq('id', id);

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("تم الحذف بنجاح", Colors.green);
        _load();
      }
    } catch (e) {
      _showSnackBar("خطأ: لا يمكن الحذف لارتباطه ببيانات أخرى", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _upsertCategory({String? id, required int level}) async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isProcessing = true);
    final parentId = level == 2
        ? _selectedStoreCategoryId
        : _selectedProductCategoryId;
    final data = {
      'name': _nameController.text.trim(),
      if (level > 1) 'parent_id': parentId,
    };
    try {
      if (id == null) {
        await supabase.from(_tableForLevel(level)).insert(data);
      } else {
        await supabase.from(_tableForLevel(level)).update(data).eq('id', id);
      }
      _nameController.clear();
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("تم الحفظ بنجاح", Colors.green);
        _load();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("تعذر الحفظ، تحقق من البيانات", Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleVisibility(
    String id,
    bool currentStatus,
    int level,
  ) async {
    await supabase
        .from(_tableForLevel(level))
        .update({'is_visible': !currentStatus})
        .eq('id', id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    if (_loadedKey != _viewKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedKey != _viewKey) _load();
      });
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // شريط رجوع يظهر داخل الأقسام الفرعية فقط
            if (_level > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        if (_level == 3) {
                          _selectedProductCategoryId = null;
                          _selectedProductCategoryName = null;
                        } else {
                          _selectedStoreCategoryId = null;
                          _selectedStoreCategoryName = null;
                        }
                        _searchController.clear();
                      }),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 15),
                      label: Text(
                        _level == 3 ? 'الأقسام الفرعية' : 'الأقسام الرئيسية',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(foregroundColor: brandRed),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: brandRed.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          switch (_level) {
                            2 =>
                              "الأقسام الفرعية لـ $_selectedStoreCategoryName",
                            3 => "أقسام فرعية لـ $_selectedProductCategoryName",
                            _ => "الأقسام الرئيسية",
                          },
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    if (_searchQuery.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'اسحب البطاقة وأفلتها مكان بطاقة أخرى لتغيير ترتيب ظهورها في الموقع',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const Divider(thickness: 1, height: 20),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              sliver: _buildCategoryGrid(level: _level, brandRed: brandRed),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              _showAddEditDialog(level: _level, brandRed: brandRed),
          backgroundColor: brandRed,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          label: Text(
            _selectedStoreCategoryId == null ? "إضافة قسم" : "إضافة فرع",
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid({required int level, required Color brandRed}) {
    if (_loading || _loadedKey != _viewKey) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    var data = _items;
    final searching = _searchQuery.isNotEmpty;
    if (searching) {
      data = data
          .where((item) => item['name'].toString().contains(_searchQuery))
          .toList();
    }
    if (data.isEmpty) return SliverFillRemaining(child: _buildEmptyState());

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 140,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = data[index];
        final bool isVisible = item['is_visible'] ?? true;
        final card = _buildCompactCard(item, isVisible, level, brandRed);
        // الترتيب بالسحب معطّل أثناء البحث لأن القائمة ناقصة
        if (searching) return card;
        return _draggableCard(item, card, brandRed);
      }, childCount: data.length),
    );
  }

  /// بطاقة قابلة للسحب، وتستقبل غيرها: الإفلات عليها يضع المسحوب مكانها
  Widget _draggableCard(
    Map<String, dynamic> item,
    Widget card,
    Color brandRed,
  ) {
    final id = item['id'].toString();
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != id,
      onAcceptWithDetails: (details) => _moveCategory(details.data, id),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return Draggable<String>(
          data: id,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 160,
              height: 130,
              child: Opacity(opacity: 0.9, child: card),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: hovering ? brandRed : Colors.transparent,
                width: 2,
              ),
            ),
            child: card,
          ),
        );
      },
    );
  }

  Widget _buildCompactCard(
    Map<String, dynamic> item,
    bool isVisible,
    int level,
    Color brandRed,
  ) {
    return GestureDetector(
      onTap: () {
        if (level == 1) {
          setState(() {
            _selectedStoreCategoryId = item['id'].toString();
            _selectedStoreCategoryName = item['name'];
            _searchController.clear();
          });
        } else if (level == 2) {
          setState(() {
            _selectedProductCategoryId = item['id'].toString();
            _selectedProductCategoryName = item['name'];
            _searchController.clear();
          });
        }
      },
      onLongPress: () =>
          _showAddEditDialog(level: level, brandRed: brandRed, category: item),
      child: Tooltip(
        message: 'اضغط مطوّلاً للتعديل أو الحذف',
        waitDuration: const Duration(milliseconds: 400),
        triggerMode: TooltipTriggerMode.longPress,
        child: Container(
          decoration: BoxDecoration(
            color: isVisible
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isVisible ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ تصميم الأيقونات الرمادية الموحدة
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isVisible
                            ? Colors.grey.shade100
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isVisible
                              ? Colors.grey.shade200
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getIcon(item['name']),
                        size: 24,
                        color: isVisible
                            ? Colors.grey.shade700
                            : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        item['name'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: isVisible
                              ? Colors.black87
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(
          _searchQuery.isEmpty ? "لا توجد بيانات" : "لا توجد نتائج لبحثك",
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showAddEditDialog({
    required int level,
    required Color brandRed,
    Map<String, dynamic>? category,
  }) {
    _nameController.text = category != null ? category['name'] : "";

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  category == null ? "إضافة عنصر" : "تعديل البيانات",
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: "الاسم",
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () =>
                            _upsertCategory(id: category?['id'], level: level),
                        child: const Text(
                          "حفظ",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          _toggleVisibility(
                            category['id'],
                            category['is_visible'] ?? true,
                            level,
                          );
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          category['is_visible'] == false
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _deleteCategory(category['id'], level),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
