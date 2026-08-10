import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../core/config/payment_config.dart';
import '../../../core/payments/app_razorpay.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_text.dart';
import '../../checkout/models/checkout_models.dart' show DeliveryType;
import '../../checkout/services/payment_service.dart';
import '../../checkout/widgets/coupon_input_widget.dart';
import '../../support/screens/support_chat_screen.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../widgets/delivery_confirmation_sheet.dart';
import '../widgets/invoice_download_button.dart';
import '../widgets/order_payment_sheet.dart';
import '../widgets/order_photo_gallery.dart';

// Private type aliases so legacy _PaymentSheet code still compiles.
// The actual sheet opened by _showPaymentSheet uses showOrderPaymentSheet().
typedef _PayMethod = PayMethod;
typedef _PaySheetResult = PaySheetResult;

// ── Colour palette ────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2453FF);
const _kPrimaryBg = Color(0xFFEEF2FF);
const _kGreen     = Color(0xFF12B76A);
const _kGreenBg   = Color(0xFFECFDF5);
const _kOrange    = Color(0xFFF79009);
const _kOrangeBg  = Color(0xFFFFF4E5);
const _kRed       = Color(0xFFD92D20);
const _kRedBg     = Color(0xFFFEF3F2);
const _kAmber     = Color(0xFFD97706);
const _kAmberBg   = Color(0xFFFEF3C7);
const _kBg        = Color(0xFFF7F8FC);
const _kText      = Color(0xFF0A1645);
const _kMuted     = Color(0xFF7D86A5);

