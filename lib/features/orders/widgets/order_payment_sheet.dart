import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../checkout/services/payment_service.dart';
import '../../checkout/widgets/coupon_input_widget.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/order_model.dart';

// ── Payment method enum ──────────────────────────────────────────────────────
enum PayMethod { wallet, upi }

// ── Result sent back to caller ───────────────────────────────────────────────
enum PaySheetResult { walletSuccess, upiRequested }

// ── Colours ───────────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2453FF);
const _kPrimaryBg = Color(0xFFEEF2FF);
const _kGreen     = Color(0xFF12B76A);
const _kGreenBg   = Color(0xFFECFDF5);
const _kOrange    = Color(0xFFF79009);
const _kOrangeBg  = Color(0xFFFFF4E5);
const _kRed       = Color(0xFFD92D20);
const _kRedBg     = Color(0xFFFEF3F2);
const _kText      = Color(0xFF0A1645);
const _kMuted     = Color(0xFF7D86A5);

// ═════════════════════════════════════════════════════════════════════════════
// PUBLIC ENTRY POINT — show the bottom sheet and return the result
// ═════════════════════════════════════════════════════════════════════════════

Future<PaySheetResult?> showOrderPaymentSheet(
  BuildContext context,
  OrderModel order,
) {
  return showModalBottomSheet<PaySheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OrderPaymentSheet(order: order),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// PAYMENT BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════

class OrderPaymentSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  const OrderPaymentSheet({super.key, required this.order});

  @override
  ConsumerState<OrderPaymentSheet> createState() => _OrderPaymentSheetState();
}

class _OrderPaymentSheetState extends ConsumerState<OrderPaymentSheet> {
  PayMethod _selectedPayMethod = PayMethod.wallet;
  bool _paying = false;
  String? _payError;
  final _paymentService = PaymentService();

  // Payable amount — starts as the order's bill (already net of any
  // first-order discount) and drops further if a coupon is applied via
  // CouponInputWidget below. applyToOrder() persists the discount
  // server-side, so payOrderWithWallet (which takes no amount param)
  // automatically charges this same figure.
  late double _billAmount = widget.order.billAmount!;

