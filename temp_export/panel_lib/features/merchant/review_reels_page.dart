import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:red_market_core/red_market_core.dart';

class ReviewReelsPage extends StatefulWidget {
  final ReelModel reel;

  const ReviewReelsPage({
    super.key,
    required this.reel,
  });

  @override
  State<ReviewReelsPage> createState() => _ReviewReelsPageState();
}

class _ReviewReelsPageState extends State<ReviewReelsPage> {
  VideoPlayerController? _controller;
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _showPauseIcon = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reel.isLikedByMe;
    _initializePlayer();
  }

  // ✅ تهيئة محسنة تضمن التشغيل الفوري ومعالجة أخطاء التحميل
  Future<void> _initializePlayer() async {
    try {
      final String rawUrl = widget.reel.videoUrl.trim();
      final Uri videoUri = Uri.parse(rawUrl);

      if (!videoUri.isAbsolute || videoUri.host.isEmpty) {
        debugPrint("❌ رابط الفيديو غير صالح: $rawUrl");
        return;
      }

      // 1. استخدام خيارات التهيئة لضمان التشغيل السلس
      _controller = VideoPlayerController.networkUrl(
        videoUri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      // 2. إضافة مستمع لمراقبة التقدم وحالة الخطأ
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          debugPrint(
              "❌ Video Player Error: ${_controller!.value.errorDescription}");
        }

        // الانتقال للحالة الجاهزة بمجرد اكتمال التهيئة والبدء في التخزين المؤقت
        if (_controller!.value.isInitialized && !_isInitialized) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
            _controller!.play();
            _controller!.setLooping(true);
          }
        }
      });

      // 3. بدء التهيئة
      await _controller!.initialize();
    } catch (e) {
      debugPrint("❌ خطأ فني أثناء تهيئة الفيديو: $e");
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(() {});
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showPauseIcon = true;
      } else {
        _controller!.play();
        _showPauseIcon = false;
      }
    });

    if (_showPauseIcon) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _showPauseIcon = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand, // ✅ هذا السطر هو الحل الجذري للمشكلة
        children: [
          // 🎥 مشغل الفيديو (تم التعديل ليملأ الشاشة بالكامل - Full Screen Cover)
          Positioned.fill(
            child: _isInitialized && _controller != null
                ? GestureDetector(
                    onTap: _togglePlay,
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover, // ✅ تكبير الفيديو ليغطي كامل المساحة
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    ),
                  )
                : _buildLoadingState(),
          ),

          if (_showPauseIcon)
            const Center(
              child: Icon(Icons.play_arrow_rounded,
                  size: 80, color: Colors.white54),
            ),

          _buildGradientOverlay(),
          _buildTopHeader(), // ✅ تم تعديل هذه الدالة
          _buildRightSidebar(),
          _buildBottomDetails(),

          // 📊 شريط التقدم السفلي
          if (_isInitialized && _controller != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF4CAF50),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF4CAF50),
            strokeWidth: 2,
          ),
          SizedBox(height: 15),
          Text("جاري تحميل المقطع...",
              style: TextStyle(
                  color: Colors.white70, fontFamily: 'Cairo', fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.2, 0.7, 1.0],
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ التعديل هنا: تم حذف النصوص وإبقاء زر الرجوع فقط
  Widget _buildTopHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightSidebar() {
    return Positioned(
      right: 12,
      bottom: 100,
      child: Column(
        children: [
          _buildProfileIcon(),
          const SizedBox(height: 25),
          _sidebarIcon(
            _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            "${widget.reel.likesCount}",
            color: _isLiked ? Colors.red : Colors.white,
            onTap: () => setState(() => _isLiked = !_isLiked),
          ),
          const SizedBox(height: 20),
          _sidebarIcon(Icons.comment_rounded, "${widget.reel.commentsCount}"),
          const SizedBox(height: 20),
          _sidebarIcon(
            _isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            "حفظ",
            color: _isBookmarked ? Colors.amber : Colors.white,
            onTap: () => setState(() => _isBookmarked = !_isBookmarked),
          ),
          const SizedBox(height: 20),
          _sidebarIcon(Icons.share_rounded, "مشاركة"),
        ],
      ),
    );
  }

  Widget _buildProfileIcon() {
    final String imgUrl = widget.reel.merchantProfileImage.trim();
    final bool hasProfileImage = imgUrl.startsWith('http');

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[300],
            backgroundImage: hasProfileImage ? NetworkImage(imgUrl) : null,
            child: !hasProfileImage
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
        ),
        Positioned(
          bottom: -10,
          child: Container(
            decoration: const BoxDecoration(
                color: Color(0xFF4CAF50), shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomDetails() {
    return Positioned(
      left: 15,
      bottom: 40,
      right: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("@${widget.reel.merchantName}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Cairo')),
              const SizedBox(width: 8),
              const Icon(Icons.verified, color: Colors.blue, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.reel.description != null &&
              widget.reel.description!.isNotEmpty)
            Text(
              widget.reel.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Cairo',
                  height: 1.4),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 5),
              Text("Original Audio - ${widget.reel.merchantName}",
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidebarIcon(IconData icon, String label,
          {Color color = Colors.white, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo'))
          ],
        ),
      );
}