// ═════════════════════════════════════════════════════════════════════════════

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _paymentService = PaymentService();
  late final AppRazorpay _razorpay;

  OrderModel? _order;
  bool _loading = true;
  bool _paying  = false;
  String? _payError;
  String? _currentOrderId;
  double? _discountedAmount;

  @override
  void initState() {
    super.initState();
    _razorpay = AppRazorpay();
    _razorpay.on(AppRazorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(AppRazorpay.EVENT_PAYMENT_ERROR, _onPayError);
    _fetchOrder();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _fetchOrder() async {
    setState(() { _loading = true; _payError = null; });
    try {
      final order = await ref.read(ordersProvider.notifier).fetchOrderDetails(widget.orderId);
      if (mounted) setState(() { _order = order; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // ── Payment handlers ──────────────────────────────────────────────────────

  /// Razorpay reports the sheet was dismissed/failed client-side — the order
  /// stays PENDING (never marked failed here) so the user can just retry.
  void _onPayError(PaymentFailureResponse r) {
    if (!mounted) return;
    setState(() {
      _paying = false;
      _payError = r.message ?? 'Payment failed. Please try again.';
    });
  }

  /// Only after the backend has verified the Razorpay signature do we treat
  /// this as a real success — never trust the SDK's success callback alone.
  void _onPaySuccess(PaymentSuccessResponse r) async {
    if (_currentOrderId == null) return;
    try {
      await _paymentService.verifyPayment(
        orderId: _currentOrderId!,
        razorpayOrderId: r.orderId!,
        razorpayPaymentId: r.paymentId!,
        razorpaySignature: r.signature!,
      );
      if (!mounted) return;
      setState(() { _paying = false; _payError = null; });

      // Refresh order to get OTP + updated paymentStatus — only now that the
      // server has actually confirmed the payment, not optimistically right
      // after the Razorpay sheet was opened.
      await _fetchOrder();

      // Coupon redemption happens automatically, server-side, the moment
      // payment succeeds — there is nothing for the client to record here.

      // Referral first-order qualification is handled entirely server-side:
      // OrdersService calls ReferralService.handleQualifyingOrder when the
      // order reaches COMPLETED + paid. No client call is needed (or trusted).

      if (!mounted) return;
      setState(() {
        _discountedAmount = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _payError = 'Payment verification failed. Please contact support.';
      });
    }
  }

  Future<void> _initiatePayment() async {
    if (_order == null) return;
    setState(() { _paying = true; _payError = null; });
    try {
      final data = await _paymentService.initiatePaymentForOrder(orderId: _order!.id);
      _currentOrderId = data['orderId']?.toString() ?? _order!.id;
      final razorpayOrderId = data['razorpayOrderId'] as String? ?? '';
      final amount = (data['amount'] as num?)?.toInt() ?? 0;

      // Open payment via Razorpay — completion is handled by _onPaySuccess/
      // _onPayError above, registered in initState(), not here.
      _razorpay.open({
        'key': PaymentConfig.razorpayKeyId,
        'amount': amount,
        'name': 'LaundryBrew',
        'order_id': razorpayOrderId,
        'description': 'Laundry Order #${_order!.displayNumber}',
        'prefill': {
          'contact': '8888888888',
          'email': 'customer@laundrybrew.com',
        },
      });

      if (!mounted) return;
      setState(() { _paying = false; });
    } catch (e) {
      if (_currentOrderId != null) await _paymentService.markPaymentFailed(_currentOrderId!);
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
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const AppText('Order Details', fontSize: 20, fontWeight: FontWeight.w900),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kText),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _fetchOrder,
            icon: const Icon(Icons.refresh_rounded, color: _kText),
          ),
          IconButton(
            tooltip: 'Need help?',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportChatScreen()),
            ),
            icon: const Icon(Icons.help_outline_rounded, color: _kText),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _order == null
              ? _buildError()
              : _buildContent(_order!),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: _kMuted),
        const SizedBox(height: 12),
        const AppText('Could not load order details', color: _kMuted),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _fetchOrder,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
          style: FilledButton.styleFrom(backgroundColor: _kPrimary),
        ),
      ],
    ),
  );

  Widget _buildContent(OrderModel order) {
    // Show Pay Now once the bill is confirmed (ITEMIZED/BREWING) through
    // dispatch (READY_FOR_PICKUP/OUT_FOR_DELIVERY) — payment now happens
    // after the order is marked ready, not before. Covers both PENDING
    // (fresh) and FAILED (previous attempt) so user can retry.
    final canPay = (order.status == OrderStatus.itemized ||
                    order.status == OrderStatus.brewing ||
                    order.status == OrderStatus.readyForPickup ||
                    order.status == OrderStatus.outForDelivery) &&
                   order.paymentStatus != PaymentStatus.completed &&
                   order.billAmount != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(order),
          const SizedBox(height: 16),
          _buildStatusTimeline(order),
          const SizedBox(height: 16),
          _buildItemsList(order),

          // Findings — item condition photos taken by admin at pickup.
          // Serves as evidence of any pre-existing damage.
          if (order.damagePhotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            OrderPhotoGallery(
              title: 'Item Condition — Findings',
              subtitle:
                  'Photos taken at pickup documenting the condition of your items.',
              icon: Icons.content_paste_search_rounded,
              accent: _kOrange,
              accentBg: _kOrangeBg,
              photos: order.damagePhotos,
            ),
          ],

          // Bill details — shown once admin has itemized
          if (order.billAmount != null) ...[
            const SizedBox(height: 16),
            _buildBillSection(order),
          ],

          // Weight verification — scale photo uploaded with the bill so you
          // can verify the kg used for billing.
          if (order.weighingPhotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            OrderPhotoGallery(
              title: 'Weight Verification',
              subtitle: order.weightKg != null
                  ? 'Scale reading for your ${order.weightKg!.toStringAsFixed(1)} kg load — proof of billed weight.'
                  : 'Scale reading photo — proof of billed weight.',
              icon: Icons.scale_rounded,
              accent: _kGreen,
              accentBg: _kGreenBg,
              photos: order.weighingPhotos,
            ),
          ],

          // Pay Now button — shown when BREWING + payment pending
          if (canPay) ...[
            const SizedBox(height: 16),
            _buildPaymentSection(order),
          ],

          // Payment pending notice — shown for non-brewing stages where payment
          // is still outstanding (PENDING or FAILED), so user knows to wait.
          if (!canPay && order.paymentStatus != PaymentStatus.completed &&
              order.status != OrderStatus.orderPlaced &&
              order.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 16),
            _buildPendingPaymentNotice(order),
          ],

          // Payment success + OTP
          if (order.paymentStatus == PaymentStatus.completed) ...[
            const SizedBox(height: 16),
            _buildPaymentConfirmed(order),
          ],

          // Delivery OTP — shown when payment done and order is NOT yet delivered
          if (order.deliveryOtp != null &&
              order.paymentStatus == PaymentStatus.completed &&
              order.status != OrderStatus.completed) ...[
            const SizedBox(height: 16),
            _buildOtpSection(order),
          ],
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          _infoRow('Order', '#${order.displayNumber}', bold: true, valueColor: _kPrimary),
          const Divider(height: 24, color: Color(0xFFF0F2F8)),
          _infoRow('Placed on', DateFormat('MMM dd, yyyy · hh:mm a').format(order.createdAt)),
          if (order.address != null) ...[
            const Divider(height: 24, color: Color(0xFFF0F2F8)),
            _infoRow('Address', order.address!, maxLines: 2),
          ],
          if (order.pickupDate != null || order.pickupSlot != null) ...[
            const Divider(height: 24, color: Color(0xFFF0F2F8)),
            _infoRow('Pickup', [
              if (order.pickupDate != null) DateFormat('MMM dd, yyyy').format(order.pickupDate!),
              if (order.pickupSlot != null) order.pickupSlot!,
            ].join(' · ')),
          ],
        ],
      ),
    );
  }

  // ── Status timeline ────────────────────────────────────────────────────────

  Widget _buildStatusTimeline(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Tracking', fontSize: 17, fontWeight: FontWeight.w800, color: _kText),
          const SizedBox(height: 18),
          _TimelineItem(
            title: 'Order Placed',
            subtitle: 'We received your order',
            icon: Icons.check_circle_rounded,
            isCompleted: true,
            isActive: order.status == OrderStatus.orderPlaced,
          ),
          _TimelineItem(
            title: 'Pickup Assigned',
            subtitle: 'Driver heading to your location',
            icon: Icons.directions_bike_rounded,
            isCompleted: order.status.index >= OrderStatus.pickupAssigned.index,
            isActive: order.status == OrderStatus.pickupAssigned,
            extra: order.driverName != null
                ? '👤 ${order.driverName}  📞 ${order.driverPhone ?? ''}'
                : null,
          ),
          _TimelineItem(
            title: 'Itemized',
            subtitle: 'Clothes counted & bill confirmed',
            icon: Icons.inventory_2_rounded,
            isCompleted: order.status.index >= OrderStatus.itemized.index,
            isActive: order.status == OrderStatus.itemized,
            extra: order.billAmount != null
                ? '₹${order.billAmount!.toStringAsFixed(0)} confirmed'
                : null,
          ),
          _TimelineItem(
            title: 'Brewing',
            subtitle: 'Your clothes are being cleaned',
            icon: Icons.local_laundry_service_rounded,
            isCompleted: order.status.index >= OrderStatus.brewing.index,
            isActive: order.status == OrderStatus.brewing,
            extra: order.status == OrderStatus.brewing && order.paymentStatus == PaymentStatus.pending
                ? '⏳ Awaiting your payment'
                : null,
          ),
          if (order.deliveryType == DeliveryType.selfPickup)
            _TimelineItem(
              title: 'Ready for Delivery',
              subtitle: 'Come collect your order at our shop',
              icon: Icons.storefront_rounded,
              isCompleted: order.status.index >= OrderStatus.readyForPickup.index,
              isActive: order.status == OrderStatus.readyForPickup,
            )
          else
            _TimelineItem(
              title: 'Out for Delivery',
              subtitle: 'Rider on the way to you',
              icon: Icons.electric_scooter_rounded,
              isCompleted: order.status.index >= OrderStatus.outForDelivery.index &&
                  order.status != OrderStatus.readyForPickup,
              isActive: order.status == OrderStatus.outForDelivery,
            ),
          _TimelineItem(
            title: order.deliveryType == DeliveryType.selfPickup ? 'Delivered' : 'Delivered',
            subtitle: order.deliveryType == DeliveryType.selfPickup
                ? 'Order collected successfully'
                : 'Order completed successfully',
            icon: Icons.home_rounded,
            isCompleted: order.status == OrderStatus.completed,
            isActive: order.status == OrderStatus.completed,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── Items list ─────────────────────────────────────────────────────────────

  Widget _buildItemsList(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Items', fontSize: 17, fontWeight: FontWeight.w800, color: _kText),
          const SizedBox(height: 14),
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText('${item.serviceName} × ${item.quantity}',
                      fontWeight: FontWeight.w600),
                ),
                AppText('Qty: ${item.quantity}', color: _kMuted, fontSize: 13),
              ],
            ),
          )),
          if (order.itemCount != null || order.weightKg != null) ...[
            const Divider(height: 24, color: Color(0xFFF0F2F8)),
            Row(
              children: [
                if (order.weightKg != null) ...[
                  const Icon(Icons.scale_outlined, size: 15, color: _kMuted),
                  const SizedBox(width: 4),
                  AppText('${order.weightKg!.toStringAsFixed(1)} kg', color: _kMuted, fontSize: 13),
                  const SizedBox(width: 16),
                ],
                if (order.itemCount != null) ...[
                  const Icon(Icons.inventory_2_outlined, size: 15, color: _kMuted),
                  const SizedBox(width: 4),
                  AppText('${order.itemCount} items', color: _kMuted, fontSize: 13),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Bill section ───────────────────────────────────────────────────────────

  /// Transparent fee/tax/discount breakdown — only renders rows that
  /// actually apply (fee fields default to 0/null and are hidden), so older
  /// orders without these fields fall back to the existing plain total.
  List<Widget> _buildFeeAndDiscountRows(OrderModel order) {
    Widget row(String label, double amount, {Color color = _kMuted, bool bold = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText(label, fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
          AppText('₹${amount.toStringAsFixed(2)}', fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
        ],
      ),
    );

    final rows = <Widget>[];
    if ((order.taxAmount ?? 0) > 0) rows.add(row('GST', order.taxAmount!));
    if ((order.deliveryFee ?? 0) > 0) rows.add(row('Delivery Fee', order.deliveryFee!));
    if ((order.platformFee ?? 0) > 0) rows.add(row('Platform Fee', order.platformFee!));
    if ((order.convenienceFee ?? 0) > 0) rows.add(row('Convenience Fee', order.convenienceFee!));
    if ((order.packagingFee ?? 0) > 0) rows.add(row('Packaging Fee', order.packagingFee!));
    if ((order.couponDiscountAmount ?? 0) > 0) {
      rows.add(row(
        order.couponCode != null ? 'Coupon Applied (${order.couponCode})' : 'Coupon Applied',
        -order.couponDiscountAmount!,
        color: _kGreen,
      ));
    }
    if (order.isManuallyAdjusted) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AppText(
          '✓ Admin Price Adjustment applied to this bill',
          fontSize: 12,
          color: _kAmber,
          fontWeight: FontWeight.w700,
        ),
      ));
    }
    if (rows.isNotEmpty) rows.add(const Divider(height: 16, color: Color(0xFFBBF0D6)));
    return rows;
  }

  Widget _buildBillSection(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD1FAE5), width: 1.5),
        boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _kGreenBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long_rounded, color: _kGreen, size: 18),
              ),
              const SizedBox(width: 10),
              const AppText('Bill Confirmed by Admin', fontSize: 16, fontWeight: FontWeight.w800, color: _kText),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kGreenBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildFeeAndDiscountRows(order),
                if (order.hasFirstOrderDiscount) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText('Bill Amount', fontSize: 13, color: _kMuted),
                      Text(
                        '₹${order.originalBillAmount!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText('First order reward', fontSize: 13, color: _kGreen, fontWeight: FontWeight.w700),
                      AppText(
                        '− ₹${order.firstOrderDiscountAmount!.toStringAsFixed(2)}',
                        fontSize: 13,
                        color: _kGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFFBBF0D6)),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppText('Total Bill', fontSize: 16, fontWeight: FontWeight.w700),
                    AppText(
                      '₹${order.billAmount!.toStringAsFixed(2)}',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _kGreen,
                    ),
                  ],
                ),
                if (order.hasFirstOrderDiscount) ...[
                  const SizedBox(height: 6),
                  const AppText(
                    "This is your first order, so we've taken this off the bill — full price from your next order onward.",
                    fontSize: 11.5,
                    color: _kMuted,
                  ),
                ],
              ],
            ),
          ),
          if (order.pickupTime != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 15, color: _kMuted),
                const SizedBox(width: 6),
                AppText('Pickup: ${order.pickupTime}', color: _kMuted, fontSize: 13),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Pay Now compact card ───────────────────────────────────────────────────

  Widget _buildPaymentSection(OrderModel order) {
    final fmt        = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final billAmount = order.billAmount!;
    final finalAmount = _discountedAmount ?? billAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Coupon Widget (NEW) ─────────────────────────────────────────
        CouponInputWidget(
          orderId: order.id,
          orderAmount: billAmount,
          onCouponApplied: (discountedAmount) {
            setState(() {
              _discountedAmount = discountedAmount;
            });
          },
        ),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: _paying ? null : () => _showPaymentSheet(order),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2453FF), Color(0xFF1A3DD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Amount row ──────────────────────────────────────────
                Row(
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
                          const AppText('Payment Due',
                              fontSize: 12, color: Colors.white70),
                          const SizedBox(height: 2),
                          AppText(fmt.format(finalAmount),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                          // Show discount if applied
                          if (_discountedAmount != null && _discountedAmount != billAmount)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Original: ${fmt.format(billAmount)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white60,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Pay Now pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _paying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kPrimary))
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppText('Pay Now',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _kPrimary),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 16, color: _kPrimary),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                // ── Payment method chips ────────────────────────────────
                Row(
                  children: [
                    _PayChip(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Wallet'),
                    const SizedBox(width: 8),
                    _PayChip(
                        icon: Icons.credit_card_rounded,
                        label: 'UPI / Card'),
                    const Spacer(),
                    Icon(Icons.lock_outline_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    AppText('Secured',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── UPI error (after Razorpay failure) ───────────────────────────
        if (_payError != null) ...[
          const SizedBox(height: 10),
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
                  child: AppText(_payError!, color: _kRed, fontSize: 12)),
              GestureDetector(
                onTap: () => setState(() => _payError = null),
                child: const Icon(Icons.close_rounded,
                    color: _kRed, size: 16),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ── Open payment bottom sheet ──────────────────────────────────────────────

  Future<void> _showPaymentSheet(OrderModel order) async {
    setState(() => _payError = null);

    final confirmed = await showDeliveryConfirmationSheet(
      context,
      orderId: order.id,
      currentType: order.deliveryType,
      currentAddress: order.deliveryAddress,
      shopName: order.shopName,
    );
    if (confirmed != true || !mounted) return;

    final result = await showOrderPaymentSheet(context, order);
    if (!mounted) return;
    if (result == PaySheetResult.walletSuccess) {
      await _fetchOrder();
      ref.read(walletProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('✅ Payment successful via Wallet! OTP shown below.'),
          backgroundColor: _kGreen,
          duration: Duration(seconds: 4),
        ),
      );
    } else if (result == PaySheetResult.upiRequested) {
      _initiatePayment();
    }
  }

  // ── Pending payment notice (before BREWING) ────────────────────────────────

  Widget _buildPendingPaymentNotice(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kAmberBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.info_outline_rounded, color: _kAmber, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Payment Pending', fontWeight: FontWeight.w800, color: _kAmber),
                SizedBox(height: 3),
                AppText(
                  'You will be able to pay once admin confirms the bill after inspecting your clothes.',
                  fontSize: 12,
                  color: _kText,
                ),
                SizedBox(height: 4),
                AppText(
                  'Invoice will be available for download after successful payment.',
                  fontSize: 11,
                  color: _kMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment confirmed banner ───────────────────────────────────────────────

  Widget _buildPaymentConfirmed(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGreenBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _kGreen, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Payment Successful', fontWeight: FontWeight.w800, color: _kGreen),
                    const SizedBox(height: 3),
                    AppText(
                      '₹${(order.billAmount ?? order.totalAmount).toStringAsFixed(2)} paid successfully',
                      fontSize: 12,
                      color: _kText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InvoiceDownloadButton(orderId: order.id),
        ],
      ),
    );
  }

  // ── OTP section ────────────────────────────────────────────────────────────

  Widget _buildOtpSection(OrderModel order) {
    final otp = order.deliveryOtp!;
    final isSelfPickup = order.deliveryType == DeliveryType.selfPickup;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
        boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _kGreenBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shield_rounded, color: _kGreen, size: 18),
              ),
              const SizedBox(width: 10),
              const AppText('Delivery OTP', fontSize: 16, fontWeight: FontWeight.w800, color: _kText),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            isSelfPickup
                ? 'Show this OTP at the counter when collecting your order.'
                : 'Share this OTP with the delivery partner to confirm your delivery.',
            fontSize: 12,
            color: _kMuted,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: otp.split('').map((digit) => Container(
              width: 58,
              height: 66,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: _kGreenBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
              ),
              child: Center(
                child: Text(
                  digit,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _kGreen,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 15, color: _kOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    isSelfPickup
                        ? 'Keep this OTP private. Only show it at the counter when you collect your order.'
                        : 'Keep this OTP private. Only share it when your delivery partner arrives.',
                    fontSize: 12,
                    color: _kOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Row helper ─────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value, {
    bool bold = false,
    Color? valueColor,
    int maxLines = 1,
  }) =>
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, color: _kMuted, fontSize: 13),
        const Spacer(),
        Flexible(
          child: AppText(
            value,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? _kText,
            fontSize: bold ? 15 : 13,
            textAlign: TextAlign.right,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
}

// ═════════════════════════════════════════════════════════════════════════════
// PAY CHIP (compact pill inside the Pay Now card)
// ═════════════════════════════════════════════════════════════════════════════

class _PayChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PayChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          AppText(label,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PAYMENT BOTTOM SHEET  (moved to widgets/order_payment_sheet.dart)
// ═════════════════════════════════════════════════════════════════════════════
// Kept as stub below only to satisfy the Dart analyser — the actual sheet is
// opened via showOrderPaymentSheet() which uses OrderPaymentSheet.

class _PaymentSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  const _PaymentSheet({required this.order});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  _PayMethod _selectedPayMethod = _PayMethod.wallet;
  bool _paying = false;
  String? _payError;
  final _paymentService = PaymentService();

  Future<void> _payWithWallet() async {
    setState(() { _paying = true; _payError = null; });
    try {
      await _paymentService.payOrderWithWallet(orderId: widget.order.id);
      if (!mounted) return;
      Navigator.pop(context, _PaySheetResult.walletSuccess);
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
    final billAmount    = widget.order.billAmount!;
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
            child: Row(
              children: [
                const Expanded(
                  child: AppText('Complete Payment',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kText),
                ),
                AppText(fmt.format(billAmount),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _kPrimary),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppText(
              'Order #${widget.order.displayNumber} · Select a payment method',
              fontSize: 12,
              color: _kMuted,
            ),
          ),
          const SizedBox(height: 20),

          // ── Scrollable options ────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wallet card
                  _PayMethodCard(
                    selected: _selectedPayMethod == _PayMethod.wallet,
                    onTap: () => setState(
                        () => _selectedPayMethod = _PayMethod.wallet),
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
                              width: 18,
                              height: 18,
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
                    subtitle: walletState.isLoading
                        ? 'Checking balance…'
                        : walletState.error != null
                            ? 'Could not load balance'
                            : hasSufficient
                                ? 'Balance: ${fmt.format(walletBalance)} — sufficient ✓'
                                : 'Balance: ${fmt.format(walletBalance)} — top up needed',
                    subtitleColor: hasSufficient
                        ? _kGreen
                        : hasInsufficient
                            ? _kOrange
                            : _kMuted,
                    badge: hasSufficient ? 'Instant' : null,
                  ),
                  const SizedBox(height: 10),

                  // UPI / Card
                  _PayMethodCard(
                    selected: _selectedPayMethod == _PayMethod.upi,
                    onTap: () =>
                        setState(() => _selectedPayMethod = _PayMethod.upi),
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
                    subtitle: 'Pay via Razorpay — UPI, cards, net banking',
                    subtitleColor: _kMuted,
                  ),
                  const SizedBox(height: 14),

                  // Insufficient notice — only when loaded & truly short
                  if (_selectedPayMethod == _PayMethod.wallet &&
                      hasInsufficient) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kOrangeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kOrange.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _kOrange, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'Need ${fmt.format(billAmount - walletBalance)} more',
                                fontWeight: FontWeight.w800,
                                color: _kOrange,
                                fontSize: 13,
                              ),
                              const SizedBox(height: 2),
                              const AppText(
                                  'Top up your wallet or choose UPI.',
                                  fontSize: 12,
                                  color: _kText),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await context.push(AppRoutes.addMoney);
                            if (mounted) {
                              ref
                                  .read(walletProvider.notifier)
                                  .refresh();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: _kOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const AppText('Add Money',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Wallet payment error
                  if (_payError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kRedBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: _kRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child:
                                AppText(_payError!, color: _kRed, fontSize: 12)),
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
                        (_selectedPayMethod == _PayMethod.wallet &&
                            hasInsufficient))
                    ? null
                    : () {
                        if (_selectedPayMethod == _PayMethod.wallet) {
                          _payWithWallet();
                        } else {
                          Navigator.pop(
                              context, _PaySheetResult.upiRequested);
                        }
                      },
                icon: _paying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        _selectedPayMethod == _PayMethod.wallet
                            ? Icons.account_balance_wallet_rounded
                            : Icons.payment_rounded,
                        size: 18,
                      ),
                label: Text(_paying
                    ? 'Processing…'
                    : _selectedPayMethod == _PayMethod.wallet
                        ? 'Pay ${fmt.format(billAmount)} via Wallet'
                        : 'Pay ${fmt.format(billAmount)} via UPI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor:
                      _kPrimary.withValues(alpha: 0.4),
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
// PAYMENT METHOD CARD
// ═════════════════════════════════════════════════════════════════════════════

class _PayMethodCard extends StatelessWidget {
  const _PayMethodCard({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    this.badge,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF2453FF);
    const kPrimaryBg = Color(0xFFEEF2FF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kPrimaryBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kPrimary : const Color(0xFFE5E7EB),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? kPrimary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  AppText(title,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? kPrimary : const Color(0xFF0A1645)),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: AppText(badge!,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF12B76A)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                AppText(subtitle, fontSize: 12, color: subtitleColor),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? kPrimary : const Color(0xFFD1D5DB),
                width: selected ? 6 : 2,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TIMELINE ITEM
// ═════════════════════════════════════════════════════════════════════════════

class _TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final bool isCompleted;
  final bool isLast;
  final String? extra;

  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.isCompleted,
    this.isLast = false,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF2453FF);
    const kMuted   = Color(0xFF7D86A5);
    const kText    = Color(0xFF0A1645);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon column
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted ? kPrimary : (isActive ? const Color(0xFFEEF2FF) : Colors.grey[100]),
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(color: kPrimary.withValues(alpha: 0.4), width: 4)
                    : null,
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                size: 17,
                color: isCompleted ? Colors.white : (isActive ? kPrimary : Colors.grey[400]),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? kPrimary.withValues(alpha: 0.3) : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  fontWeight: FontWeight.w800,
                  color: isCompleted ? kText : kMuted,
                ),
                AppText(subtitle, fontSize: 12, color: kMuted),
                if (extra != null) ...[
                  const SizedBox(height: 4),
                  AppText(extra!, fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