  Future<void> _payWithWallet() async {
    setState(() { _paying = true; _payError = null; });
    try {
      await _paymentService.payOrderWithWallet(orderId: widget.order.id);
      if (!mounted) return;
      Navigator.pop(context, PaySheetResult.walletSuccess);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _paying = false;
        _payError = msg.startsWith('Exception: ') ? msg.substring(11) : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState   = ref.watch(walletProvider);
    final walletBalance = walletState.balance;
    final billAmount    = _billAmount;
    final hasFirstOrderDiscount = widget.order.hasFirstOrderDiscount;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    final walletLoaded    = !walletState.isLoading && walletState.error == null;
    final hasSufficient   = walletLoaded && walletBalance >= billAmount;
    final hasInsufficient = walletLoaded && walletBalance < billAmount;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasFirstOrderDiscount)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(fmt.format(widget.order.originalBillAmount!),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kMuted,
                            decoration: TextDecoration.lineThrough)),
                  ),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Complete Payment',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _kText)),
                    ),
                    Text(fmt.format(billAmount),
                        style: TextStyle(
                            fontSize: hasFirstOrderDiscount ? 22 : 18,
                            fontWeight: FontWeight.w900,
                            color: _kPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${widget.order.displayNumber} · Select a payment method',
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                      ),
                    ),
                    if (hasFirstOrderDiscount) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kGreenBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'You save ${fmt.format(widget.order.firstOrderDiscountAmount!)}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _kGreen),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (hasFirstOrderDiscount) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kGreenBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      // Extra room so the "FIRST ORDER" ribbon (positioned
                      // outside the icon box) doesn't get clipped by the
                      // Row's own bounds.
                      padding: const EdgeInsets.only(bottom: 6, left: 2),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _kGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.card_giftcard_rounded,
                                color: Colors.white, size: 18),
                          ),
                          Positioned(
                            left: -4,
                            bottom: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEC4899),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'FIRST ORDER',
                                style: TextStyle(
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🎉 Special First Order Offer!',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _kGreen,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            'Flat ${fmt.format(widget.order.firstOrderDiscountAmount!)} OFF on your first order',
                            style: const TextStyle(
                                fontSize: 12, color: _kText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '-${fmt.format(widget.order.firstOrderDiscountAmount!)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _kGreen,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ── Scrollable options ────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Coupon code ──────────────────────────────────────
                  CouponInputWidget(
                    orderId: widget.order.id,
                    orderAmount: widget.order.billAmount!,
                    onCouponApplied: (finalAmount) {
                      setState(() => _billAmount = finalAmount);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Wallet card
                  _PayMethodCard(
                    selected: _selectedPayMethod == PayMethod.wallet,
                    onTap: () => setState(() => _selectedPayMethod = PayMethod.wallet),
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: hasSufficient
                            ? _kGreenBg
                            : hasInsufficient
                                ? _kOrangeBg
                                : _kPrimaryBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: walletState.isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kPrimary))
                          : Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 18,
                              color: hasSufficient
                                  ? _kGreen
                                  : hasInsufficient
                                      ? _kOrange
                                      : _kPrimary,
                            ),
                    ),
                    title: 'Wallet',
                    subtitle: _walletSubtitle(
                      walletState: walletState,
                      hasSufficient: hasSufficient,
                      hasInsufficient: hasInsufficient,
                      walletBalance: walletBalance,
                      billAmount: billAmount,
                      fmt: fmt,
                    ),
                    badge: hasSufficient ? 'Instant' : null,
                  ),
                  const SizedBox(height: 10),

                  // UPI / Card
                  _PayMethodCard(
                    selected: _selectedPayMethod == PayMethod.upi,
                    onTap: () => setState(() => _selectedPayMethod = PayMethod.upi),
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _kPrimaryBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payment_rounded,
                          size: 18, color: _kPrimary),
                    ),
                    title: 'UPI / Card',
                    subtitle: const Text(
                      'Pay via Razorpay — UPI, cards, net banking',
                      style: TextStyle(fontSize: 12, color: _kMuted),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Order amount breakdown — only when a first-order
                  // discount applies. Nothing to break down otherwise.
                  if (hasFirstOrderDiscount) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          _BreakdownRow(
                            label: 'Order Amount',
                            value: fmt.format(widget.order.originalBillAmount!),
                          ),
                          const SizedBox(height: 8),
                          _BreakdownRow(
                            label: 'First Order Discount',
                            value: '- ${fmt.format(widget.order.firstOrderDiscountAmount!)}',
                            valueColor: _kGreen,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                          ),
                          _BreakdownRow(
                            label: 'Total Payable',
                            value: fmt.format(billAmount),
                            bold: true,
                            valueColor: _kPrimary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Insufficient wallet notice
                  if (_selectedPayMethod == PayMethod.wallet && hasInsufficient) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kOrangeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _kOrange, size: 16),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Add money to your wallet or choose UPI to complete payment.',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kText),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            await context.push(AppRoutes.addMoney);
                            if (mounted) {
                              ref.read(walletProvider.notifier).refresh();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: _kOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Add Money',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Error
                  if (_payError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kRedBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: _kRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_payError!,
                                style: const TextStyle(
                                    color: _kRed, fontSize: 12))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // ── Pay button ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (_paying ||
                        (_selectedPayMethod == PayMethod.wallet && hasInsufficient))
                    ? null
                    : () {
                        if (_selectedPayMethod == PayMethod.wallet) {
                          _payWithWallet();
                        } else {
                          Navigator.pop(context, PaySheetResult.upiRequested);
                        }
                      },
                icon: _paying
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        _selectedPayMethod == PayMethod.wallet
                            ? Icons.account_balance_wallet_rounded
                            : Icons.payment_rounded,
                        size: 18,
                      ),
                label: Text(_paying
                    ? 'Processing…'
                    : _selectedPayMethod == PayMethod.wallet
                        ? 'Pay ${fmt.format(billAmount)} via Wallet'
                        : 'Pay ${fmt.format(billAmount)} via UPI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),

          // ── Security note ─────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('Secured by Razorpay & Laundry Brew',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WALLET SUBTITLE — one line while sufficient, two lines while short
// (balance shown first, then the exact top-up amount needed).
// ═════════════════════════════════════════════════════════════════════════════

Widget _walletSubtitle({
  required WalletState walletState,
  required bool hasSufficient,
  required bool hasInsufficient,
  required double walletBalance,
  required double billAmount,
  required NumberFormat fmt,
}) {
  if (walletState.isLoading) {
    return const Text('Checking balance…',
        style: TextStyle(fontSize: 12, color: _kMuted));
  }
  if (walletState.error != null) {
    return const Text('Could not load balance',
        style: TextStyle(fontSize: 12, color: _kMuted));
  }
  if (hasSufficient) {
    return Text('Balance: ${fmt.format(walletBalance)} — sufficient ✓',
        style: const TextStyle(fontSize: 12, color: _kGreen));
  }
  // hasInsufficient: show the balance, then exactly how much more is needed
  // to cover the (already first-order-discounted, if applicable) total.
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Balance: ${fmt.format(walletBalance)}',
          style: const TextStyle(fontSize: 12, color: _kOrange)),
      const SizedBox(height: 2),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline_rounded, size: 12, color: _kOrange),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Insufficient balance (Needs ${fmt.format(billAmount - walletBalance)} more)',
              style: const TextStyle(fontSize: 12, color: _kOrange),
            ),
          ),
        ],
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// BREAKDOWN ROW — "Order Amount / First Order Discount / Total Payable"
// ═════════════════════════════════════════════════════════════════════════════

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor = _kText,
  });

  final String label;
  final String value;
  final bool bold;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: bold ? _kText : _kMuted)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: valueColor)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PAY METHOD CARD
// ═════════════════════════════════════════════════════════════════════════════

class _PayMethodCard extends StatelessWidget {
  const _PayMethodCard({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  /// Widget instead of a plain String so callers can render a two-line
  /// "Balance: ₹X / Insufficient balance (Needs ₹Y more)" breakdown for the
  /// wallet card, not just a single line of text.
  final Widget subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _kPrimaryBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kPrimary : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: selected ? _kPrimary : _kText)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kGreenBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _kGreen)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  subtitle,
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _kPrimary : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: _kPrimary, shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
