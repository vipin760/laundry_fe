import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/legal_links.dart';
import '../../location/models/address_model.dart';
import '../../orders/widgets/select_delivery_address_sheet.dart';
import '../../services/models/service_model.dart';
import '../../services/providers/cart_provider.dart';
import '../models/checkout_models.dart';
import '../providers/checkout_slot_provider.dart';
import '../services/payment_service.dart';
import 'order_success_screen.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF2453FF);
const _kBlueBg  = Color(0xFFEEF2FF);
const _kDark    = Color(0xFF0E1A48);
const _kGrey    = Color(0xFF6B7280);
const _kBg      = Color(0xFFEEF1FB);


// ═════════════════════════════════════════════════════════════════════════════

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.checkoutContext});
  final CheckoutContext checkoutContext;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isProcessing  = false;
  bool _termsAccepted = true;
  bool _shippingEnabled = false;
  String? _error;

  DeliveryType _deliveryType = DeliveryType.homeDelivery;
  AddressModel? _deliveryAddress;

  static const double _freeDeliveryThreshold = 249;
  static const double _deliveryFeeAmount = 49;

  /// Single source of truth for delivery-fee eligibility: true whenever at
  /// least one leg of this order requires a delivery partner to travel
  /// (Home Pickup and/or Home Delivery). Only Self Drop-off + Self Pickup —
  /// where the customer handles both legs — has neither a minimum order nor
  /// a delivery fee. Every fee/visibility check below reads this getter
  /// instead of re-deriving the pickup/delivery combination.
  ///
  /// Pickup leg uses explicit equality (not `!= dropAtShop`) so a future
  /// [CheckoutServiceType] value must be deliberately classified here rather
  /// than silently defaulting to "home leg".
  bool get _hasHomeLeg =>
      widget.checkoutContext.serviceType == CheckoutServiceType.collectFromHome ||
      widget.checkoutContext.serviceType == CheckoutServiceType.homeReception ||
      _deliveryType == DeliveryType.homeDelivery;

  // Calculate shipping charges based on total amount
  double _calculateShippingCharges(double totalAmount) {
    if (!_hasHomeLeg || !_shippingEnabled) return 0;
    return totalAmount >= _freeDeliveryThreshold ? 0 : _deliveryFeeAmount;
  }

  double get _shippingCharges => _calculateShippingCharges(widget.checkoutContext.expectedAmount);

  Future<void> _chooseDeliveryAddress() async {
    final picked = await showSelectDeliveryAddressSheet(context);
    if (picked != null) setState(() => _deliveryAddress = picked);
  }

  void _setDeliveryType(DeliveryType type) {
    setState(() {
      _deliveryType = type;
      // Reset the acknowledgment toggle once the Shipping section would be
      // hidden entirely (no home leg left) — nothing left to acknowledge.
      if (!_hasHomeLeg) {
        _shippingEnabled = false;
      }
    });
  }

  bool _isOrderReadyToPlace() {
    // Check basic requirements
    if (!_termsAccepted || _isProcessing) return false;

    // Whenever a home leg is involved, the shipping option works like an
    // agreement: button stays disabled until the user selects it.
    // (Missing address is validated on tap with a helpful message.)
    if (_hasHomeLeg) {
      return _shippingEnabled;
    }

    // Self Drop-off + Self Pickup: only require terms acceptance
    return true;
  }

  Future<void> _placeOrder() async {
    if (!_termsAccepted) {
      _snack('Please accept the Terms & Conditions to proceed.');
      return;
    }
    if (_deliveryType == DeliveryType.homeDelivery && _deliveryAddress == null) {
      _snack('Please select a delivery address for your finished order.');
      return;
    }
    if (_hasHomeLeg && !_shippingEnabled) {
      _snack('Please enable shipping to proceed.');
      return;
    }
    setState(() { _isProcessing = true; _error = null; });
    try {
      // New flow: place order now (no upfront payment).
      // Admin will inspect, itemize, set bill, and move to Brewing.
      // User pays from My Orders > Order Detail once admin confirms the bill.
      // We always use the simple checkout endpoint — Razorpay is initiated later.

      // Add shipping charges to the expected amount if shipping is enabled
      final totalAmount = widget.checkoutContext.expectedAmount + _shippingCharges;

      final orderData = await _paymentService.placeOrderOnly(
        checkoutContext: CheckoutContext(
          serviceType: widget.checkoutContext.serviceType,
          paymentMethod: widget.checkoutContext.paymentMethod,
          expectedAmount: totalAmount,
          pickupSlot: widget.checkoutContext.pickupSlot,
          deliverySlot: widget.checkoutContext.deliverySlot,
          pickupAddress: widget.checkoutContext.pickupAddress,
          receptionDetails: widget.checkoutContext.receptionDetails,
          selectedShop: widget.checkoutContext.selectedShop,
          assignedShop: widget.checkoutContext.assignedShop,
        ),
        deliveryType: _deliveryType,
        deliveryAddress: _deliveryAddress,
      );

      // Capture the admin's Order Placed message before the cart is cleared —
      // same booking-type signal (line item category) already used elsewhere
      // in checkout to distinguish Instant from Scheduled. No calculation,
      // just a lookup on the service that was actually ordered.
      final lineItems = ref.read(cartProvider).lineItems;
      final orderPlacedMessage = lineItems.isEmpty
          ? null
          : lineItems.first.service.orderPlacedMessageFor(
              ServiceCategory.fromValue(lineItems.first.category),
            );

      ref.read(cartProvider.notifier).clearCart();
      ref.read(selectedPickupSlotProvider.notifier).clear();
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _navigateToSuccess(
        orderId:     (orderData['_id'] ?? orderData['orderId'] ?? '').toString(),
        orderNumber: (orderData['orderNumber'] ?? '').toString(),
        actualPickupDate: orderData['pickupDate'] as String?,
        actualDeliveryDate: orderData['deliveryDate'] as String?,
        orderPlacedMessage: orderPlacedMessage,
      );
    } on LocationUnavailableException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      // The selected Drop-at-Shop branch isn't usable right now — send the
      // customer back to branch selection with a specific reason, rather than
      // showing a generic error on this screen (there's nothing to fix here).
      Navigator.of(context).pop(_locationErrorMessage(e.code, e.message));
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      setState(() {
        _isProcessing = false;
        _error = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      });
    }
  }

  /// Maps a backend LocationEligibilityReason code to customer-facing copy.
  /// Falls back to the backend's own message for any reason not listed here.
  String _locationErrorMessage(String code, String fallbackMessage) {
    switch (code) {
      case 'DAILY_CAPACITY_REACHED':
        return 'This branch has reached today\'s capacity. Please choose another nearby branch.';
      case 'LOCATION_INACTIVE':
      case 'LOCATION_NOT_FOUND':
        return 'This branch is no longer available. Please choose another branch.';
      case 'LOCATION_CLOSED_TODAY':
      case 'LOCATION_CLOSED_THIS_TIME':
      case 'LOCATION_TEMPORARILY_UNAVAILABLE':
        return 'This branch is closed right now. Please choose another branch.';
      case 'NO_PICKUP_SLOTS_AVAILABLE':
      case 'NO_DELIVERY_SLOTS_AVAILABLE':
        return 'This branch has no matching slots available. Please choose another branch.';
      default:
        return fallbackMessage;
    }
  }

  void _navigateToSuccess({
    required String orderId,
    required String orderNumber,
    String? actualPickupDate,
    String? actualDeliveryDate,
    String? orderPlacedMessage,
  }) {
    // Replace the entire checkout stack with the success screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          orderId:     orderId,
          orderNumber: orderNumber.isNotEmpty ? orderNumber : 'LB${orderId.substring(orderId.length > 5 ? orderId.length - 5 : 0).toUpperCase()}',
          pickupSlot:   widget.checkoutContext.pickupSlot,
          deliverySlot: widget.checkoutContext.deliverySlot,
          // The backend already computed the real dates for this order (it
          // knows every service's turnaround) — trust those over any
          // client-side guess.
          actualPickupDate: actualPickupDate,
          actualDeliveryDate: actualDeliveryDate,
          orderPlacedMessage: orderPlacedMessage,
          deliveryType: _deliveryType,
        ),
      ),
      (route) => route.isFirst, // keep only the home route below
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ctx = widget.checkoutContext;
    final cartItems = ref.watch(cartProvider).lineItems;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 1. Pickup & Delivery card ──────────────────────────────────
          _SectionCard(
            header: 'Pickup & Delivery',
            onEdit: () => Navigator.pop(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLabel('Service'),
              const SizedBox(height: 4),
              // List all cart items as services
              ...cartItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${item.service.name}${item.quantity > 1 ? ' × ${item.quantity}' : ''}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kDark),
                ),
              )),
              const SizedBox(height: 4),
              // const _InfoNote('Extra charges between 11 PM – 6 AM'),
              const _InfoNote('minimum order three pairs'),
              if (cartItems.isNotEmpty)
                // _InfoNote('Min. order between ${cartItems.first.service.name} only is 3 items'),
              const SizedBox(height: 12),
              const _FieldLabel('Collect From'),
              const SizedBox(height: 4),
              Text(
                _serviceTypeLabel(ctx.serviceType),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kDark),
              ),
              if (ctx.pickupAddress != null) ...[
                const SizedBox(height: 2),
                Text(
                  ctx.pickupAddress!.fullAddress,
                  style: const TextStyle(fontSize: 12, color: _kGrey),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 14),

          // ── 1b. Return delivery method ─────────────────────────────────
          _SectionCard(
            header: 'How would you like to get your order back?',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: _DeliveryTypeOption(
                    icon: Icons.local_shipping_rounded,
                    label: 'Home Delivery',
                    selected: _deliveryType == DeliveryType.homeDelivery,
                    onTap: () => _setDeliveryType(DeliveryType.homeDelivery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DeliveryTypeOption(
                    icon: Icons.storefront_rounded,
                    label: 'Self Pickup',
                    selected: _deliveryType == DeliveryType.selfPickup,
                    onTap: () => _setDeliveryType(DeliveryType.selfPickup),
                  ),
                ),
              ]),
              if (_deliveryType == DeliveryType.homeDelivery) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _chooseDeliveryAddress,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kBlueBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDCE3FF)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.location_on_rounded, color: _kBlue, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _deliveryAddress?.fullAddress ?? 'Select a delivery address',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _deliveryAddress != null ? _kDark : _kGrey,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 18),
                    ]),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const _InfoNote('You\'ll collect your finished order from our shop.'),
              ],
            ]),
          ),
          const SizedBox(height: 14),

          // ── 1c. Shipping Option (only when a home leg is involved) ───────
          if (_hasHomeLeg) ...[
            _SectionCard(
              header: 'Shipping',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _shippingEnabled = !_shippingEnabled),
                child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _shippingEnabled ? _kBlue : const Color(0xFFD1D5DB),
                      width: _shippingEnabled ? 6 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text(
                      'Unlock Free Delivery',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _kDark),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Order for ₹${_freeDeliveryThreshold.toStringAsFixed(0)} or more to get FREE delivery.'
                      'Otherwise, a ₹${_deliveryFeeAmount.toStringAsFixed(0)} delivery fee applies.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kGrey),
                    ),
                  ]),
                ),
              ]),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── 2. Price notice ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your bill will be confirmed by our team after we pick up and inspect your items.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600, height: 1.5),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── 4. Error (if any) ──────────────────────────────────────────
          if (_error != null) ...[
            _ErrorCard(message: _error!),
            const SizedBox(height: 10),
          ],

          // ── 6. Terms & Conditions ──────────────────────────────────────
          _TermsRow(
            accepted: _termsAccepted,
            onChanged: (v) => setState(() => _termsAccepted = v),
          ),
          const SizedBox(height: 20),
        ]),
      ),

      // ── Bottom: Place Order button ──────────────────────────────────────────
      bottomNavigationBar: _PlaceOrderBar(
        isProcessing: _isProcessing,
        enabled: _isOrderReadyToPlace(),
        onTap: _placeOrder,
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: _kBg,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: _kDark),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Review Your Order',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kDark)),
        Text('Please confirm your order details',
            style: TextStyle(fontSize: 11, color: _kGrey, fontWeight: FontWeight.w500)),
      ],
    ),
    titleSpacing: 0,
  );

  String _serviceTypeLabel(CheckoutServiceType t) => switch (t) {
    CheckoutServiceType.collectFromHome => 'Home Pickup',
    CheckoutServiceType.dropAtShop     => 'Drop at Shop',
    CheckoutServiceType.homeReception  => 'Home / Reception',
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ═════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.header, required this.child, this.onEdit});
  final String header;
  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Expanded(child: Text(header,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kDark))),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: const Text('Edit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kBlue)),
            ),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TERMS ROW
