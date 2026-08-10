import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/checkout_models.dart';
import 'track_order_screen.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
const _kBlue  = Color(0xFF0137B5);
const _kDark  = Color(0xFF0A1645);
const _kGrey  = Color(0xFF6B7280);

// ═════════════════════════════════════════════════════════════════════════════
// ORDER SUCCESS SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderNumber,
    required this.orderId,
    this.pickupSlot,
    this.deliverySlot,
    this.actualPickupDate,
    this.actualDeliveryDate,
    this.orderPlacedMessage,
    this.deliveryType = DeliveryType.homeDelivery,
  });

  final String orderNumber; // e.g. "LB20394"
  final String orderId;     // MongoDB _id (for navigation)
  final CheckoutSlot? pickupSlot;
  final CheckoutSlot? deliverySlot;
  /// ISO date strings from the just-created order (order.pickupDate /
  /// order.deliveryDate) — the backend already resolved these using each
  /// service's real turnaround, so prefer them over any client-side guess.
  final String? actualPickupDate;
  final String? actualDeliveryDate;
  /// Admin-authored copy (LaundryService.instantOrderPlacedMessage /
  /// scheduledOrderPlacedMessage) for the order's booking type — looked up,
  /// never calculated, never derived from duration/turnaroundHours.
  final String? orderPlacedMessage;
  /// How the customer chose to get their finished order back — Self Pickup
  /// orders show a "ready for pickup" card instead of a "delivery" one,
  /// since there's no home delivery leg to describe.
  final DeliveryType deliveryType;

  bool get _isSelfPickup => deliveryType == DeliveryType.selfPickup;

  // ── Helpers ──────────────────────────────────────────────────────────────

  String get _displayNumber => '#$orderNumber';

  String _formatPickupDate() {
    final raw = actualPickupDate ?? pickupSlot?.date ?? '';
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      final local = raw.contains('T') ? d.toLocal() : d;
      return DateFormat('EEE, d MMM yyyy').format(local);
    } catch (_) {
      return raw;
    }
  }

  String _pickupTimeLabel() {
    final s = pickupSlot;
    if (s == null) return 'Anytime';
    if (s.isInstant) return '~15 min';
    if (s.startTime.isNotEmpty && s.endTime.isNotEmpty) {
      return '${_to12h(s.startTime)} – ${_to12h(s.endTime)}';
    }
    return s.label;
  }

  /// Scheduled only — the turnaround text off the picked slot (e.g.
  /// "24-48 hrs"). Instant has no comparable slot-level text; its ETA is a
  /// concrete time shown by [_deliveryExpected] instead.
  String _deliveryTurnaround() {
    final d = deliverySlot;
    if (d == null) return '';
    if (d.isInstant) return '';
    return d.expectedTurnaround ?? '';
  }

  /// When the order is expected — computed from the backend's
  /// [actualDeliveryDate], which is itself derived from the admin-configured
  /// turnaround on the ordered service (LaundryService.turnaroundHours for
  /// Scheduled, instantTurnaroundMinutes for Instant — see
  /// orders.service.ts's delivery-schedule block). Instant shows a same-day
  /// clock time; Scheduled shows a date + slot.
  String _deliveryExpected() {
    final d = deliverySlot;
    if (d == null) return 'Next available slot';

    if (d.isInstant) {
      if (actualDeliveryDate == null || actualDeliveryDate!.isEmpty) return '';
      try {
        final dt = DateTime.parse(actualDeliveryDate!).toLocal();
        return 'Today · ${DateFormat('h:mm a').format(dt)}';
      } catch (_) {
        return '';
      }
    }

    // Scheduled orders: use the date the backend actually computed for this
    // order (it knows every item's real turnaround — 24h, 48h, whichever is
    // longest). Only fall back to assuming "next day" if that's missing.
    String dateLabel;
    if (actualDeliveryDate != null && actualDeliveryDate!.isNotEmpty) {
      try {
        dateLabel = DateFormat('EEE, d MMM')
            .format(DateTime.parse(actualDeliveryDate!).toLocal());
      } catch (_) {
        dateLabel = DateFormat('EEE, d MMM')
            .format(DateTime.now().add(const Duration(days: 1)));
      }
    } else {
      dateLabel = DateFormat('EEE, d MMM')
          .format(DateTime.now().add(const Duration(days: 1)));
    }

    if (d.startTime.isNotEmpty && d.endTime.isNotEmpty) {
      return '$dateLabel · ${_to12h(d.startTime)} – ${_to12h(d.endTime)}';
    }
    return '$dateLabel · ${d.label}';
  }

  /// Self Pickup only — when the order will be ready to collect from the
  /// shop. Uses the same backend-computed [actualDeliveryDate] as
  /// [_deliveryExpected] (the "ready" moment is identical whether the
  /// customer collects it or has it delivered — see orders.service.ts's
  /// delivery-schedule block), just phrased as "ready", not "delivered".
  String _readyBy() {
    final raw = actualDeliveryDate;
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final isInstantOrder =
          (pickupSlot?.isInstant ?? false) || (deliverySlot?.isInstant ?? false);
      if (isInstantOrder) {
        return 'Ready by ${DateFormat('h:mm a').format(dt)} today';
      }
      final d = deliverySlot;
      final dateLabel = DateFormat('EEE, d MMM').format(dt);
      if (d != null && d.startTime.isNotEmpty && d.endTime.isNotEmpty) {
        return '$dateLabel · ${_to12h(d.startTime)} – ${_to12h(d.endTime)}';
      }
      return dateLabel;
    } catch (_) {
      return '';
    }
  }

  static String _to12h(String hhmm) {
    if (hhmm.isEmpty) return '';
    try {
      final parts = hhmm.split(':');
      int h = int.parse(parts[0]);
      final m = parts[1];
      final suffix = h >= 12 ? 'PM' : 'AM';
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
      return m == '00' ? '$h $suffix' : '$h:$m $suffix';
    } catch (_) {
      return hhmm;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(authProvider).user?.name ?? 'there';
    final firstName = userName.split(' ').first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable body ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Confetti + checkmark hero ────────────────────────
                    SizedBox(
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Confetti
                          const _ConfettiLayer(),
                          // Checkmark
                          _GreenCheckmark(),
                        ],
                      ),
                    ),

                    // ── Titles ───────────────────────────────────────────
                    const Text(
                      'Order Placed!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thank you, $firstName 👋',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'We\'ve received your order.',
                      style: TextStyle(fontSize: 14, color: _kGrey),
                    ),

                    const SizedBox(height: 20),

                    // ── Order ID ─────────────────────────────────────────
                    const Text(
                      'Order ID',
                      style: TextStyle(fontSize: 13, color: _kGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayNumber,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _kBlue,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Pickup & Delivery card ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F3FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            // Pickup
                            _InfoSection(
                              icon: Icons.verified_user_rounded,
                              title: 'Pickup',
                              rows: [
                                if (_formatPickupDate().isNotEmpty)
                                  _InfoRow(Icons.calendar_today_rounded,
                                      _formatPickupDate()),
                                _InfoRow(
                                    Icons.access_time_rounded, 'Order anytime'),
                                _InfoRow(
                                    Icons.access_time_rounded, _pickupTimeLabel()),
                              ],
                            ),

                            // Divider
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(
                                  height: 1, color: Color(0xFFDDE3F5)),
                            ),

                            // Delivery — or, for Self Pickup, when it'll be
                            // ready to collect from the shop instead.
                            if (_isSelfPickup)
                              _InfoSection(
                                icon: Icons.storefront_rounded,
                                title: 'Ready for Delivery',
                                rows: [
                                  if (_readyBy().isNotEmpty)
                                    _InfoRow(
                                        Icons.calendar_today_rounded, _readyBy()),
                                ],
                              )
                            else
                              _InfoSection(
                                icon: Icons.location_on_rounded,
                                title: 'Delivery',
                                rows: [
                                  if (_deliveryTurnaround().isNotEmpty)
                                    _InfoRow(Icons.access_time_rounded,
                                        _deliveryTurnaround()),
                                  if (_deliveryExpected().isNotEmpty)
                                    _InfoRow(Icons.calendar_today_rounded,
                                        _deliveryExpected()),
                                ],
                              ),

                            // Admin-configured message for this booking type
                            // (Instant vs Scheduled), looked up on the
                            // ordered service — supplements the computed
                            // date/time above with the shop's own copy about
                            // what to expect.
                            if (orderPlacedMessage != null &&
                                orderPlacedMessage!.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(
                                    height: 1, color: Color(0xFFDDE3F5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 14, 16, 16),
                                child: Text(
                                  orderPlacedMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _kGrey,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'You will receive updates on\nevery step of your order.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: _kGrey,
                            height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom buttons ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, 12 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  // Track Order
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => TrackOrderScreen(
                              orderId:     orderId,
                              orderNumber: orderNumber,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.local_shipping_rounded,
                          size: 20, color: Colors.white),
                      label: const Text(
                        'Track Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GREEN CHECKMARK CIRCLE
// ═════════════════════════════════════════════════════════════════════════════

class _GreenCheckmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x4010B981),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CONFETTI LAYER
// ═════════════════════════════════════════════════════════════════════════════

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer();

  static const _pieces = [
    // {dx%, dy%, color, size, angle}
    _C(0.08, 0.25, Color(0xFFFBBF24), 10, 0.5),
    _C(0.18, 0.10, Color(0xFF3B82F6), 9, -0.3),
    _C(0.30, 0.18, Color(0xFFEC4899), 8, 1.0),
    _C(0.70, 0.12, Color(0xFF10B981), 11, 0.8),
    _C(0.82, 0.20, Color(0xFFF97316), 9,  -0.6),
    _C(0.90, 0.32, Color(0xFF8B5CF6), 10, 0.4),
    _C(0.12, 0.48, Color(0xFF6366F1), 7,  1.2),
    _C(0.78, 0.48, Color(0xFFEF4444), 8, -0.9),
    _C(0.55, 0.08, Color(0xFF22D3EE), 9,  0.2),
    _C(0.44, 0.20, Color(0xFFFBBF24), 7, -0.5),
    _C(0.25, 0.60, Color(0xFF34D399), 8,  0.7),
    _C(0.88, 0.62, Color(0xFFF472B6), 9, -0.3),
    _C(0.62, 0.68, Color(0xFF60A5FA), 7,  1.1),
    _C(0.05, 0.70, Color(0xFFFBBF24), 10, -0.8),
    _C(0.95, 0.70, Color(0xFF4ADE80), 8,  0.6),
    _C(0.38, 0.72, Color(0xFFA78BFA), 9, -0.4),
    _C(0.68, 0.30, Color(0xFFFCA5A5), 7,  0.9),
    _C(0.50, 0.78, Color(0xFF67E8F9), 8, -1.0),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Stack(
        children: _pieces.map((p) {
          return Positioned(
            left: p.dx * w - p.size / 2,
            top:  p.dy * h - p.size / 2,
            child: Transform.rotate(
              angle: p.angle,
              child: Container(
                width:  p.size,
                height: p.size,
                decoration: BoxDecoration(
                  color: p.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _C {
  const _C(this.dx, this.dy, this.color, this.size, this.angle);
  final double dx, dy, size, angle;
  final Color color;
}

// ═════════════════════════════════════════════════════════════════════════════
// INFO SECTION (Pickup / Delivery)
// ═════════════════════════════════════════════════════════════════════════════

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE3F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: _kBlue),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kDark,
                  ),
                ),
                const SizedBox(height: 8),
                ...rows,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Icon(icon, size: 14, color: _kBlue),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: _kGrey,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }
}
