import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/payment_config.dart';
import '../../../core/payments/app_razorpay.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

const _kBlue     = Color(0xFF2453FF);
const _kBlueDark = Color(0xFF1A3FCC);
const _kBg       = Color(0xFFF5F6FA);

const _kPresets = [100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0];

class AddMoneyScreen extends ConsumerStatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  ConsumerState<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends ConsumerState<AddMoneyScreen> {
  final _amountCtrl = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  late final AppRazorpay _razorpay;

  bool   _loading       = false;
  double? _selectedPreset;

  // Pending payment details (needed for verify call)
  String? _pendingWalletTxnId;
  String? _pendingRazorpayOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = AppRazorpay();
    _razorpay.on(AppRazorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(AppRazorpay.EVENT_PAYMENT_ERROR, _onPayError);
    _razorpay.on(AppRazorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _razorpay.clear();
    super.dispose();
  }

  // ── Amount helpers ──────────────────────────────────────────────────────────

  double? get _enteredAmount {
    final v = double.tryParse(_amountCtrl.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  void _selectPreset(double amount) {
    setState(() {
      _selectedPreset = amount;
      _amountCtrl.text = amount.toInt().toString();
    });
  }

  // ── Pay flow ────────────────────────────────────────────────────────────────

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _enteredAmount!;

    setState(() => _loading = true);

    try {
      final order = await ref
          .read(walletProvider.notifier)
          .createAddMoneyOrder(amount);

      _pendingWalletTxnId       = order['walletTxnId']?.toString();
      _pendingRazorpayOrderId   = order['razorpayOrderId']?.toString();
      final razorpayAmount     = order['amount'] as int; // paise

      final user = ref.read(authProvider).user;

      // Same checkout mechanism as order payments (orders_screen.dart) —
      // opens Checkout.js and returns once the modal is up; the actual
      // result arrives asynchronously via the EVENT_PAYMENT_SUCCESS /
      // EVENT_PAYMENT_ERROR callbacks registered in initState().
      _razorpay.open({
        'key': PaymentConfig.razorpayKeyId,
        'amount': razorpayAmount,
        'currency': 'INR',
        'name': 'LaundryBrew',
        'order_id': _pendingRazorpayOrderId,
        'description': 'Wallet Top-up',
        'prefill': {
          'email': user?.email ?? '',
          'contact': user?.mobileNumber ?? '',
        },
      });

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Could not initiate payment: $e', isError: true);
      }
    }
  }

  void _onPayError(PaymentFailureResponse r) {
    // Do NOT treat this as a failed wallet transaction — Razorpay was
    // dismissed/failed client-side; the pending transaction stays as-is
    // server-side so the user can simply tap "Proceed to Pay" again.
    if (!mounted) return;
    setState(() => _loading = false);
    _showSnack(r.message ?? 'Payment failed. Please try again.', isError: true);
  }

  void _onPaySuccess(PaymentSuccessResponse r) async {
    if (_pendingWalletTxnId == null || _pendingRazorpayOrderId == null) return;
    try {
      final newBalance = await ref
          .read(walletProvider.notifier)
          .verifyAddMoney(
            walletTxnId:        _pendingWalletTxnId!,
            razorpayOrderId:    _pendingRazorpayOrderId!,
            razorpayPaymentId:  r.paymentId!,
            razorpaySignature:  r.signature!,
          );

      if (!mounted) return;
      setState(() => _loading = false);

      final fmt = NumberFormat.currency(
          locale: 'en_IN', symbol: '₹', decimalDigits: 2);
      _showSuccessSheet(fmt.format(newBalance));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Payment verification failed. Please contact support.', isError: true);
    }
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _kBlue,
    ));
  }

  void _showSuccessSheet(String newBalance) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SuccessSheet(
        newBalance: newBalance,
        onDone: () {
          Navigator.of(context).pop(); // close sheet
          Navigator.of(context).pop(); // back to wallet
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Add Money',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Gradient info card ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kBlue, _kBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top-up your wallet',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('Funds added instantly via Razorpay',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13)),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Quick amounts ──────────────────────────────────────────────
              const Text('Choose Amount',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black87)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kPresets.map((amt) {
                  final isSelected = _selectedPreset == amt;
                  return GestureDetector(
                    onTap: () => _selectPreset(amt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _kBlue : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected ? _kBlue : const Color(0xFFD1D5DB),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: _kBlue.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3))
                              ]
                            : [],
                      ),
                      child: Text(
                        '₹${amt.toInt()}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── Custom amount ──────────────────────────────────────────────
              const Text('Or Enter Amount',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black87)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                onChanged: (_) {
                  if (_selectedPreset != null) {
                    setState(() => _selectedPreset = null);
                  }
                },
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
                decoration: InputDecoration(
                  prefixText: '₹  ',
                  prefixStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54),
                  hintText: '0',
                  hintStyle:
                      TextStyle(fontSize: 16, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFD1D5DB), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _kBlue, width: 1.8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFEF4444), width: 1.2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFEF4444), width: 1.8),
                  ),
                ),
                validator: (v) {
                  final val = double.tryParse(v?.trim() ?? '');
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  if (val < 1) return 'Minimum amount is ₹1';
                  if (val > 100000) return 'Maximum amount is ₹1,00,000';
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // ── Pay button ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlueDark,
                    disabledBackgroundColor:
                        _kBlueDark.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Proceed to Pay',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Powered by ────────────────────────────────────────────────
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.security_rounded,
                        size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 5),
                    Text('Secured by Razorpay',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Success Bottom Sheet ───────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.newBalance, required this.onDone});
  final String newBalance;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 42),
          ),
          const SizedBox(height: 18),
          const Text('Money Added!',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text('New wallet balance: $newBalance',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2453FF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Back to Wallet',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
