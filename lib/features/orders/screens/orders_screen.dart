import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/payment_config.dart';
import '../../../core/payments/app_razorpay.dart';
import '../../checkout/models/checkout_models.dart' show DeliveryType;
import '../../checkout/services/payment_service.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../../checkout/screens/track_order_screen.dart';
import '../widgets/order_payment_sheet.dart';
import 'order_detail_screen.dart';

// ── Brand colours ──────────────────────────────────────────────────────────────
const _kPrimary    = Color(0xFF2453FF);
const _kPrimaryBg  = Color(0xFFEEF2FF);
const _kBg         = Color(0xFFF5F7FF);
const _kGreen      = Color(0xFF12B76A);
const _kGreenBg    = Color(0xFFECFDF5);
const _kOrange     = Color(0xFFF79009);
const _kOrangeBg   = Color(0xFFFFF4E5);
const _kRed        = Color(0xFFD92D20);
const _kRedBg      = Color(0xFFFEF3F2);
const _kText       = Color(0xFF0A1645);
const _kMuted      = Color(0xFF7D86A5);
const _kBorder     = Color(0xFFE8EEFF);

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() => ref.read(ordersProvider.notifier).fetchOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    final summary = state.summary;

    final active = state.orders
        .where((o) =>
            o.status != OrderStatus.completed &&
            o.status != OrderStatus.cancelled)
        .where(_matchesSearch)
        .toList();

    final completed = state.orders
        .where((o) => o.status == OrderStatus.completed)
        .where(_matchesSearch)
        .toList();

    final cancelled = state.orders
        .where((o) => o.status == OrderStatus.cancelled)
        .where(_matchesSearch)
        .toList();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header + stats ─────────────────────────────────────────────
            _buildHeader(summary),

            // ── Tabs ───────────────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: _kPrimary,
                indicatorWeight: 2.5,
                labelColor: _kPrimary,
                unselectedLabelColor: _kMuted,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(text: 'Active (${summary.activeCount})'),
                  Tab(text: 'Completed (${summary.completedCount})'),
                  Tab(text: 'Cancelled (${summary.cancelledCount})'),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: _kPrimary, strokeWidth: 2.5))
                  : state.error != null
                      ? _ErrorView(
                          message: state.error!,
                          onRetry: () =>
                              ref.read(ordersProvider.notifier).fetchOrders(),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _ActiveOrdersList(orders: active),
                            _CompletedOrdersList(
                              orders: completed,
                              onRate: _showRatingDialog,
                              onBookAgain: _handleBookAgain,
                            ),
                            _CancelledOrdersList(orders: cancelled),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesSearch(OrderModel o) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return o.displayNumber.toLowerCase().contains(q) ||
        o.items.any((i) => i.serviceName.toLowerCase().contains(q));
  }

  Widget _buildHeader(OrdersSummary summary) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _IconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My Orders',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _kText)),
                          SizedBox(height: 2),
                          Text("Here's what's happening with your laundry",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: _kMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: () =>
                        ref.read(ordersProvider.notifier).fetchOrders(),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.notifications_none_rounded,
                    onTap: () {},
                    badge: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _StatCard(
                icon: Icons.shopping_bag_outlined,
                iconColor: _kPrimary,
                iconBg: _kPrimaryBg,
                value: '${summary.activeCount}',
                label: 'Active Orders',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.check_circle_outline_rounded,
                iconColor: _kGreen,
                iconBg: _kGreenBg,
                value: '${summary.completedCount}',
                label: 'Completed',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: _kPrimary,
                iconBg: _kPrimaryBg,
                value: '₹${summary.totalSaved.toStringAsFixed(0)}',
                label: 'Total Saved',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search bar
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, color: _kMuted, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                        fontSize: 14,
                        color: _kText,
                        fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search by Order ID or Service',
                      hintStyle: TextStyle(color: _kMuted, fontSize: 13.5),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      color: _kPrimary, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  void _showRatingDialog(OrderModel order) {
    int selectedRating = order.rating ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Rate Your Order',
              style:
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Order #${order.displayNumber}',
                  style: const TextStyle(color: _kMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedRating = i + 1),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: _kOrange,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: _kMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary),
              onPressed: selectedRating == 0
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await ref
                          .read(ordersProvider.notifier)
                          .rateOrder(order.id, selectedRating);
                    },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBookAgain(OrderModel order) {
    // OrdersScreen is reached via an imperative Navigator.push (see
    // home_screen.dart), not a go_router location change, so context.go()
    // has no route to pop back through — it just no-ops. Pop the imperative
    // stack back to the root (Home) instead.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTIVE ORDERS LIST
// ══════════════════════════════════════════════════════════════════════════════

class _ActiveOrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  const _ActiveOrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyState(
        icon: Icons.local_laundry_service_outlined,
        message: 'No active orders',
        sub: 'Book a laundry service to get started!',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: orders.length,
      itemBuilder: (_, i) => _ActiveOrderCard(order: orders[i]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPLETED ORDERS LIST
// ══════════════════════════════════════════════════════════════════════════════

class _CompletedOrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final void Function(OrderModel) onRate;
  final void Function(OrderModel) onBookAgain;

  const _CompletedOrdersList({
    required this.orders,
    required this.onRate,
    required this.onBookAgain,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline_rounded,
        message: 'No completed orders yet',
        sub: 'Completed orders will appear here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: orders.length,
      itemBuilder: (_, i) => _CompletedOrderCard(
        order: orders[i],
        onRate: onRate,
        onBookAgain: onBookAgain,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CANCELLED ORDERS LIST
// ══════════════════════════════════════════════════════════════════════════════

class _CancelledOrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  const _CancelledOrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyState(
        icon: Icons.cancel_outlined,
        message: 'No cancelled orders',
        sub: '',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: orders.length,
      itemBuilder: (_, i) => _CancelledOrderCard(order: orders[i]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTIVE ORDER CARD
// ══════════════════════════════════════════════════════════════════════════════

class _ActiveOrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  const _ActiveOrderCard({required this.order});

  @override
  ConsumerState<_ActiveOrderCard> createState() => _ActiveOrderCardState();
}

class _ActiveOrderCardState extends ConsumerState<_ActiveOrderCard> {
  late final AppRazorpay _razorpay;
  final _paymentService = PaymentService();
  bool _paying = false;
  String? _currentOrderId;

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
    _razorpay.clear();
    super.dispose();
  }

  void _onPayError(PaymentFailureResponse r) {
    // Do NOT call markPaymentFailed — Razorpay was dismissed client-side;
    // order paymentStatus stays PENDING so the user can tap Pay Now again.
    if (!mounted) return;
    setState(() => _paying = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r.message ?? 'Payment failed. Please try again.'),
      backgroundColor: _kRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

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
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Payment successful! Your delivery OTP is ready.'),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
      // Navigate to order detail to show OTP
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: widget.order.id),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payment verification failed. Please contact support.'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _initiatePayment() async {
    setState(() => _paying = true);
    try {
      final data = await _paymentService.initiatePaymentForOrder(orderId: widget.order.id);
      _currentOrderId = data['orderId']?.toString() ?? widget.order.id;
      final razorpayOrderId = data['razorpayOrderId'] as String? ?? '';
      final amount = (data['amount'] as num?)?.toInt() ?? 0;

      _razorpay.open({
        'key': PaymentConfig.razorpayKeyId,
        'amount': amount,
        'name': 'LaundryBrew',
        'order_id': razorpayOrderId,
        'description': 'Laundry Order #${widget.order.displayNumber}',
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
        'prefill': {'contact': '8888888888', 'email': 'test@razorpay.com'},
        'external': {'wallets': ['paytm']},
      });
      if (mounted) setState(() => _paying = false);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.startsWith('Exception: ') ? msg.substring(11) : msg),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _showPaymentSheet(OrderModel order) async {
    if (_paying) return;

    final result = await showOrderPaymentSheet(context, order);
    if (!mounted) return;

    if (result == PaySheetResult.walletSuccess) {
      await ref.read(ordersProvider.notifier).fetchOrders();
      ref.read(walletProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payment successful via Wallet! Your delivery OTP is ready.'),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
    } else if (result == PaySheetResult.upiRequested) {
      await _initiatePayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isOutForDelivery = order.status == OrderStatus.outForDelivery;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Top row ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isOutForDelivery ? _kOrangeBg : _kPrimaryBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isOutForDelivery
                        ? Icons.dry_cleaning_outlined
                        : Icons.iron_outlined,
                    color: isOutForDelivery ? _kOrange : _kPrimary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),

                // Order info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.items.map((i) => i.serviceName).join(' & '),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Order #${order.displayNumber}',
                        style: const TextStyle(
                            fontSize: 13, color: _kMuted),
                      ),
                      const SizedBox(height: 6),
                      _StatusBadge(status: order.status),
                    ],
                  ),
                ),

                // ETA or date badge
                isOutForDelivery
                    ? _EtaBadge(etaMinutes: order.etaMinutes)
                    : _DateBadge(order: order),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F2F8)),
          const SizedBox(height: 14),

          // ── Out for delivery: rider row + live track ─────────────────────
          if (isOutForDelivery) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: _kPrimary, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        'Live Tracking  •  ${order.driverDistanceKm?.toStringAsFixed(1) ?? '—'} km away',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary),
                      ),
                      const Spacer(),
                      if (order.driverName != null)
                        Text('Rider: ${order.driverName}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: _kText,
                                fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                          icon: Icons.shopping_bag_outlined,
                          label:
                              '${order.itemCount ?? order.items.length} Items'),
                      const SizedBox(width: 12),
                      _InfoChip(
                          icon: Icons.currency_rupee_rounded,
                          label:
                              '₹${order.effectiveAmount.toStringAsFixed(0)}'),
                      const Spacer(),
                      _TrackButton(
                        label: 'Live Track',
                        icon: Icons.location_searching_rounded,
                        onTap: () => _openTracking(context),
                        outlined: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Progress stepper ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child:
                  _ProgressStepper(status: order.status, order: order),
            ),
            const SizedBox(height: 14),

            // ── Weight + price + track / pay ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (order.weightKg != null) ...[
                    _InfoChip(
                        icon: Icons.scale_outlined,
                        label:
                            '${order.weightKg!.toStringAsFixed(0)} Kg'),
                    const SizedBox(width: 12),
                  ],
                  if (order.billAmount != null)
                    _InfoChip(
                        icon: Icons.currency_rupee_rounded,
                        label:
                            '₹${order.effectiveAmount.toStringAsFixed(0)}')
                  else
                    _InfoChip(
                        icon: Icons.info_outline_rounded,
                        label: 'Bill pending'),
                  const Spacer(),
                  // Show "Pay Now" once bill is confirmed (itemized/brewing)
                  // through dispatch (ready for pickup/out for delivery) and
                  // payment is outstanding (PENDING or FAILED)
                  if ((order.status == OrderStatus.itemized ||
                          order.status == OrderStatus.brewing ||
                          order.status == OrderStatus.readyForPickup ||
                          order.status == OrderStatus.outForDelivery) &&
                      order.billAmount != null &&
                      order.paymentStatus != PaymentStatus.completed)
                    _paying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: _kPrimary),
                          )
                        : _TrackButton(
                            label: 'Pay Now',
                            icon: Icons.payment_rounded,
                            onTap: () => _showPaymentSheet(order),
                          )
                  else
                    _TrackButton(
                      label: 'Track Order',
                      icon: Icons.arrow_forward_rounded,
                      onTap: () => _openTracking(context),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  void _openTracking(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackOrderScreen(
          orderId: widget.order.id,
          orderNumber: widget.order.displayNumber,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPLETED ORDER CARD
// ══════════════════════════════════════════════════════════════════════════════

class _CompletedOrderCard extends StatelessWidget {
  final OrderModel order;
  final void Function(OrderModel) onRate;
  final void Function(OrderModel) onBookAgain;

  const _CompletedOrderCard({
    required this.order,
    required this.onRate,
    required this.onBookAgain,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _kGreenBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_laundry_service_outlined,
                      color: _kGreen, size: 28),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.items.map((i) => i.serviceName).join(' & '),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text('Order #${order.displayNumber}',
                          style: const TextStyle(
                              fontSize: 12.5, color: _kMuted)),
                      const SizedBox(height: 6),
                      const _StatusBadge(status: OrderStatus.completed),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Delivered on',
                        style:
                            TextStyle(fontSize: 11, color: _kMuted)),
                    Text(
                      DateFormat('MMM dd, yyyy')
                          .format(order.createdAt),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _kText),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(order.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: _kMuted),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F2F8)),
            const SizedBox(height: 12),

            Row(
              children: [
                if (order.weightKg != null) ...[
                  _InfoChip(
                      icon: Icons.scale_outlined,
                      label:
                          '${order.weightKg!.toStringAsFixed(0)} Kg'),
                  const SizedBox(width: 10),
                ],
                _InfoChip(
                    icon: Icons.currency_rupee_rounded,
                    label:
                        '₹${order.effectiveAmount.toStringAsFixed(0)}'),
                const SizedBox(width: 10),
                // Star rating (tappable)
                GestureDetector(
                  onTap: () => onRate(order),
                  child: Row(
                    children: List.generate(5, (i) {
                      final filled =
                          order.rating != null && i < order.rating!;
                      return Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: filled
                            ? _kOrange
                            : const Color(0xFFD1D5DB),
                        size: 18,
                      );
                    }),
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => onBookAgain(order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side: const BorderSide(
                        color: _kPrimary, width: 1.5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Book Again',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CANCELLED ORDER CARD
// ══════════════════════════════════════════════════════════════════════════════

class _CancelledOrderCard extends StatelessWidget {
  final OrderModel order;
  const _CancelledOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kRedBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: _kRed, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.items.map((i) => i.serviceName).join(' & '),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text('Order #${order.displayNumber}',
                      style: const TextStyle(
                          fontSize: 12.5, color: _kMuted)),
                  const SizedBox(height: 6),
                  const _StatusBadge(status: OrderStatus.cancelled),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${order.effectiveAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kRed),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd').format(order.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: _kMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROGRESS STEPPER
// ══════════════════════════════════════════════════════════════════════════════

class _ProgressStepper extends StatelessWidget {
  final OrderStatus status;
  final OrderModel order;
  const _ProgressStepper({required this.status, required this.order});

  static const _steps = [
    ('Pickup',     Icons.directions_bike_rounded),
    ('Collected',  Icons.inventory_2_outlined),
    ('Cleaning',   Icons.dry_cleaning_outlined),
    ('Quality\nCheck', Icons.search_rounded),
    ('Out for\nDelivery', Icons.electric_scooter_rounded),
    ('Delivered',  Icons.home_rounded),
  ];

  int get _currentStep {
    switch (status) {
      case OrderStatus.orderPlaced:    return 1;
      case OrderStatus.pickupAssigned: return 2;
      case OrderStatus.itemized:       return 2;
      case OrderStatus.brewing:        return 3;
      case OrderStatus.outForDelivery: return 5;
      case OrderStatus.completed:      return 6;
      default:                         return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStep;

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIndex = i ~/ 2;
                final done = stepIndex < current - 1;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: done ? _kPrimary : const Color(0xFFE2E8F0),
                  ),
                );
              }
              final stepIndex = i ~/ 2;
              final isDone   = stepIndex < current - 1;
              final isActive = stepIndex == current - 1;

              return Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? _kPrimary : Colors.white,
                  border: Border.all(
                    color: isDone || isActive
                        ? _kPrimary
                        : const Color(0xFFD8DDED),
                    width: isActive ? 2 : 1.5,
                  ),
                ),
                child: Icon(
                  isDone
                      ? Icons.check_rounded
                      : _steps[stepIndex].$2,
                  size: 15,
                  color: isDone
                      ? Colors.white
                      : isActive
                          ? _kPrimary
                          : const Color(0xFFB8BFDC),
                ),
              );
            }),
          ),
        ),
        // Labels
        Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) return const Expanded(child: SizedBox());
            final stepIndex = i ~/ 2;
            final isDone   = stepIndex < current - 1;
            final isActive = stepIndex == current - 1;
            return SizedBox(
              width: 38,
              child: Text(
                _steps[stepIndex].$1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight:
                      isActive || isDone ? FontWeight.w700 : FontWeight.w500,
                  color: isDone || isActive ? _kPrimary : _kMuted,
                  height: 1.3,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      OrderStatus.orderPlaced    => ('Confirmed',        _kPrimary, _kPrimaryBg),
      OrderStatus.pickupAssigned => ('Pickup Assigned',  _kOrange,  _kOrangeBg),
      OrderStatus.itemized       => ('Itemized',         _kOrange,  _kOrangeBg),
      OrderStatus.brewing        => ('Brewing',           _kGreen,   _kGreenBg),
      OrderStatus.outForDelivery => ('Out for Delivery', _kPrimary, _kPrimaryBg),
      OrderStatus.readyForPickup => ('Ready for Delivery', _kPrimary, _kPrimaryBg),
      OrderStatus.completed      => ('Delivered',        _kGreen,   _kGreenBg),
      OrderStatus.cancelled      => ('Cancelled',        _kRed,     _kRedBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final OrderModel order;
  const _DateBadge({required this.order});

  /// Friendly "expected by" line from the server-computed ETA — deliberately
  /// never shows an overdue/alarm state (that's an admin-only SLA signal);
  /// once the window passes we just soften to "shortly".
  String? _friendlyEta() {
    final deadline = order.etaDeadline;
    final milestone = order.etaMilestone;
    if (deadline == null || milestone == null) return null;

    final isSelfPickup = order.deliveryType == DeliveryType.selfPickup;
    final verb = milestone == 'PICKUP'
        ? 'Pickup'
        : (isSelfPickup ? 'Ready' : 'Arriving');

    final now = DateTime.now();
    if (now.isAfter(deadline)) return '$verb shortly';

    final local = deadline.toLocal();
    final timeStr = DateFormat('h:mm a').format(local);
    final isToday = DateUtils.isSameDay(local, now);
    return isToday
        ? '$verb by $timeStr'
        : '$verb by ${DateFormat('dd MMM').format(local)}, $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = order.pickupDate != null &&
        DateUtils.isSameDay(order.pickupDate!, now);
    final label = isToday ? 'Today' : (order.pickupSlot ?? 'Scheduled');
    final friendlyEta = _friendlyEta();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _kPrimaryBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5E0FF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 11, color: _kPrimary),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary)),
            ],
          ),
          if (friendlyEta != null) ...[
            const SizedBox(height: 2),
            Text(
              friendlyEta,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _kPrimary),
            ),
          ] else if (order.deliverySlot != null || order.deliveryDate != null) ...[
            const SizedBox(height: 2),
            const Text('Expected',
                style: TextStyle(fontSize: 10, color: _kMuted)),
            Text(
              [
                if (order.deliveryDate != null)
                  DateFormat('dd MMM').format(order.deliveryDate!.toLocal()),
                if (order.deliverySlot != null) order.deliverySlot!,
              ].join(' · '),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _kPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

class _EtaBadge extends StatelessWidget {
  final int? etaMinutes;
  const _EtaBadge({this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _kOrangeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD89A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.electric_scooter_rounded,
                  size: 13, color: _kOrange),
              SizedBox(width: 3),
              Text('ETA',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kOrange)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            etaMinutes != null ? '$etaMinutes mins' : '—',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _kOrange),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _kMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: _kText, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TrackButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;
  const _TrackButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kPrimary,
          side: const BorderSide(color: _kPrimary, width: 1.5),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: _kPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _kText)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: _kMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _IconBtn(
      {required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FF),
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: Icon(icon, color: _kText, size: 20),
          ),
          if (badge)
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: _kPrimary, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _EmptyState(
      {required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration:
                const BoxDecoration(color: _kPrimaryBg, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: _kPrimary),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kText)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sub,
                style:
                    const TextStyle(fontSize: 13, color: _kMuted)),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: _kMuted),
            const SizedBox(height: 16),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
