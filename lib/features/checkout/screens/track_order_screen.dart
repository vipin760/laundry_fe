import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/payment_config.dart';
import '../../../core/payments/app_razorpay.dart';
import '../../orders/models/order_model.dart';
import '../../orders/widgets/delivery_confirmation_sheet.dart';
import '../../orders/widgets/order_payment_sheet.dart';
import '../../orders/widgets/order_photo_gallery.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/checkout_models.dart' show DeliveryType;
import '../services/payment_service.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
const _kBlue  = Color(0xFF2453FF);
const _kDark  = Color(0xFF0A1645);
const _kGrey  = Color(0xFF7D86A5);
const _kBg    = Color(0xFFF5F7FF);
const _kGreen = Color(0xFF12B76A);
const _kRed   = Color(0xFFD92D20);
const _kGreenBg  = Color(0xFFECFDF5);
const _kOrange   = Color(0xFFF79009);
const _kOrangeBg = Color(0xFFFFF4E5);

// ── Step definition ───────────────────────────────────────────────────────────
//
//  Image → Status mapping (number matches the filename number):
//
//  1 → order_confirmed_1 (1).png   → ORDER_PLACED      (Order Confirmed)
//  2 → we_are_on_the_way_2 (1).png → PICKUP_ASSIGNED   (We're On The Way)
//  3 → you_order_itemized_3 (1).png→ ITEMIZED           (Order Itemized)
//  4 → items_bewing_4 (1).png      → PROCESSING         (Items Being Brewed)
//  5 → order_confirmed_5 (1).png   → OUT_FOR_DELIVERY   (Out for Delivery)
//  6 → (reuses image 5)            → COMPLETED          (Delivered ✓)

class _Step {
  final int number;
  final String statusKey;
  final String label;
  final String description;
  final String asset;
  const _Step({
    required this.number,
    required this.statusKey,
    required this.label,
    required this.description,
    required this.asset,
  });
}

const _kSteps = [
  _Step(
    number: 1,
    statusKey: 'ORDER_PLACED',
    label: 'Order Confirmed',
    description: 'Your order has been placed and confirmed successfully.',
    asset: 'assets/images/order_confirmed_1 (1).png',
  ),
  _Step(
    number: 2,
    statusKey: 'PICKUP_ASSIGNED',
    label: "We're On The Way",
    description: 'Our partner is heading to your location to pick up your clothes.',
    asset: 'assets/images/we_are_on_the_way_2 (1).png',
  ),
  _Step(
    number: 3,
    statusKey: 'ITEMIZED',
    label: 'Order Itemized',
    description: 'Your clothes have been received and itemized at our facility.',
    asset: 'assets/images/you_order_itemized_3 (1).png',
  ),
  _Step(
    number: 4,
    statusKey: 'PROCESSING',
    label: 'Items Being Brewed',
    description: "We're cleaning your clothes with care using premium detergents.",
    asset: 'assets/images/items_bewing_4 (1).png',
  ),
  _Step(
    number: 5,
    statusKey: 'OUT_FOR_DELIVERY',
    label: 'Out for Delivery',
    description: 'Your fresh clothes are on the way back to you!',
    asset: 'assets/images/order_confirmed_5 (1).png',
  ),
];

// Self-pickup orders never go OUT_FOR_DELIVERY — step 5 is "Ready for Pickup"
// instead, and the final label reads "Picked Up".
const _kSelfPickupSteps = [
  _Step(
    number: 1,
    statusKey: 'ORDER_PLACED',
    label: 'Order Confirmed',
    description: 'Your order has been placed and confirmed successfully.',
    asset: 'assets/images/order_confirmed_1 (1).png',
  ),
  _Step(
    number: 2,
    statusKey: 'PICKUP_ASSIGNED',
    label: "We're On The Way",
    description: 'Our partner is heading to your location to pick up your clothes.',
    asset: 'assets/images/we_are_on_the_way_2 (1).png',
  ),
  _Step(
    number: 3,
    statusKey: 'ITEMIZED',
    label: 'Order Itemized',
    description: 'Your clothes have been received and itemized at our facility.',
    asset: 'assets/images/you_order_itemized_3 (1).png',
  ),
  _Step(
    number: 4,
    statusKey: 'PROCESSING',
    label: 'Items Being Brewed',
    description: "We're cleaning your clothes with care using premium detergents.",
    asset: 'assets/images/items_bewing_4 (1).png',
  ),
  _Step(
    number: 5,
    statusKey: 'READY_FOR_PICKUP',
    label: 'Ready for Delivery',
    description: 'Your fresh clothes are ready — come collect them at our shop!',
    asset: 'assets/images/order_confirmed_5 (1).png',
  ),
];

