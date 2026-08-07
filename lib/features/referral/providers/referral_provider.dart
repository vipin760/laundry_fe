import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/referral_api.dart';
import '../models/referral_models.dart';

// ── State ────────────────────────────────────────────────────────────────────

class ReferralState {
  const ReferralState({
    this.my = MyReferral.empty,
    this.recent = const [],
    this.history = const [],
    this.program = const ReferralProgram(),
    this.hasReferrer = true, // true hides the apply card until we know better
    this.isLoading = false,
    this.isApplying = false,
    this.error,
  });

  final MyReferral my;
  final List<ReferralHistoryItem> recent; // small list for the home screen
  final List<ReferralHistoryItem> history; // full paginated list
  final ReferralProgram program;

  /// Whether the current user has already been referred by someone.
  /// Controls the "Have a referral code?" card on the home screen.
  final bool hasReferrer;

  final bool isLoading;
  final bool isApplying;
  final String? error;

  ReferralState copyWith({
    MyReferral? my,
    List<ReferralHistoryItem>? recent,
    List<ReferralHistoryItem>? history,
    ReferralProgram? program,
    bool? hasReferrer,
    bool? isLoading,
    bool? isApplying,
    String? error,
    bool clearError = false,
  }) {
    return ReferralState(
      my: my ?? this.my,
      recent: recent ?? this.recent,
      history: history ?? this.history,
      program: program ?? this.program,
      hasReferrer: hasReferrer ?? this.hasReferrer,
      isLoading: isLoading ?? this.isLoading,
      isApplying: isApplying ?? this.isApplying,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ReferralNotifier extends Notifier<ReferralState> {
  final _api = const ReferralApi();

  @override
  ReferralState build() {
    // Gate on auth restoration rather than fetching unconditionally: on
    // web this provider can build before session restore (async) finishes,
    // and fetching before we know the user is logged in sends an
    // unauthenticated request. Watching authProvider re-triggers this once
    // restore completes (or login state actually changes).
    final auth = ref.watch(authProvider);
    final willFetch = auth.isInitialized && auth.isAuthenticated;
    if (willFetch) {
      Future.microtask(loadDashboard);
    }
    // isLoading only makes sense while a fetch is actually pending — for a
    // logged-out (or not-yet-restored) user there is no in-flight request
    // to wait on, so it must not be left stuck true.
    return ReferralState(isLoading: willFetch);
  }

  /// Load the Refer & Earn home payload (code, stats, recent, programme rules).
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.fetchDashboard();
      state = state.copyWith(
        isLoading: false,
        my: result.my,
        recent: result.recent,
        program: result.program,
        hasReferrer: result.hasReferrer,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  /// Load the full, paginated history (My Referrals screen).
  Future<void> loadHistory({int page = 1, int limit = 20}) async {
    try {
      final items = await _api.fetchHistory(page: page, limit: limit);
      state = state.copyWith(
        history: page == 1 ? items : [...state.history, ...items],
      );
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  /// Validate a code (used on the registration/enter-code screen).
  Future<String?> validate(String code) async {
    try {
      return await _api.validate(code);
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      return null;
    }
  }

  /// Apply a referral code for the current user (post-registration).
  /// Returns true on success. Re-entrant calls (double taps) are ignored
  /// while a request is already in flight.
  Future<bool> apply(String code, {Map<String, dynamic>? context}) async {
    if (state.isApplying) return false; // request deduplication
    state = state.copyWith(isApplying: true, clearError: true);
    try {
      await _api.apply(code, context: context);
      state = state.copyWith(isApplying: false);
      await loadDashboard();
      return true;
    } catch (e) {
      state = state.copyWith(isApplying: false, error: _msg(e));
      return false;
    }
  }

  Future<void> refresh() => loadDashboard();

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
}

/// Global provider for referral state.
final referralProvider =
    NotifierProvider<ReferralNotifier, ReferralState>(ReferralNotifier.new);
