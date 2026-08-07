import 'package:flutter/material.dart';

/// Directional horizontal light-streak flash that crosses the logo's split
/// seam while the two pieces are sliding apart or together (storyboard
/// frames 2, 4 and 6). A bright opaque core line plus several
/// gradient-tailed streaks of varying thickness fan out around the seam
/// and extend well beyond the logo's own edges — deliberately bold, so
/// the moment reads instantly rather than as a faint hint. Silent (no
/// paint) outside movement windows.
class MotionBlurPainter extends CustomPainter {
  /// 0 = invisible, 1 = peak brightness. Callers pulse this 0→hold→0
  /// across each movement frame, with a genuine hold at peak so the flash
  /// has time to register — it is never held on during a static frame.
  final double intensity;

  /// Horizontal extent of the streaks, in logical pixels — deliberately
  /// wider than the logo so the streaks appear to shoot past its edges.
  final double streakWidth;

  /// Y position (in this painter's local coordinates) of the split seam.
  final double centerY;

  const MotionBlurPainter({
    required this.intensity,
    required this.streakWidth,
    required this.centerY,
  });

  static const _offsets = [-16.0, -8.0, 0.0, 8.0, 15.0];
  static const _thickness = [2.0, 3.4, 6.0, 3.2, 1.8];
  static const _alphas = [0.45, 0.7, 1.0, 0.65, 0.4];

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.01) return;

    final cx = size.width / 2;
    final spread = 0.5 + intensity * 0.7; // lines fan out as intensity rises

    // Wide ambient flash wash behind everything — this is what sells the
    // "a flash just happened" read at a glance.
    final washRect = Rect.fromCenter(
      center: Offset(cx, centerY),
      width: streakWidth,
      height: 60,
    );
    canvas.drawRect(
      washRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.45 * intensity),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(washRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    for (var i = 0; i < _offsets.length; i++) {
      final y = centerY + _offsets[i] * spread;
      final rect = Rect.fromCenter(
        center: Offset(cx, y),
        width: streakWidth,
        height: _thickness[i],
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: _alphas[i] * intensity),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );
    }

    // Bright opaque core right at the seam — the crisp "edge" of the flash.
    final coreRect = Rect.fromCenter(
      center: Offset(cx, centerY),
      width: streakWidth,
      height: 2.2,
    );
    canvas.drawRect(
      coreRect,
      Paint()..color = Colors.white.withValues(alpha: intensity.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(covariant MotionBlurPainter oldDelegate) =>
      oldDelegate.intensity != intensity ||
      oldDelegate.streakWidth != streakWidth ||
      oldDelegate.centerY != centerY;
}
