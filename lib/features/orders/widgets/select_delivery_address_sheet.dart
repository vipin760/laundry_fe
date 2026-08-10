import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../checkout/models/checkout_models.dart';
import '../../checkout/services/payment_service.dart';
import '../../location/models/address_model.dart';
import '../../location/providers/address_provider.dart';
import '../../location/screens/add_edit_address_screen.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue = Color(0xFF2453FF);
const _kDark = Color(0xFF0A1645);
const _kGrey = Color(0xFF7D86A5);
const _kRed  = Color(0xFFDC2626);
const _kRedBg = Color(0xFFFEF2F2);

const _typeIcons = {
  'Home':  Icons.home_rounded,
  'Work':  Icons.work_rounded,
  'Other': Icons.place_rounded,
};

/// Bottom sheet for picking a return-delivery address from the customer's
/// saved addresses. Always a fresh choice — never pre-selected — per the
/// "always pick fresh from saved addresses" requirement for home delivery.
/// Returns the chosen [AddressModel], or null if dismissed without a choice.
Future<AddressModel?> showSelectDeliveryAddressSheet(BuildContext context) {
  return showModalBottomSheet<AddressModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SelectDeliveryAddressSheet(),
  );
}

class _SelectDeliveryAddressSheet extends ConsumerStatefulWidget {
  const _SelectDeliveryAddressSheet();

  @override
  ConsumerState<_SelectDeliveryAddressSheet> createState() =>
      _SelectDeliveryAddressSheetState();
}

class _SelectDeliveryAddressSheetState
    extends ConsumerState<_SelectDeliveryAddressSheet> {
  final _paymentService = PaymentService();

  // Address currently being validated — disables the rest of the list and
  // swaps its chevron for a spinner so taps can't stack up while a check
  // is in flight.
  String? _checkingId;
  String? _error;

  /// Same radius check the pickup-address flow already runs before checkout —
  /// applied here too so a return-delivery address outside the shop's service
  /// area is caught the moment it's picked, not after the order is placed.
  Future<void> _selectAddress(AddressModel addr) async {
    if (_checkingId != null) return; // a check is already in flight

    if (addr.lat == null || addr.lng == null) {
      setState(() => _error =
          "This address doesn't have a precise location saved, so we can't "
          'confirm we deliver there. Please edit it (use "Use Current '
          'Location" or search) or pick a different address.');
      return;
    }

    setState(() {
      _checkingId = addr.id;
      _error = null;
    });

    final ServiceabilityCheck result = await _paymentService.isLocationServiceable(
      latitude: addr.lat!,
      longitude: addr.lng!,
    );

    if (!mounted) return;

    if (result.serviceable) {
      Navigator.pop(context, addr);
      return;
    }

    setState(() {
      _checkingId = null;
      _error = result.reason ??
          "We don't deliver to this address yet. Please pick a different one.";
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncAddresses = ref.watch(addressesProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text('Select Delivery Address',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Where should we deliver your finished order?',
                  style: TextStyle(fontSize: 12, color: _kGrey)),
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
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline_rounded, color: _kRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: _kRed, fontSize: 12, height: 1.4)),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Flexible(
            child: asyncAddresses.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Could not load your addresses.', style: TextStyle(color: _kGrey)),
              ),
              data: (addresses) => addresses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Text(
                        'No saved addresses yet. Add one to continue.',
                        style: TextStyle(color: _kGrey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      itemCount: addresses.length,
                      itemBuilder: (context, i) {
                        final addr = addresses[i];
                        final isChecking = _checkingId == addr.id;
                        final disabled = _checkingId != null && !isChecking;
                        return _AddressTile(
                          address: addr,
                          isChecking: isChecking,
                          disabled: disabled,
                          onTap: disabled ? null : () => _selectAddress(addr),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditAddressScreen()),
                ),
                icon: const Icon(Icons.add_rounded, size: 18, color: _kBlue),
                label: const Text('Add New Address',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _kBlue)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
          SafeArea(top: false, child: const SizedBox(height: 4)),
        ],
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onTap,
    this.isChecking = false,
    this.disabled = false,
  });
  final AddressModel address;
  final VoidCallback? onTap;
  final bool isChecking;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[address.type] ?? Icons.place_rounded;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecking ? _kBlue.withAlpha(90) : const Color(0xFFE9EDFA),
            width: isChecking ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: _kBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address.type,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kDark)),
                        const SizedBox(height: 2),
                        Text(
                          address.fullAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _kGrey, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  if (isChecking)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, color: _kGrey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
