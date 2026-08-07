import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_transaction_model.dart';

// ── Models ─────────────────────────────────────────────────────────────────────

class WalletState {
  const WalletState({
    this.balance = 0,
    this.transactions = const [],
    this.isLoading = false,
    this.error,
  });

  final double balance;
  final List<WalletTransactionModel> transactions;
  final bool isLoading;
  final String? error;

  WalletState copyWith({
    double? balance,
    List<WalletTransactionModel>? transactions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() {
    // Depend on auth state rather than firing unconditionally: on web,
    // this provider can be built before session restore (which is async)
    // finishes, and fetching before we know whether the user is logged in
    // causes an unauthenticated 401. Watching authProvider means this
    // rebuilds (and only then fetches) once restore completes or login
    // state actually changes.
    final auth = ref.watch(authProvider);
    if (auth.isInitialized && auth.isAuthenticated) {
      Future.microtask(fetchWallet);
    }
    return const WalletState();
  }

  Future<void> fetchWallet() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await ApiClient.instance.get('/wallet');
      final data = response.data as Map<String, dynamic>;
      state = state.copyWith(
        isLoading: false,
        balance: (data['balance'] as num?)?.toDouble() ?? 0,
        transactions: _parseTxns(data['transactions']),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => fetchWallet();

  /// Creates a Razorpay order for the given [amount] (in INR).
  /// Returns the order payload needed by Razorpay SDK.
  Future<Map<String, dynamic>> createAddMoneyOrder(double amount) async {
    final response = await ApiClient.instance.post(
      '/wallet/add-money/create-order',
      data: {'amount': amount},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Verifies payment and credits wallet. Updates local balance on success.
  Future<double> verifyAddMoney({
    required String walletTxnId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await ApiClient.instance.post(
      '/wallet/add-money/verify',
      data: {
        'walletTxnId': walletTxnId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final newBalance = (data['balance'] as num?)?.toDouble() ?? state.balance;
    // Refresh to pick up the new transaction in the list.
    await fetchWallet();
    return newBalance;
  }

  List<WalletTransactionModel> _parseTxns(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WalletTransactionModel.fromJson)
        .toList();
  }
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(
  WalletNotifier.new,
);

// ── All-transactions async provider ────────────────────────────────────────────

final allTransactionsProvider =
    FutureProvider<List<WalletTransactionModel>>((ref) async {
  final response = await ApiClient.instance.get('/wallet/transactions');
  final data = response.data as Map<String, dynamic>;
  final raw = data['transactions'];
  if (raw is! List) return [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(WalletTransactionModel.fromJson)
      .toList();
});
