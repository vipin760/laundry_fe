import 'package:flutter/material.dart';

/// Storyboard-derived timing, colours and geometry for the LaundryBrew
/// "simple open close" splash animation. Every value here maps directly
/// to a frame in the approved storyboard — see [SplashScreen] for how
/// the frames are assembled into a single [AnimationController] timeline.
abstract final class SplashConstants {
  static const Color backgroundColor = Color(0xFF0D2DBB);
  static const String logoAsset = 'assets/images/icon.png';

  // ── Storyboard frame durations (ms) — each beat given room to register ───
  static const int frame1ClosedMs = 350; // 1. Logo closed
  static const int frame2OpenMs = 500; // 2. Logo opens (spring)
  static const int frame3HoldOpenMs = 600; // 3. Logo remains open
  static const int frame4CloseMs = 500; // 4. Logo closes
  static const int frame5HoldClosedMs = 500; // 5. Logo closed (pause)
  static const int frame6OpenMs = 500; // 6. Logo opens again (spring)
  static const int frame7CloseAgainMs = 500; // 7. Logo closes for good
  static const int frame8BrandMs = 650; // 8. Logo stays closed; brand fades in

  /// Portion of [frame8BrandMs], at its start, spent on the lockup's
  /// 0.97→1.00 settle-pop — the logo is already closed by then, so this is
  /// a pure scale flourish, not a split motion.
  static const int lockupPopMs = 220;

  static const int totalMs = frame1ClosedMs +
      frame2OpenMs +
      frame3HoldOpenMs +
      frame4CloseMs +
      frame5HoldClosedMs +
      frame6OpenMs +
      frame7CloseAgainMs +
      frame8BrandMs; // 4100ms

  static const Duration controllerDuration = Duration(milliseconds: totalMs);

  /// Extra pause after the controller finishes, before navigating away.
  static const Duration postAnimationDelay = Duration(milliseconds: 200);

  // ── Logo geometry ─────────────────────────────────────────────────────────
  static const double logoSizeFactor = 0.38; // of the shortest screen side

  /// Each half's *additional* travel beyond its resting position, as a
  /// fraction of the rendered mark width. The source art already has a
  /// small natural gap between the two pieces at rest (see markSeamFrac
  /// below) — this is the extra opening distance on top of that. Large
  /// enough that the open state is unmistakable, not just detectable.
  static const double splitGapFactor = 0.32;

  // ── Source-art crop (measured from assets/images/icon.png, 1024x1024) ───
  // icon.png bakes the mark AND the "laundrybrew" wordmark into one PNG on
  // a much larger canvas. Alpha-channel analysis (row-by-row solid-pixel
  // scan) found four content bands: the hook glyph (rows 178-313), a real
  // 22px resting gap (314-335), the goggles glyph (336-492), then the
  // wordmark text starting at row 559 — which must NOT be included in the
  // cropped mark, or it duplicates against the separately-animated
  // brand text in frame 7. These fractions crop tightly to just the mark
  // (with a small symmetric margin) and mark the pieces' natural seam.
  //
  // markCropRightFrac was widened from 681/1024 after the logo artwork's
  // right edge was redrawn with a smooth curve (previously boxy/angular)
  // that reaches column 688 — 7px past the old bound — which was clipping
  // the new curve. 708/1024 restores the same ~19px margin the other three
  // edges already have.
  static const double markCropLeftFrac = 329 / 1024;
  static const double markCropRightFrac = 708 / 1024;
  static const double markCropTopFrac = 159 / 1024;
  static const double markCropBottomFrac = 511 / 1024;

  /// Midpoint of the source art's resting gap (rows 314-336) — the exact
  /// row the two pieces are split at when closed.
  static const double markSeamFrac = 325 / 1024;

  // ── Movement distortion ("light tears through logo") ────────────────────
  // stretch/skew/smear/centerDisplacement are all derived directly from
  // blurIntensity (stretch = blurIntensity * peak, etc.) rather than driven
  // by their own TweenSequences — blurIntensity's bell already peaks at
  // each curve's true peak velocity and is exactly 0 during every
  // hold/closed/open segment, so deriving from it guarantees the
  // distortion is perfectly synchronized and vanishes the instant movement
  // stops, with no separate timeline to keep in phase.

  /// Peak horizontal stretch added to each piece's scale at peak velocity.
  static const double distortionStretchPeak = 0.07;

  /// Peak horizontal shear (dx per unit y, pivoted at the seam edge)
  /// applied to each piece at peak velocity — top piece leans this amount
  /// right, bottom piece mirrors it left.
  static const double distortionSkewPeak = 0.16;

  /// Peak extra horizontal blur sigma layered on top of the existing
  /// vertical motion blur, so the smear reads as coming from the
  /// horizontal streak rather than purely from vertical travel.
  static const double distortionSmearSigmaPeak = 5.0;

  /// Peak horizontal nudge applied to each piece (opposite signs) at the
  /// seam, as if the passing light briefly wrenches the tear line sideways.
  static const double distortionCenterDisplacementPeak = 3.0;
}