// ═════════════════════════════════════════════════════════════════════════════

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.accepted, required this.onChanged});
  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      GestureDetector(
        onTap: () => onChanged(!accepted),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22, height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accepted ? _kBlue : const Color(0xFFD1D5DB),
              width: accepted ? 6 : 2,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: _kGrey, fontWeight: FontWeight.w500),
            children: [
              const TextSpan(text: 'By placing the order you agree to our '),
              TextSpan(
                text: 'Terms & Conditions',
                style: const TextStyle(
                  color: _kBlue,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => LegalLinks.openTermsAndConditions(context),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PLACE ORDER BOTTOM BAR
// ═════════════════════════════════════════════════════════════════════════════

class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({
    required this.isProcessing,
    required this.enabled,
    required this.onTap,
  });
  final bool isProcessing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(
          color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: _kBlue,
            disabledBackgroundColor: _kBlue.withAlpha(120),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isProcessing
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Confirm Order',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 0.3)),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey));
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(text,
        style: const TextStyle(fontSize: 11, color: _kGrey, fontWeight: FontWeight.w500)),
  );
}

class _BillRow extends StatelessWidget {
  const _BillRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label,
        style: const TextStyle(fontSize: 13, color: _kGrey, fontWeight: FontWeight.w600))),
    Text(value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark)),
  ]);
}

class _DeliveryTypeOption extends StatelessWidget {
  const _DeliveryTypeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? _kBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kBlue : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? _kBlue : _kGrey, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? _kBlue : _kDark,
              )),
        ]),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: Color(0xFF991B1B), height: 1.4))),
    ]),
  );
}
