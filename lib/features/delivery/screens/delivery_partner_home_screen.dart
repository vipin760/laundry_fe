import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_text.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/models/order_model.dart';
import '../providers/delivery_orders_provider.dart';

const _navy = Color(0xFF0E1A48);
const _primaryBlue = Color(0xFF2453FF);

void _copy(BuildContext context, String value, String msg) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Home screen for users with the `delivery_partner` role.
///
/// Shows orders assigned to this partner that are out for delivery.
/// On handover the partner asks the customer for the 4-digit OTP the
/// customer received after payment, and enters it here to complete
/// the delivery.
class DeliveryPartnerHomeScreen extends ConsumerWidget {
  const DeliveryPartnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deliveryOrdersProvider);
    final partnerName = ref.watch(authProvider).user?.name;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('My Deliveries',
                fontSize: 18, fontWeight: FontWeight.w800),
            if (partnerName != null && partnerName.isNotEmpty)
              AppText(partnerName,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: _navy),
            onPressed: () =>
                ref.read(deliveryOrdersProvider.notifier).fetchAssigned(),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: _navy),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(deliveryOrdersProvider.notifier).fetchAssigned(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, DeliveryOrdersState state) {
    if (state.isLoading && state.active.isEmpty && state.completed.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.active.isEmpty && state.completed.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.black26),
          const SizedBox(height: 12),
          Center(
            child: AppText(state.error!,
                fontSize: 14, color: Colors.black54,
                textAlign: TextAlign.center),
          ),
        ],
      );
    }

    if (state.active.isEmpty && state.completed.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.local_shipping_outlined, size: 48, color: Colors.black26),
          SizedBox(height: 12),
          Center(
            child: AppText('No deliveries assigned to you yet',
                fontSize: 14, color: Colors.black54),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (state.active.isNotEmpty) ...[
          const AppText('OUT FOR DELIVERY',
              fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45),
          const SizedBox(height: 10),
          ...state.active.map(
            (o) => _DeliveryCard(
              order: o,
              onConfirm: () => _openOtpSheet(context, ref, o),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (state.completed.isNotEmpty) ...[
          const AppText('COMPLETED',
              fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45),
          const SizedBox(height: 10),
          ...state.completed.map((o) => _DeliveryCard(order: o)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  void _openOtpSheet(BuildContext context, WidgetRef ref, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OtpConfirmSheet(order: order),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order, this.onConfirm});

  final OrderModel order;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final isActive = onConfirm != null;
    final itemsSummary = order.items
        .map((i) => '${i.serviceName} × ${i.quantity}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _primaryBlue.withValues(alpha: 0.25) : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppText('#${order.displayNumber}',
                  fontSize: 15, fontWeight: FontWeight.w800),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFFF3E6)
                      : const Color(0xFFE9F9EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText(
                  isActive ? 'Out for delivery' : 'Delivered',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFFB25E09)
                      : const Color(0xFF1B8A46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (itemsSummary.isNotEmpty)
            AppText(itemsSummary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          if (order.customer?.name != null && order.customer!.name!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_outline,
                    size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText(order.customer!.name!,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      maxLines: 1),
                ),
              ],
            ),
          ],
          if (order.customer?.phone != null && order.customer!.phone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone_outlined,
                    size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText(order.customer!.phone!,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      maxLines: 1),
                ),
              ],
            ),
          ],
          if (order.customer?.address != null && order.customer!.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText(order.customer!.address!,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      maxLines: 3),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _copy(context, order.customer!.address!, 'Address copied'),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.copy_rounded, size: 16, color: Colors.black45),
                  ),
                ),
              ],
            ),
          ],
          if (order.receptionDetails != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded,
                          size: 16, color: Colors.black45),
                      const SizedBox(width: 6),
                      const AppText('Reception Pickup',
                          fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
                    ],
                  ),
                  if (order.receptionDetails!.receptionName != null &&
                      order.receptionDetails!.receptionName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    AppText('Reception: ${order.receptionDetails!.receptionName}',
                        fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                  ],
                  if (order.receptionDetails!.flatVillaNumber != null &&
                      order.receptionDetails!.flatVillaNumber!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText('Flat/Villa: ${order.receptionDetails!.flatVillaNumber}',
                        fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                  ],
                  if (order.receptionDetails!.securityInstructions != null &&
                      order.receptionDetails!.securityInstructions!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText('Security: ${order.receptionDetails!.securityInstructions}',
                        fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                  ],
                  if (order.receptionDetails!.pickupNotes != null &&
                      order.receptionDetails!.pickupNotes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText('Notes: ${order.receptionDetails!.pickupNotes}',
                        fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          AppText('₹${order.effectiveAmount.toStringAsFixed(0)}',
              fontSize: 15, fontWeight: FontWeight.w800,
              color: const Color(0xFF1B8A46)),
          if (isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Enter customer OTP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── OTP bottom sheet ──────────────────────────────────────────────────────────

class _OtpConfirmSheet extends ConsumerStatefulWidget {
  const _OtpConfirmSheet({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_OtpConfirmSheet> createState() => _OtpConfirmSheetState();
}

class _OtpConfirmSheetState extends ConsumerState<_OtpConfirmSheet> {
  final _otpController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      setState(() => _error = 'Please enter the 4-digit OTP.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref
        .read(deliveryOrdersProvider.notifier)
        .completeDelivery(widget.order.id, otp);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content:
            Text('Order #${widget.order.displayNumber} delivered successfully'),
        backgroundColor: const Color(0xFF1B8A46),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Confirm delivery · #${widget.order.displayNumber}',
              fontSize: 17, fontWeight: FontWeight.w800),
          const SizedBox(height: 6),
          const AppText(
            'Ask the customer for the 4-digit OTP they received after '
            'payment and enter it below to complete this delivery.',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _otpController,
            enabled: !_submitting,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 16,
              color: _navy,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              filled: true,
              fillColor: const Color(0xFFF6F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            AppText(_error!,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD32F2F)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify & complete delivery',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
