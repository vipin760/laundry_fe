import 'package:flutter/material.dart';

import '../../checkout/models/checkout_models.dart' show DeliveryType;
import '../../checkout/services/payment_service.dart';
import '../../location/models/address_model.dart';
import 'select_delivery_address_sheet.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
const _kBlue = Color(0xFF2453FF);
const _kBlueBg = Color(0xFFEEF2FF);
const _kDark = Color(0xFF0A1645);
const _kGrey = Color(0xFF7D86A5);
const _kRed = Color(0xFFD92D20);
const _kRedBg = Color(0xFFFEF3F2);

/// Shown right before payment so the customer confirms (or changes) how
/// they'll receive their finished order. Returns true if confirmed and the
/// caller should proceed to payment, false/null if cancelled.
Future<bool?> showDeliveryConfirmationSheet(
  BuildContext context, {
  required String orderId,
  required DeliveryType currentType,
  AddressModel? currentAddress,
  String? shopName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeliveryConfirmationSheet(
      orderId: orderId,
      currentType: currentType,
      currentAddress: currentAddress,
      shopName: shopName,
    ),
  );
}

class _DeliveryConfirmationSheet extends StatefulWidget {
  const _DeliveryConfirmationSheet({
    required this.orderId,
    required this.currentType,
    required this.currentAddress,
    required this.shopName,
  });

  final String orderId;
  final DeliveryType currentType;
  final AddressModel? currentAddress;
  final String? shopName;

  @override
  State<_DeliveryConfirmationSheet> createState() => _DeliveryConfirmationSheetState();
}

class _DeliveryConfirmationSheetState extends State<_DeliveryConfirmationSheet> {
  final _paymentService = PaymentService();
  late DeliveryType _type = widget.currentType;
  AddressModel? _address;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _address = widget.currentAddress;
  }

  Future<void> _chooseAddress() async {
    final picked = await showSelectDeliveryAddressSheet(context);
    if (picked != null) setState(() => _address = picked);
  }

  Future<void> _confirm() async {
    if (_type == DeliveryType.homeDelivery && _address == null) {
      setState(() => _error = 'Please select a delivery address.');
      return;
    }
    final changed = _type != widget.currentType ||
        (_type == DeliveryType.homeDelivery && _address?.id != widget.currentAddress?.id);

    if (!changed) {
      Navigator.pop(context, true);
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      await _paymentService.updateDeliveryDetails(
        orderId: widget.orderId,
        deliveryType: _type,
        deliveryAddress: _address,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _saving = false;
        _error = msg.startsWith('Exception: ') ? msg.substring(11) : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Confirm How You\'ll Get Your Order',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kDark)),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Please confirm before you pay.',
                    style: TextStyle(fontSize: 12, color: _kGrey)),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: _OptionCard(
                    icon: Icons.local_shipping_rounded,
                    label: 'Home Delivery',
                    selected: _type == DeliveryType.homeDelivery,
                    onTap: () => setState(() => _type = DeliveryType.homeDelivery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OptionCard(
                    icon: Icons.storefront_rounded,
                    label: 'Self Pickup',
                    selected: _type == DeliveryType.selfPickup,
                    onTap: () => setState(() => _type = DeliveryType.selfPickup),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _type == DeliveryType.homeDelivery
                  ? GestureDetector(
                      onTap: _chooseAddress,
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
                              _address?.fullAddress ?? 'Select a delivery address',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _address != null ? _kDark : _kGrey,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 18),
                        ]),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.store_rounded, color: _kGrey, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.shopName != null
                                ? 'Collect from ${widget.shopName}'
                                : 'You\'ll collect your finished order from our shop.',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kDark),
                          ),
                        ),
                      ]),
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kRedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: _kRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: _kRed, fontSize: 12))),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm & Continue to Pay',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
            SafeArea(top: false, child: const SizedBox(height: 4)),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
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
