import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_text.dart';
import '../models/order_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OrderPhotoGallery — horizontal thumbnail strip + full-screen zoomable viewer.
// Used for:
//   • Findings / item-condition photos (damage evidence, with notes)
//   • Weight verification photos (scale reading, bill proof)
// Thumbnails are decoded at reduced size (cacheWidth) for smooth scrolling.
// ─────────────────────────────────────────────────────────────────────────────

const _kText  = Color(0xFF0A1645);
const _kMuted = Color(0xFF7D86A5);

class OrderPhotoGallery extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final List<OrderPhotoModel> photos;

  const OrderPhotoGallery({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(title,
                    fontSize: 16, fontWeight: FontWeight.w800, color: _kText),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText('${photos.length}',
                    fontSize: 12, fontWeight: FontWeight.w800, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppText(subtitle, fontSize: 12, color: _kMuted),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _Thumb(
                photo: photos[i],
                accent: accent,
                onTap: () => _openViewer(context, i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullScreenViewer(
          title: title,
          photos: photos,
          initialIndex: index,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ── Thumbnail ────────────────────────────────────────────────────────────────

class _Thumb extends StatelessWidget {
  final OrderPhotoModel photo;
  final Color accent;
  final VoidCallback onTap;

  const _Thumb({required this.photo, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'order-photo-${photo.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Image.network(
                photo.url,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                // Decode at thumbnail resolution — big memory/perf win
                cacheWidth: 240,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        width: 96,
                        height: 96,
                        color: const Color(0xFFF0F2F8),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: accent),
                          ),
                        ),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  color: const Color(0xFFF0F2F8),
                  child: const Icon(Icons.broken_image_outlined,
                      color: _kMuted, size: 24),
                ),
              ),
              if (photo.note != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Text(
                      photo.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full-screen viewer (swipe + pinch-zoom) ──────────────────────────────────

class _FullScreenViewer extends StatefulWidget {
  final String title;
  final List<OrderPhotoModel> photos;
  final int initialIndex;

  const _FullScreenViewer({
    required this.title,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: AppText(
          '${widget.title} · ${_index + 1}/${widget.photos.length}',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final p = widget.photos[i];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: 'order-photo-${p.id}',
                      child: Image.network(
                        p.url,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white54),
                                  ),
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 48),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: [
                  if (photo.note != null)
                    AppText(photo.note!,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        textAlign: TextAlign.center),
                  if (photo.uploadedAt != null) ...[
                    const SizedBox(height: 4),
                    AppText(
                      DateFormat('MMM dd, yyyy · hh:mm a')
                          .format(photo.uploadedAt!),
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
