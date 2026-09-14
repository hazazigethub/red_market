import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsSheet extends StatefulWidget {
  final String targetId;
  final String targetType;
  final bool isDark;

  const CommentsSheet(
      {super.key,
      required this.targetId,
      required this.targetType,
      this.isDark = false});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final supabase = Supabase.instance.client;
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _editCtrl = TextEditingController();

  String? _replyingToCommentId;
  String? _replyingToUserName;
  String? _editingCommentId;
  bool _isReel = false;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  final Map<String, bool> _likedComments = {};
  final Map<String, int> _commentLikeCounts = {};
  final Map<String, bool> _likedReplies = {};
  final Map<String, int> _replyLikeCounts = {};
  final Set<String> _expandedComments = {};

  static const Color brandRed = Color(0xFFD32027);

  @override
  void initState() {
    super.initState();
    _isReel = widget.targetType == 'reel';
    _loadComments();
  }

  String get _commentsTable => _isReel ? 'reel_comments' : 'product_comments';
  String get _repliesTable =>
      _isReel ? 'reel_comment_replies' : 'product_comment_replies';
  String get _likesTable =>
      _isReel ? 'reel_comment_likes' : 'product_comment_likes';
  String get _replyLikesTable =>
      _isReel ? 'reel_reply_likes' : 'product_reply_likes';
  String get _targetColumn => _isReel ? 'reel_id' : 'product_id';

  Future<void> _loadComments() async {
    try {
      final res = await supabase
          .from(_commentsTable)
          .select('*, profiles:user_id(full_name, logo_url)')
          .eq(_targetColumn, widget.targetId)
          .order('created_at', ascending: false);
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final liked = await supabase
            .from(_likesTable)
            .select('comment_id')
            .eq('user_id', userId);
        for (final row in liked as List) {
          _likedComments[row['comment_id'].toString()] = true;
        }
        final likedReplies = await supabase
            .from(_replyLikesTable)
            .select('reply_id')
            .eq('user_id', userId);
        for (final row in likedReplies as List) {
          _likedReplies[row['reply_id'].toString()] = true;
        }
      }
      final comments = res as List;
      for (final c in comments) {
        _commentLikeCounts[c['id'].toString()] = c['likes_count'] ?? 0;
      }
      if (mounted)
        setState(() {
          _comments = List<Map<String, dynamic>>.from(comments);
          _isLoading = false;
        });
    } catch (e) {
      debugPrint("Error loading comments: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final bool isLiked = _likedComments[commentId] ?? false;
    final int count = _commentLikeCounts[commentId] ?? 0;
    setState(() {
      _likedComments[commentId] = !isLiked;
      _commentLikeCounts[commentId] =
          isLiked ? (count > 0 ? count - 1 : 0) : count + 1;
    });
    try {
      if (!isLiked) {
        await supabase
            .from(_likesTable)
            .insert({'comment_id': commentId, 'user_id': userId});
        await supabase.from(_commentsTable).update(
            {'likes_count': _commentLikeCounts[commentId]}).eq('id', commentId);
      } else {
        await supabase
            .from(_likesTable)
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
        await supabase.from(_commentsTable).update(
            {'likes_count': _commentLikeCounts[commentId]}).eq('id', commentId);
      }
    } catch (e) {
      setState(() {
        _likedComments[commentId] = isLiked;
        _commentLikeCounts[commentId] = count;
      });
    }
  }

  Future<void> _toggleReplyLike(String replyId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final bool isLiked = _likedReplies[replyId] ?? false;
    final int count = _replyLikeCounts[replyId] ?? 0;
    setState(() {
      _likedReplies[replyId] = !isLiked;
      _replyLikeCounts[replyId] =
          isLiked ? (count > 0 ? count - 1 : 0) : count + 1;
    });
    try {
      if (!isLiked) {
        await supabase
            .from(_replyLikesTable)
            .insert({'reply_id': replyId, 'user_id': userId});
      } else {
        await supabase
            .from(_replyLikesTable)
            .delete()
            .eq('reply_id', replyId)
            .eq('user_id', userId);
      }
    } catch (e) {
      setState(() {
        _likedReplies[replyId] = isLiked;
        _replyLikeCounts[replyId] = count;
      });
    }
  }

  Future<void> _sendComment() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || _commentCtrl.text.trim().isEmpty) return;
    try {
      if (_replyingToCommentId != null) {
        await supabase.from(_repliesTable).insert({
          'comment_id': _replyingToCommentId,
          'user_id': userId,
          'content': _commentCtrl.text.trim(),
          'created_at': DateTime.now().toIso8601String()
        });
        setState(() {
          _replyingToCommentId = null;
          _replyingToUserName = null;
        });
      } else {
        await supabase.from(_commentsTable).insert({
          _targetColumn: widget.targetId,
          'user_id': userId,
          'content': _commentCtrl.text.trim(),
          'created_at': DateTime.now().toIso8601String()
        });
      }
      _commentCtrl.clear();
      await _loadComments();
    } catch (e) {
      debugPrint("Comment error: $e");
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await supabase.from(_commentsTable).delete().eq('id', commentId);
      await _loadComments();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  Future<void> _editComment(String commentId) async {
    if (_editCtrl.text.trim().isEmpty) return;
    try {
      await supabase
          .from(_commentsTable)
          .update({'content': _editCtrl.text.trim()}).eq('id', commentId);
      setState(() => _editingCommentId = null);
      _editCtrl.clear();
      await _loadComments();
    } catch (e) {
      debugPrint("Edit error: $e");
    }
  }

  void _showCommentOptions(Map<String, dynamic> comment) {
    final userId = supabase.auth.currentUser?.id;
    if (userId != comment['user_id']?.toString()) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: Text("تعديل التعليق",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: widget.isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(ctx);
                _editCtrl.text = comment['content'] ?? '';
                setState(() => _editingCommentId = comment['id'].toString());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("حذف التعليق",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteComment(comment['id'].toString());
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _showReplyOptions(Map<String, dynamic> reply) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: Text("تعديل الرد",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: widget.isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(ctx);
                _editCtrl.text = reply['content'] ?? '';
                setState(() => _editingCommentId = 'reply_${reply['id']}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("حذف الرد",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await supabase
                    .from(_repliesTable)
                    .delete()
                    .eq('id', reply['id']);
                setState(() {});
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ✅ زر الإعجاب كـ widget مستقل
  Widget _buildLikeButton(
      {required bool isLiked,
      required int count,
      required VoidCallback onTap,
      required Color subTextColor,
      double size = 22}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? Colors.red : subTextColor, size: size),
          if (count > 0)
            Text("$count",
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: isLiked ? Colors.red : subTextColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        widget.isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final Color textColor = widget.isDark ? Colors.white : Colors.black87;
    final Color subTextColor = widget.isDark ? Colors.white60 : Colors.grey;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 14),
              Text("التعليقات",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: textColor)),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.withValues(alpha: 0.2), height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: brandRed))
                    : _comments.isEmpty
                        ? Center(
                            child: Text("لا توجد تعليقات بعد",
                                style: TextStyle(
                                    fontFamily: 'Cairo', color: subTextColor)))
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _comments.length,
                            itemBuilder: (context, i) {
                              final c = _comments[i];
                              final profile = c['profiles'];
                              final commentId = c['id'].toString();
                              final isLiked =
                                  _likedComments[commentId] ?? false;
                              final likeCount =
                                  _commentLikeCounts[commentId] ?? 0;
                              final userId = supabase.auth.currentUser?.id;
                              final isOwner =
                                  userId == c['user_id']?.toString();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ التعليق — زر الإعجاب خارج Expanded ومتوسط
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.grey.shade200,
                                          backgroundImage:
                                              (profile?['logo_url'] != null &&
                                                      profile['logo_url']
                                                          .toString()
                                                          .isNotEmpty)
                                                  ? NetworkImage(
                                                      profile['logo_url'])
                                                  : null,
                                          child:
                                              (profile?['logo_url'] == null ||
                                                      profile['logo_url']
                                                          .toString()
                                                          .isEmpty)
                                                  ? Icon(Icons.person,
                                                      color: subTextColor,
                                                      size: 16)
                                                  : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  profile?['full_name'] ??
                                                      'مجهول',
                                                  style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: textColor)),
                                              const SizedBox(height: 2),
                                              if (_editingCommentId ==
                                                  commentId)
                                                Row(children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller: _editCtrl,
                                                      autofocus: true,
                                                      style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 13,
                                                          color: textColor),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            "تعديل التعليق...",
                                                        hintStyle: TextStyle(
                                                            color:
                                                                subTextColor),
                                                        border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            borderSide:
                                                                const BorderSide(
                                                                    color:
                                                                        brandRed)),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 12,
                                                                vertical: 8),
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                      icon: const Icon(
                                                          Icons.check,
                                                          color: brandRed),
                                                      onPressed: () =>
                                                          _editComment(
                                                              commentId)),
                                                  IconButton(
                                                      icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.grey),
                                                      onPressed: () =>
                                                          setState(() {
                                                            _editingCommentId =
                                                                null;
                                                            _editCtrl.clear();
                                                          })),
                                                ])
                                              else
                                                Text(c['content'] ?? '',
                                                    style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 13,
                                                        height: 1.4,
                                                        color: subTextColor)),
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                GestureDetector(
                                                  onTap: () => setState(() {
                                                    _replyingToCommentId =
                                                        commentId;
                                                    _replyingToUserName =
                                                        profile?['full_name'] ??
                                                            'مجهول';
                                                  }),
                                                  child: Text("رد",
                                                      style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          color: brandRed,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ),
                                                if (isOwner) ...[
                                                  const SizedBox(width: 12),
                                                  GestureDetector(
                                                      onTap: () =>
                                                          _showCommentOptions(
                                                              c),
                                                      child: Icon(
                                                          Icons.more_horiz,
                                                          color: subTextColor,
                                                          size: 16)),
                                                ],
                                              ]),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // ✅ زر الإعجاب متوسط مع التعليق
                                        _buildLikeButton(
                                            isLiked: isLiked,
                                            count: likeCount,
                                            onTap: () =>
                                                _toggleCommentLike(commentId),
                                            subTextColor: subTextColor,
                                            size: 22),
                                      ],
                                    ),
                                  ),

                                  // ✅ الردود
                                  FutureBuilder(
                                    future: supabase
                                        .from(_repliesTable)
                                        .select(
                                            '*, profiles:user_id(full_name, logo_url)')
                                        .eq('comment_id', commentId)
                                        .order('created_at', ascending: true),
                                    builder: (context, replySnapshot) {
                                      final replies =
                                          replySnapshot.data as List? ?? [];
                                      if (replies.isEmpty)
                                        return const SizedBox();
                                      final isExpanded =
                                          _expandedComments.contains(commentId);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            right: 46, bottom: 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () => setState(() {
                                                if (isExpanded) {
                                                  _expandedComments
                                                      .remove(commentId);
                                                } else {
                                                  _expandedComments
                                                      .add(commentId);
                                                }
                                              }),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4),
                                                child: Row(children: [
                                                  Container(
                                                      width: 24,
                                                      height: 1,
                                                      color: Colors.grey
                                                          .withValues(alpha: 0.4)),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isExpanded
                                                        ? "إخفاء الردود"
                                                        : "عرض ${replies.length} ${replies.length == 1 ? 'رد' : 'ردود'} ▼",
                                                    style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .grey.shade600),
                                                  ),
                                                ]),
                                              ),
                                            ),
                                            if (isExpanded)
                                              ...replies.map((r) {
                                                final rProfile = r['profiles'];
                                                final replyId =
                                                    r['id'].toString();
                                                final isReplyOwner = supabase
                                                        .auth.currentUser?.id ==
                                                    r['user_id']?.toString();
                                                final isReplyLiked =
                                                    _likedReplies[replyId] ??
                                                        false;
                                                final replyLikeCount =
                                                    _replyLikeCounts[replyId] ??
                                                        (r['likes_count'] ?? 0);

                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 4),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 14,
                                                        backgroundColor: Colors
                                                            .grey.shade200,
                                                        backgroundImage: (rProfile?[
                                                                        'logo_url'] !=
                                                                    null &&
                                                                rProfile[
                                                                        'logo_url']
                                                                    .toString()
                                                                    .isNotEmpty)
                                                            ? NetworkImage(
                                                                rProfile[
                                                                    'logo_url'])
                                                            : null,
                                                        child: (rProfile?[
                                                                        'logo_url'] ==
                                                                    null ||
                                                                rProfile[
                                                                        'logo_url']
                                                                    .toString()
                                                                    .isEmpty)
                                                            ? Icon(Icons.person,
                                                                color:
                                                                    subTextColor,
                                                                size: 12)
                                                            : null,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                rProfile?[
                                                                        'full_name'] ??
                                                                    'مجهول',
                                                                style: TextStyle(
                                                                    fontFamily:
                                                                        'Cairo',
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color:
                                                                        textColor)),
                                                            Text(
                                                                r['content'] ??
                                                                    '',
                                                                style: TextStyle(
                                                                    fontFamily:
                                                                        'Cairo',
                                                                    fontSize:
                                                                        12,
                                                                    height: 1.4,
                                                                    color:
                                                                        subTextColor)),
                                                            if (isReplyOwner)
                                                              GestureDetector(
                                                                onTap: () =>
                                                                    _showReplyOptions(
                                                                        r),
                                                                child: Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        top: 2),
                                                                    child: Icon(
                                                                        Icons
                                                                            .more_horiz,
                                                                        color:
                                                                            subTextColor,
                                                                        size:
                                                                            16)),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // ✅ زر الإعجاب متوسط مع الرد
                                                      _buildLikeButton(
                                                          isLiked: isReplyLiked,
                                                          count: replyLikeCount,
                                                          onTap: () =>
                                                              _toggleReplyLike(
                                                                  replyId),
                                                          subTextColor:
                                                              subTextColor,
                                                          size: 18),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              if (_replyingToCommentId != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: brandRed.withValues(alpha: 0.05),
                  child: Row(children: [
                    Text("رد على $_replyingToUserName",
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: brandRed,
                            fontSize: 12)),
                    const Spacer(),
                    GestureDetector(
                        onTap: () => setState(() {
                              _replyingToCommentId = null;
                              _replyingToUserName = null;
                            }),
                        child:
                            Icon(Icons.close, color: subTextColor, size: 16)),
                  ]),
                ),
              Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    left: 16,
                    right: 16,
                    top: 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: _replyingToCommentId != null
                            ? "اكتب رداً..."
                            : "أضف تعليقاً...",
                        hintStyle:
                            TextStyle(fontFamily: 'Cairo', color: subTextColor),
                        filled: true,
                        fillColor: widget.isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.grey.withValues(alpha: 0.08),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendComment,
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                            color: brandRed, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
