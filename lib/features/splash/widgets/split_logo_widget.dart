import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../splash_constants.dart';
import 'motion_blur_painter.dart';

/// The LaundryBrew mark rendered as its two real designed pieces (hook +
/// goggles), cropped directly out of the decoded source image at the seam
/// the artwork already has — not a blind 50/50 slice of the whole asset
/// (which also contains the baked-in wordmark further down the canvas).
///
/// [splitProgress] is 0 at rest (source art's natural gap only) and 1 at
/// full extra travel — driven by the storyboard's open/close
/// [TweenSequence] in [SplashScreen]. [blurIntensity] pulses 0→1→0 only
/// while the halves are actually moving: it drives the directional
/// vertical blur on the pieces themselves plus the horizontal
/// light-streak flash painted at the seam.
class SplitLogoWidget extends StatelessWidget {
  final ui.Image image;
  final double size;
  final double splitProgress;
  final double blurIntensity;

  const SplitLogoWidget({
    super.key,
    required this.image,
    required this.size,
    required this.splitProgress,
    required this.blurIntensity,
  });

  @override
  Widget build(BuildContext context) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final left = SplashConstants.markCropLeftFrac * w;
    final right = SplashConstants.markCropRightFrac * w;
    final top = SplashConstants.markCropTopFrac * h;
    final bottom = SplashConstants.markCropBottomFrac * h;
    final seam = SplashConstants.markSeamFrac * h;

    final topSrc = Rect.fromLTRB(left, top, right, seam);
    final bottomSrc = Rect.fromLTRB(left, seam, right, bottom);
    final cropWidth = right - left;

    final topDstH = size * topSrc.height / cropWidth;
    final bottomDstH = size * bottomSrc.height / cropWidth;

    final travel = size * SplashConstants.splitGapFactor * splitProgress;
    final blurSigma = blurIntensity * 2.6;

    // Distortion signals — derived directly from blurIntensity so they are
    // exactly synchronized with the motion-blur bell: 0 at rest (open/
    // closed/hold), peaking precisely when blurIntensity peaks, and gone
    // the instant movement stops. See SplashConstants for rationale.
    final stretchAmount = blurIntensity * SplashConstants.distortionStretchPeak;
    final skewAmount = blurIntensity * SplashConstants.distortionSkewPeak;
    final smearSigma = blurIntensity * SplashConstants.distortionSmearSigmaPeak;
    final centerDisplacement =
        blurIntensity * SplashConstants.distortionCenterDisplacementPeak;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (blurIntensity > 0.01)
          Positioned.fill(
            child: CustomPaint(
              painter: MotionBlurPainter(
                intensity: blurIntensity,
                streakWidth: size * 3.0,
                centerY: topDstH,
              ),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top piece: pivoted at its bottom edge (the seam) so the
            // stretch/skew reads as the piece being dragged away from the
            // tear line, not leaning as a rigid block.
            Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(0, 0, 1 + stretchAmount)
                ..setEntry(0, 1, skewAmount),
              child: Transform.translate(
                offset: Offset(centerDisplacement, -travel),
                child: _LogoPiece(
                  image: image,
                  srcRect: topSrc,
                  dstSize: Size(size, topDstH),
                  blurIntensity: blurIntensity,
                  blurSigma: blurSigma,
                  smearSigma: smearSigma,
                ),
              ),
            ),
            // Bottom piece: pivoted at its top edge (the seam), skew and
            // center displacement mirrored from the top piece.
            Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(0, 0, 1 + stretchAmount)
                ..setEntry(0, 1, -skewAmount),
              child: Transform.translate(
                offset: Offset(-centerDisplacement, travel),
                child: _LogoPiece(
                  image: image,
                  srcRect: bottomSrc,
                  dstSize: Size(size, bottomDstH),
                  blurIntensity: blurIntensity,
                  blurSigma: blurSigma,
                  smearSigma: smearSigma,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One logo piece: a soft blurred bloom halo behind it (visible only while
/// [blurIntensity] is above zero, i.e. only during movement) plus the crisp
/// piece itself with a subtle directional (vertical) motion blur riding on
/// top of it.
class _LogoPiece extends StatelessWidget {
  final ui.Image image;
  final Rect srcRect;
  final Size dstSize;
  final double blurIntensity;
  final double blurSigma;

  /// Extra horizontal blur sigma, on top of [blurSigma]'s vertical motion
  /// blur, so the smear reads as coming from the horizontal light streak
  /// rather than purely from the piece's vertical travel.
  final double smearSigma;

  const _LogoPiece({
    required this.image,
    required this.srcRect,
    required this.dstSize,
    required this.blurIntensity,
    required this.blurSigma,
    required this.smearSigma,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (blurIntensity > 0.02)
          Opacity(
            opacity: (blurIntensity * 0.85).clamp(0.0, 1.0),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 6 + blurIntensity * 8 + smearSigma,
                sigmaY: 6 + blurIntensity * 8,
              ),
              child: CustomPaint(
                size: dstSize,
                painter: _LogoPiecePainter(image: image, srcRect: srcRect),
              ),
            ),
          ),
        ImageFiltered(
          enabled: blurSigma > 0.05 || smearSigma > 0.05,
          imageFilter: ui.ImageFilter.blur(sigmaX: smearSigma, sigmaY: blurSigma),
          child: CustomPaint(
            size: dstSize,
            painter: _LogoPiecePainter(image: image, srcRect: srcRect),
          ),
        ),
      ],
    );
  }
}

class _LogoPiecePainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;

  const _LogoPiecePainter({required this.image, required this.srcRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      image,
      srcRect,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPiecePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.srcRect != srcRect;
}
