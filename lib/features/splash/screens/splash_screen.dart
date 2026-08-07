import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../splash_constants.dart';
import '../widgets/split_logo_widget.dart';

// ══════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN — "open, close, open, close, reveal" brand animation
//
// Single AnimationController (4100ms) split into eight segments. Every
// TweenSequence's item weights are each segment's duration in ms, so
// controller time maps 1:1 onto this timeline (see SplashConstants).
// The logo fully closes (segment 7) BEFORE the brand text appears — the
// wordmark only shows up once the mark has settled shut, not while it's
// still open:
//
//   Seg  Name            ms range     splitProgress          blur peak
//   1    Closed             0- 350    0 (const)              -
//   2    Opens            350- 850    0→1 _openCurve         early, held
//   3    Hold open        850-1450    1 (const)              -
//   4    Closes          1450-1950    1→0 _closeCurve        mid, held
//   5    Hold closed     1950-2450    0 (const)               -
//   6    Opens again     2450-2950    0→1 _openCurve         early, held
//   7    Closes again    2950-3450    1→0 _closeCurve        mid, held
//   8    Brand reveal    3450-4100    0 (const, stays closed) -
//
// _openCurve is a soft spring-overshoot bezier (gentler than stock
// easeOutBack); _closeCurve is sine-based for a smooth, gradual glide with
// no overshoot. `blurIntensity`'s bell shape tracks each curve's real
// velocity profile (front-loaded for spring-opens, centered for
// sine-eased closes) with a genuine plateau at peak brightness — not just
// an instantaneous spike — so the flash has time to actually register.
// Segment 8 has no split motion, so no blur.
//
// `_textReveal` fades the brand lockup in across the whole of segment 8.
// `_lockupScale` holds 1.0 through segment 7, then — at the very start of
// segment 8, once the logo is already closed — pops 0.97→1.0 over
// [SplashConstants.lockupPopMs] as a pure scale flourish, holding 1.0 for
// the rest of the brand reveal.
//
// 200ms after the controller completes, navigation fires once auth state
// is known.
// ══════════════════════════════════════════════════════════════════════════

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _splitProgress;
  late final Animation<double> _blurIntensity;
  late final Animation<double> _textReveal;
  late final Animation<double> _lockupScale;

  ui.Image? _logoImage;
  bool _animationDone = false;
  bool _navigated = false;
  ProviderSubscription<dynamic>? _authSub;

  static const _f1 = SplashConstants.frame1ClosedMs;
  static const _f2 = SplashConstants.frame2OpenMs;
  static const _f3 = SplashConstants.frame3HoldOpenMs;
  static const _f4 = SplashConstants.frame4CloseMs;
  static const _f5 = SplashConstants.frame5HoldClosedMs;
  static const _f6 = SplashConstants.frame6OpenMs;
  static const _f7 = SplashConstants.frame7CloseAgainMs;
  static const _f8 = SplashConstants.frame8BrandMs;
  static const _pop = SplashConstants.lockupPopMs;

  /// Gentle spring for opening — a softer overshoot bezier than the stock
  /// easeOutBack (whose y-control point of ~1.70 reads as a sharper snap).
  static const Curve _openCurve = Cubic(0.30, 1.15, 0.55, 1.0);

  /// Sine-based ease for closing — a smoother, more gradual deceleration
  /// than a cubic S-curve, with no overshoot.
  static const Curve _closeCurve = Curves.easeInOutSine;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ctrl = AnimationController(
      vsync: this,
      duration: SplashConstants.controllerDuration,
    );

    // ── Segments 1–8: logo split/close progress (0 = closed, 1 = open) ─────
    // Opening segments use _openCurve — a soft spring-overshoot bezier —
    // for a tiny, premium arrival bounce; closing segments use
    // _closeCurve (sine-based, no overshoot) for a smooth, gradual glide
    // to a stop.
    _splitProgress = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: _f1.toDouble()), // 1
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: _openCurve)),
        weight: _f2.toDouble(),
      ), // 2
      TweenSequenceItem(tween: ConstantTween(1.0), weight: _f3.toDouble()), // 3
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: _closeCurve)),
        weight: _f4.toDouble(),
      ), // 4
      TweenSequenceItem(tween: ConstantTween(0.0), weight: _f5.toDouble()), // 5
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: _openCurve)),
        weight: _f6.toDouble(),
      ), // 6
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: _closeCurve)),
        weight: _f7.toDouble(),
      ), // 7: closes again — this is the logo's final resting state
      TweenSequenceItem(tween: ConstantTween(0.0), weight: _f8.toDouble()), // 8
    ]).animate(_ctrl);

    // ── Motion-blur pulse: shaped per-segment to track each curve's real
    // velocity profile, not just segment-time. Spring-opens are
    // front-loaded (easeOutBack is fastest right as it starts); closes are
    // centered (easeInOutCubic peaks at its midpoint). Kept narrow — "very
    // brief" — relative to each segment. Segment 8 has no split motion, so
    // no blur at all.
    _blurIntensity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: _f1.toDouble()),
      ..._openBell(_f2), // 2
      TweenSequenceItem(tween: ConstantTween(0.0), weight: _f3.toDouble()),
      ..._closeBell(_f4), // 4
      TweenSequenceItem(tween: ConstantTween(0.0), weight: _f5.toDouble()),
      ..._openBell(_f6), // 6
      ..._closeBell(_f7), // 7
      TweenSequenceItem(tween: ConstantTween(0.0), weight: _f8.toDouble()),
    ]).animate(_ctrl);

    // ── Segment 8 only: brand lockup fade + upward ease, logo already closed
    _textReveal = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(
        (_f1 + _f2 + _f3 + _f4 + _f5 + _f6 + _f7) / SplashConstants.totalMs,
        1.0,
        curve: Curves.easeOut,
      ),
    );

    // ── Start of segment 8 only: the whole lockup (logo + wordmark +
    // tagline) pops 0.97→1.00 as one unit — a pure scale flourish, since
    // the logo has already finished closing by segment 7.
    _lockupScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: (_f1 + _f2 + _f3 + _f4 + _f5 + _f6 + _f7).toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.97, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: _pop.toDouble(),
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: (_f8 - _pop).toDouble()),
    ]).animate(_ctrl);

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationDone = true;
        Future.delayed(SplashConstants.postAnimationDelay, _tryNavigate);
      }
    });

    _authSub = ref.listenManual(authProvider, (_, next) {
      if (next.isInitialized) _tryNavigate();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isInitialized) _tryNavigate();
    });

    _loadLogoImage();
  }

  Future<void> _loadLogoImage() async {
    final data = await rootBundle.load(SplashConstants.logoAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _logoImage = frame.image);
    _ctrl.forward();
  }

  /// Front-loaded blur bell for spring-opening segments: rises fast (12%
  /// of the segment, matching easeOutBack's early speed), *holds* at peak
  /// brightness for a real stretch (18%) so the flash is actually visible
  /// rather than a one-frame spike, fades over the next 20%, then stays
  /// silent for the remainder while the spring gently settles.
  static List<TweenSequenceItem<double>> _openBell(int segMs, {double peak = 1.0}) {
    final rise = segMs * 0.12;
    final hold = segMs * 0.18;
    final fall = segMs * 0.20;
    final tail = segMs - rise - hold - fall;
    return [
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: peak).chain(CurveTween(curve: Curves.easeOut)),
        weight: rise,
      ),
      TweenSequenceItem(tween: ConstantTween(peak), weight: hold),
      TweenSequenceItem(
        tween: Tween(begin: peak, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: fall,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: tail),
    ];
  }

  /// Centered blur bell for easeInOutCubic closing segments: silent for the
  /// first 25% (curve hasn't sped up yet), rise+hold+fall spanning the
  /// midpoint where velocity peaks — with a genuine hold at peak, not an
  /// instantaneous spike — then silent for the remainder.
  static List<TweenSequenceItem<double>> _closeBell(int segMs, {double peak = 1.0}) {
    final head = segMs * 0.25;
    final rise = segMs * 0.12;
    final hold = segMs * 0.16;
    final fall = segMs * 0.12;
    final tail = segMs - head - rise - hold - fall;
    return [
      TweenSequenceItem(tween: ConstantTween(0.0), weight: head),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: peak).chain(CurveTween(curve: Curves.easeOut)),
        weight: rise,
      ),
      TweenSequenceItem(tween: ConstantTween(peak), weight: hold),
      TweenSequenceItem(
        tween: Tween(begin: peak, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: fall,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: tail),
    ];
  }

  void _tryNavigate() {
    if (_navigated || !mounted || !_animationDone) return;
    final auth = ref.read(authProvider);
    if (!auth.isInitialized) return;
    _navigated = true;

    // If we were redirected here by the router's auth-initialization
    // barrier (see app_router.dart), `from` carries the route the user
    // actually asked for (e.g. a browser refresh on /wallet) so we land
    // back there instead of always bouncing to /home. The router's
    // `redirect` re-runs on this navigation and will still correct it
    // (e.g. bounce to /auth/login if unauthenticated, or to the delivery
    // partner home if applicable) — this just picks the best default.
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final fallback = auth.isAuthenticated ? AppRoutes.home : AppRoutes.login;
    final target = (from != null && from.isNotEmpty && from != AppRoutes.splash)
        ? from
        : fallback;
    context.go(target);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _authSub?.close();
    _logoImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoImage = _logoImage;
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final logoSize = shortestSide * SplashConstants.logoSizeFactor;

    return Scaffold(
      backgroundColor: SplashConstants.backgroundColor,
      body: logoImage == null
          ? const SizedBox.shrink()
          : RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final textT = _textReveal.value;
                  // Logo + wordmark + tagline animate as a single brand
                  // lockup: one shared scale for the final settle pop.
                  return Center(
                    child: Transform.scale(
                      scale: _lockupScale.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SplitLogoWidget(
                            image: logoImage,
                            size: logoSize,
                            splitProgress: _splitProgress.value,
                            blurIntensity: _blurIntensity.value,
                          ),
                          SizedBox(height: logoSize * 0.05),
                          Opacity(
                            opacity: textT,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - textT)),
                              child: const _BrandText(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// BRAND TEXT — frame 8 payoff, shown only once the logo is closed
// ══════════════════════════════════════════════════════════════════════════

class _BrandText extends StatelessWidget {
  const _BrandText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'laundrybrew',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'unleash your potential',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