// Step-6 reuses image 5 but labels itself "Delivered" (or "Picked Up")
const _kDeliveredAsset = 'assets/images/order_confirmed_5 (1).png';
const _kDeliveredLabel = 'Delivered';
const _kDeliveredDesc  = 'Your order has been delivered. Thank you for choosing LaundryBrew!';
const _kPickedUpLabel = 'Delivered';
const _kPickedUpDesc  = 'You\'ve picked up your order. Thank you for choosing LaundryBrew!';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns 0-based index into the step list, or -1 for CANCELLED.
int _statusToIdx(String status) {
  switch (status) {
    case 'ORDER_PLACED':     return 0;
    case 'PICKUP_ASSIGNED':  return 1;
    case 'ITEMIZED':         return 2;
    case 'PROCESSING':       return 3;
    case 'OUT_FOR_DELIVERY': return 4;
    case 'READY_FOR_PICKUP': return 4;
    case 'COMPLETED':        return 4;
    case 'CANCELLED':        return -1;
    default:                 return 0;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  final String orderId;
  final String orderNumber;

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  final _svc = PaymentService();
  late final AppRazorpay _razorpay;

  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  bool _paying = false;
  bool _cancelling = false;
  String? _payError;

  @override
  void initState() {
    super.initState();
    _razorpay = AppRazorpay();
    _fetch();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _razorpay.clear();
    super.dispose();
  }

  OrderModel? get _orderModel =>
      _order != null ? OrderModel.fromJson(_order!) : null;

  // ── Payment ──────────────────────────────────────────────────────────────

  Future<void> _initiateUpiPayment() async {
    final order = _orderModel;
    if (order == null) return;
    setState(() { _paying = true; _payError = null; });
    try {
      final data = await _svc.initiatePaymentForOrder(orderId: order.id);
      final razorpayOrderId = data['razorpayOrderId'] as String? ?? '';
      final amount = (data['amount'] as num?)?.toInt() ?? 0;

      // Open payment via Razorpay
      _razorpay.open({
        'key': PaymentConfig.razorpayKeyId,
        'amount': amount,
        'name': 'LaundryBrew',
        'order_id': razorpayOrderId,
        'description': 'Laundry Order #${order.displayNumber}',
        'prefill': {
          'contact': '8888888888',
          'email': 'customer@laundrybrew.com',
        },
      });

      if (!mounted) return;
      setState(() { _paying = false; _payError = null; });
      await _fetch();
    } catch (e) {
      await _svc.markPaymentFailed(widget.orderId);
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _paying = false;
        _payError = msg.startsWith('Exception: ') ? msg.substring(11) : msg;
      });
    }
  }

  Future<void> _showPaymentSheet() async {
    final order = _orderModel;
    if (order == null) return;
    setState(() => _payError = null);

    final confirmed = await showDeliveryConfirmationSheet(
      context,
      orderId: order.id,
      currentType: order.deliveryType,
      currentAddress: order.deliveryAddress,
      shopName: (_order?['locationSnapshot'] as Map?)?['shopName'] as String?,
    );
    if (confirmed != true || !mounted) return;

    final result = await showOrderPaymentSheet(context, order);
    if (!mounted) return;
    if (result == PaySheetResult.walletSuccess) {
      await _fetch();
      ref.read(walletProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Payment successful via Wallet!'),
          backgroundColor: _kGreen,
          duration: Duration(seconds: 4),
        ),
      );
    } else if (result == PaySheetResult.upiRequested) {
      _initiateUpiPayment();
    }
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Are you sure you want to cancel this order? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _cancelling = true);
    try {
      await _svc.cancelOrder(widget.orderId);
      if (!mounted) return;
      setState(() => _cancelling = false);
      await _fetch();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled.'),
          backgroundColor: _kRed,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _kRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _fetch() async {
    try {
      final data = await _svc.getOrderTracking(widget.orderId);
      if (mounted) setState(() { _order = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String get _statusKey =>
      (_order?['status'] as String?) ?? 'ORDER_PLACED';
  bool get _isCancelled  => _statusKey == 'CANCELLED';
  bool get _isCompleted  => _statusKey == 'COMPLETED';
  bool get _isSelfPickup => _orderModel?.deliveryType == DeliveryType.selfPickup;
  List<_Step> get _steps => _isSelfPickup ? _kSelfPickupSteps : _kSteps;

  /// Pay button — itemized/brewing through dispatch (ready for pickup / out
  /// for delivery), while unpaid. Payment now happens after the order is
  /// marked ready, not before.
  bool get _canPay {
    final paymentStatus = _order?['paymentStatus'] as String?;
    return (_statusKey == 'ITEMIZED' ||
            _statusKey == 'PROCESSING' ||
            _statusKey == 'READY_FOR_PICKUP' ||
            _statusKey == 'OUT_FOR_DELIVERY') &&
        paymentStatus != 'COMPLETED' &&
        (_order?['billAmount'] as num?) != null;
  }

  /// Cancel button — only before itemization, mirroring backend rules.
  bool get _canCancel =>
      _statusKey == 'ORDER_PLACED' || _statusKey == 'PICKUP_ASSIGNED';

  List<Map<String, dynamic>> get _statusHistory {
    final raw = _order?['statusHistory'] as List?;
    if (raw == null) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  String? _tsFor(String statusKey) {
    for (final e in _statusHistory) {
      if (e['status'] == statusKey) {
        final ts = e['timestamp'] as String?;
        if (ts == null) return null;
        try {
          return DateFormat('dd MMM yyyy  hh:mm a')
              .format(DateTime.parse(ts).toLocal());
        } catch (_) {
          return ts;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Track Order',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _kDark)),
            Text('Order #${widget.orderNumber}',
                style: const TextStyle(
                    fontSize: 11,
                    color: _kGrey,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kBlue),
            onPressed: () {
              setState(() => _loading = true);
              _fetch();
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE9EDFA)),
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5))
          : _error != null
              ? _ErrorView(
                  message: _error!,
                  onRetry: () {
                    setState(() => _loading = true);
                    _fetch();
                  })
              : _order == null
                  ? const _ErrorView(
                      message: 'Order not found.', onRetry: null)
                  : _buildBody(),
    );
  }

  Widget _buildBody() {
    final idx = _statusToIdx(_statusKey);
    final steps = _steps;
    final step = idx >= 0 ? steps[idx] : steps[0];

    final heroLabel = _isCompleted
        ? (_isSelfPickup ? _kPickedUpLabel : _kDeliveredLabel)
        : _isCancelled
            ? 'Order Cancelled'
            : step.label;

    final heroDesc = _isCompleted
        ? (_isSelfPickup ? _kPickedUpDesc : _kDeliveredDesc)
        : _isCancelled
            ? 'This order has been cancelled. Please contact support if you need help.'
            : step.description;

    final heroAsset = _isCompleted || _isCancelled
        ? _kDeliveredAsset
        : step.asset;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // ── Hero ─────────────────────────────────────────────────────────
          _HeroBanner(
            stepNumber: _isCompleted ? 6 : (_isCancelled ? 0 : step.number),
            label: heroLabel,
            description: heroDesc,
            asset: heroAsset,
            isCancelled: _isCancelled,
            isCompleted: _isCompleted,
            totalSteps: _isCompleted ? 6 : steps.length,
          ),

          // ── OTP display card (shown from PROCESSING through OUT_FOR_DELIVERY/READY_FOR_PICKUP) ─
          if ((_statusKey == 'PROCESSING' ||
                  _statusKey == 'OUT_FOR_DELIVERY' ||
                  _statusKey == 'READY_FOR_PICKUP') &&
              (_order!['deliveryOtp'] as String?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _OtpDisplayCard(
                otp: _order!['deliveryOtp'] as String,
                isSelfPickup: _isSelfPickup,
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Timeline ──────────────────────────────────────────────
                const Text('Order Progress',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _kDark)),
                const SizedBox(height: 14),

                _VerticalTimeline(
                  currentStatusKey: _statusKey,
                  tsFor: _tsFor,
                  isCancelled: _isCancelled,
                  isCompleted: _isCompleted,
                  steps: _steps,
                  deliveredLabel: _isSelfPickup ? _kPickedUpLabel : _kDeliveredLabel,
                ),
                const SizedBox(height: 20),

                // ── Driver card ───────────────────────────────────────────
                if (_statusKey == 'PICKUP_ASSIGNED' &&
                    _order!['driverName'] != null)
                  _DriverCard(order: _order!),

                // ── Findings — item condition photos taken by admin at pickup ──
                if (_orderModel?.damagePhotos.isNotEmpty == true) ...[
                  OrderPhotoGallery(
                    title: 'Item Condition — Findings',
                    subtitle:
                        'Photos taken at pickup documenting the condition of your items.',
                    icon: Icons.content_paste_search_rounded,
                    accent: _kOrange,
                    accentBg: _kOrangeBg,
                    photos: _orderModel!.damagePhotos,
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Itemization card ──────────────────────────────────────
                if (_statusToIdx(_statusKey) >= 2 &&
                    (_order!['weightKg'] != null ||
                        _order!['itemCount'] != null))
                  _ItemizedCard(order: _order!),

                // ── Weight verification — scale photo uploaded with the bill ──
                if (_orderModel?.weighingPhotos.isNotEmpty == true) ...[
                  OrderPhotoGallery(
                    title: 'Weight Verification',
                    subtitle: _order!['weightKg'] != null
                        ? 'Scale reading for your ${_order!['weightKg']} kg load — proof of billed weight.'
                        : 'Scale reading photo — proof of billed weight.',
                    icon: Icons.scale_rounded,
                    accent: _kGreen,
                    accentBg: _kGreenBg,
                    photos: _orderModel!.weighingPhotos,
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Pay Now (itemized/brewing + bill set + unpaid) ────────
                if (_canPay) ...[
                  _PayNowCard(
                    amount: (_order!['billAmount'] as num).toDouble(),
                    paying: _paying,
                    onTap: _paying ? null : _showPaymentSheet,
                  ),
                  if (_payError != null) ...[
                    const SizedBox(height: 10),
                    _PayErrorBanner(
                      message: _payError!,
                      onDismiss: () => setState(() => _payError = null),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],

                // ── Pickup info ───────────────────────────────────────────
                if (_order!['pickupDate'] != null ||
                    _order!['pickupSlot'] != null)
                  _PickupInfoCard(order: _order!, isSelfPickup: _isSelfPickup),

                // ── Cancel order (before itemization only) ────────────────
                if (_canCancel) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _cancelling ? null : _cancelOrder,
                      icon: _cancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kRed))
                          : const Icon(Icons.cancel_outlined,
                              size: 18, color: _kRed),
                      label: Text(
                        _cancelling ? 'Cancelling…' : 'Cancel Order',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kRed),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFECDCA)),
                        backgroundColor: const Color(0xFFFFFBFA),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'You will receive updates on every step of your order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: _kGrey, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
// HERO BANNER
// ══════════════════════════════════════════════════════════════════════════════

class _HeroBanner extends StatelessWidget {
  final int stepNumber;      // 1-6, or 0 for cancelled
  final String label;
  final String description;
  final String asset;
  final bool isCancelled;
  final bool isCompleted;
  final int totalSteps;

  const _HeroBanner({
    required this.stepNumber,
    required this.label,
    required this.description,
    required this.asset,
    required this.isCancelled,
    required this.isCompleted,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          // Step badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isCancelled
                  ? const Color(0xFFFEF2F2)
                  : isCompleted
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? _kRed
                        : isCompleted
                            ? _kGreen
                            : _kBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isCancelled
                      ? 'Cancelled'
                      : isCompleted
                          ? 'All steps completed'
                          : 'Step $stepNumber of $totalSteps',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCancelled
                        ? _kRed
                        : isCompleted
                            ? _kGreen
                            : _kBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Illustration
          SizedBox(
            height: 200,
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.local_laundry_service_outlined,
                    size: 64, color: _kBlue),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _kDark)),
          const SizedBox(height: 8),
          Text(description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, color: _kGrey, height: 1.5)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// VERTICAL TIMELINE
// ══════════════════════════════════════════════════════════════════════════════

class _VerticalTimeline extends StatelessWidget {
  final String currentStatusKey;
  final String? Function(String) tsFor;
  final bool isCancelled;
  final bool isCompleted;
  final List<_Step> steps;
  final String deliveredLabel;

  const _VerticalTimeline({
    required this.currentStatusKey,
    required this.tsFor,
    required this.isCancelled,
    required this.isCompleted,
    this.steps = _kSteps,
    this.deliveredLabel = _kDeliveredLabel,
  });

  @override
  Widget build(BuildContext context) {
    final currentIdx = _statusToIdx(currentStatusKey);

    // Build rows for 5 base steps + optional "Delivered"/"Picked Up" row
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        children: [
          // Step 1-5
          for (int i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              isDone: !isCancelled && i <= currentIdx,
              isActive: !isCancelled && i == currentIdx && !isCompleted,
              timestamp: tsFor(steps[i].statusKey),
              showLine: !(i == steps.length - 1 && !isCompleted),
              isCancelledStep: isCancelled && i == 0,
            ),

          // Step 6: Delivered / Picked Up (only when COMPLETED)
          if (isCompleted)
            _TimelineRow(
              step: _Step(
                number: 6,
                statusKey: 'COMPLETED',
                label: deliveredLabel,
                description: '',
                asset: _kDeliveredAsset,
              ),
              isDone: true,
              isActive: true,
              isDelivered: true,
              timestamp: tsFor('COMPLETED'),
              showLine: false,
            ),
        ],
      ),
    );
  }
}

// ── Single timeline row ───────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final _Step step;
  final bool isDone;
  final bool isActive;
  final bool showLine;
  final bool isCancelledStep;
  final bool isDelivered;
  final String? timestamp;

  const _TimelineRow({
    required this.step,
    required this.isDone,
    required this.isActive,
    required this.showLine,
    this.isCancelledStep = false,
    this.isDelivered = false,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    // Dot colour logic
    final Color dotBg = isCancelledStep
        ? _kRed
        : isDone
            ? isDelivered
                ? _kGreen
                : _kBlue
            : const Color(0xFFF0F2F8);

    final Color dotBorder = isCancelledStep
        ? _kRed
        : isDone
            ? isDelivered
                ? _kGreen
                : _kBlue
            : const Color(0xFFD8DDED);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dot + connector ─────────────────────────────────────────────
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotBg,
                    border: Border.all(color: dotBorder, width: 2),
                  ),
                  child: Center(
                    child: isDone && !isCancelledStep
                        ? Icon(
                            isDelivered
                                ? Icons.home_rounded
                                : Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : isCancelledStep
                            ? const Icon(Icons.close_rounded,
                                size: 16, color: Colors.white)
                            : Text(
                                '${step.number}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _kGrey),
                              ),
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: isDone
                          ? _kBlue.withValues(alpha: 0.25)
                          : const Color(0xFFEAEDFA),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // ── Label + timestamp + thumbnail ───────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 22 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step number label
                        Text(
                          '${step.number}. ${step.label}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive || (isDone && isDelivered)
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isDone ? _kDark : _kGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Timestamp
                        Text(
                          timestamp ??
                              (isDone ? '—' : 'Pending'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDone && timestamp != null
                                ? _kBlue.withValues(alpha: 0.75)
                                : _kGrey,
                            fontWeight: isDone && timestamp != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAY NOW CARD
// ══════════════════════════════════════════════════════════════════════════════

class _PayNowCard extends StatelessWidget {
  const _PayNowCard({
    required this.amount,
    required this.paying,
    required this.onTap,
  });

  final double amount;
  final bool paying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2453FF), Color(0xFF1A3DD4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _kBlue.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payments_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Due',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text(fmt.format(amount),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: paying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kBlue))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Pay Now',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _kBlue)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: _kBlue),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayErrorBanner extends StatelessWidget {
  const _PayErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: _kRed, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(color: _kRed, fontSize: 12))),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(Icons.close_rounded, color: _kRed, size: 16),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DETAIL CARDS
// ══════════════════════════════════════════════════════════════════════════════

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _DriverCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _InfoCard(
        title: 'Driver Details',
        titleIcon: Icons.person_pin_circle_rounded,
        children: [
          _DetailRow(Icons.person_rounded, 'Name',
              order['driverName'] ?? '—'),
          const SizedBox(height: 8),
          _DetailRow(Icons.phone_rounded, 'Phone',
              order['driverPhone'] ?? '—'),
        ],
      ),
    );
  }
}

class _ItemizedCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ItemizedCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _InfoCard(
        title: 'Itemization',
        titleIcon: Icons.scale_rounded,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              if (order['weightKg'] != null)
                _StatChip(
                    label: 'Weight',
                    value: '${order['weightKg']} kg'),
              if (order['itemCount'] != null)
                _StatChip(
                    label: 'Items',
                    value: '${order['itemCount']} pcs'),
              if (order['billAmount'] != null)
                _StatChip(
                    label: 'Bill',
                    value: '₹${order['billAmount']}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickupInfoCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isSelfPickup;
  const _PickupInfoCard({required this.order, this.isSelfPickup = false});

  @override
  Widget build(BuildContext context) {
    final rawDate = order['pickupDate'] as String?;
    String dateStr = '—';
    if (rawDate != null) {
      try {
        dateStr = DateFormat('EEE, dd MMM yyyy')
            .format(DateTime.parse(rawDate).toLocal());
      } catch (_) {}
    }
    final slot = order['pickupSlot'] as String?;

    // Delivery (or, for Self Pickup, ready-for-collection) — scheduled
    // orders land on the same slot, shifted by the service's turnaround;
    // instant orders shift by minutes. Same underlying field either way,
    // just relabeled since Self Pickup has no delivery leg.
    final rawDeliveryDate = order['deliveryDate'] as String?;
    final deliveryDt =
        rawDeliveryDate != null ? DateTime.tryParse(rawDeliveryDate)?.toLocal() : null;
    String? deliveryDateStr;
    if (deliveryDt != null) {
      try {
        deliveryDateStr = DateFormat('EEE, dd MMM yyyy').format(deliveryDt);
      } catch (_) {}
    }
    final deliverySlotRaw = order['deliverySlot'] as String?;
    final hasDeliverySlot =
        deliverySlotRaw != null && deliverySlotRaw.trim().isNotEmpty;
    // Instant orders have no real slot — show the exact computed ETA instead
    // of a slot label that has no relationship to the actual delivery time.
    String? deliveryEtaStr;
    if (!hasDeliverySlot && deliveryDt != null) {
      try {
        deliveryEtaStr =
            DateFormat('EEE, dd MMM yyyy · hh:mm a').format(deliveryDt);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _InfoCard(
        title: isSelfPickup ? 'Pickup & Collection' : 'Pickup & Delivery',
        titleIcon: Icons.calendar_today_rounded,
        children: [
          _DetailRow(Icons.calendar_today_rounded, 'Pickup', dateStr),
          if (slot != null) ...[
            const SizedBox(height: 8),
            _DetailRow(Icons.access_time_rounded, 'Pickup slot', slot),
          ],
          if (deliveryEtaStr != null) ...[
            const SizedBox(height: 8),
            _DetailRow(
                isSelfPickup
                    ? Icons.storefront_rounded
                    : Icons.local_shipping_rounded,
                isSelfPickup ? 'Ready by' : 'Delivery by',
                deliveryEtaStr),
          ] else ...[
            if (deliveryDateStr != null) ...[
              const SizedBox(height: 8),
              _DetailRow(
                  isSelfPickup
                      ? Icons.storefront_rounded
                      : Icons.local_shipping_rounded,
                  isSelfPickup ? 'Ready for Delivery' : 'Delivery',
                  deliveryDateStr),
            ],
            if (hasDeliverySlot) ...[
              const SizedBox(height: 8),
              _DetailRow(Icons.access_time_rounded,
                  isSelfPickup ? 'Ready slot' : 'Delivery slot',
                  deliverySlotRaw),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final List<Widget> children;
  const _InfoCard(
      {required this.title,
      required this.titleIcon,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(titleIcon, size: 14, color: _kBlue),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kBlue,
                      letterSpacing: 0.2)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: _kBlue),
      const SizedBox(width: 8),
      Text('$label  ',
          style: const TextStyle(fontSize: 12, color: _kGrey)),
      Expanded(
        child: Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kDark)),
      ),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _kDark)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: _kGrey)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OTP DISPLAY CARD  (shown when status = OUT_FOR_DELIVERY)
// ══════════════════════════════════════════════════════════════════════════════

class _OtpDisplayCard extends StatelessWidget {
  const _OtpDisplayCard({required this.otp, this.isSelfPickup = false});
  final String otp;
  final bool isSelfPickup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2453FF), Color(0xFF4F75FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2453FF).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_open_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery OTP',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      isSelfPickup
                          ? 'Your order is ready for pickup!'
                          : 'Your order is on its way!',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── OTP digit boxes ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: otp.split('').map((digit) {
              return Container(
                width: 52,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _kBlue,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // ── Instruction ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSelfPickup
                        ? 'Show this OTP at the counter when collecting your order.'
                        : 'Share this OTP with your delivery partner to confirm delivery.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ERROR VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, color: _kGrey)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry',
                    style: TextStyle(
                        color: _kBlue,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
