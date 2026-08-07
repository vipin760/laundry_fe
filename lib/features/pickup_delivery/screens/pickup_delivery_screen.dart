import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../checkout/models/checkout_models.dart';
import '../../checkout/providers/checkout_slot_provider.dart';
import '../../checkout/screens/scheduling_screen.dart';
import '../../location/providers/address_provider.dart';
import '../../location/screens/checkout_address_screen.dart';
import '../../pricing/models/cloth_type_model.dart';
import '../../pricing/providers/cloth_types_provider.dart';
import '../../services/models/service_model.dart';
import '../../services/providers/cart_provider.dart';
import '../../services/providers/services_provider.dart';
import '../providers/standard_slots_provider.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF2453FF);
const _kBg     = Color(0xFFF5F6FA);
const _kAmber  = Color(0xFFD97706);
const _kGreen  = Color(0xFF15803D);

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class PickupDeliveryScreen extends ConsumerStatefulWidget {
  /// Pass [initialTab] = 'scheduled' to open on the Standard tab.
  /// Defaults to 'instant'.
  const PickupDeliveryScreen({super.key, this.initialTab = 'instant'});
  final String initialTab;

  @override
  ConsumerState<PickupDeliveryScreen> createState() =>
      _PickupDeliveryScreenState();
}

class _PickupDeliveryScreenState
    extends ConsumerState<PickupDeliveryScreen> {
  late bool _isInstant = widget.initialTab != 'scheduled';

  // Selected pickup slot (standard tab only)
  CheckoutSlot? _pickupSlot;

  void _onProceed(BuildContext context) {
    // Scheduled orders must have a pickup slot chosen HERE — the checkout
    // page no longer asks for it (it shows the derived delivery time instead).
    final cart = ref.read(cartProvider);
    final hasScheduled =
        cart.lineItems.any((i) => i.category == 'scheduled');
    if (hasScheduled && _pickupSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pickup time slot first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Carry the chosen slot into the checkout flow.
    ref.read(selectedPickupSlotProvider.notifier).set(_pickupSlot);

    // Service type isn't chosen until SchedulingScreen, so this screen can't
    // yet know whether an address will even be needed (Drop at Shop doesn't
    // need one) — always proceed and let SchedulingScreen's own address
    // requirement (_needsAddress) decide, once the type is actually known.
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SchedulingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync  = ref.watch(servicesProvider);
    final selectedAddr   = ref.watch(selectedAddressProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A1645)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Pickup & Delivery',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A1645),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Location strip ────────────────────────────────────────────────
          _LocationStrip(
            address: selectedAddr,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutAddressScreen()),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE9EDFA)),

          // ── Tab switcher ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                children: [
                  _TabPill(
                    icon: Icons.bolt_rounded,
                    label: 'Instant',
                    selected: _isInstant,
                    onTap: () => setState(() => _isInstant = true),
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    icon: Icons.calendar_month_rounded,
                    label: 'Scheduled',
                    selected: !_isInstant,
                    onTap: () => setState(() => _isInstant = false),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: servicesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _kBlue),
              ),
              error: (err, _) => _ErrorView(
                message: err.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(servicesProvider),
              ),
              data: (services) => _isInstant
                  ? _InstantView(services: services)
                  : _ScheduledView(
                      services: services,
                      pickupSlot: _pickupSlot,
                      onPickupSlot: (s) => setState(() => _pickupSlot = s),
                    ),
            ),
          ),
        ],
      ),

      // ── Sticky cart bar ───────────────────────────────────────────────────
      bottomNavigationBar: _CartBar(
        onCheckout: () => _onProceed(context),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// INSTANT TAB CONTENT
// ═════════════════════════════════════════════════════════════════════════════

class _InstantView extends ConsumerWidget {
  const _InstantView({required this.services});
  final List<ServiceModel> services;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combos = ref.watch(clothTypesProvider).asData?.value
            .where((c) => c.category == 'ironing' && c.subcategory == 'combo')
            .toList() ??
        const <ClothTypeModel>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Instant banner ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kAmber.withAlpha(25), _kAmber.withAlpha(10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kAmber.withAlpha(60)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kAmber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instant Pickup',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                          color: Color(0xFF92400E))),
                  SizedBox(height: 3),
                  Text('Delivery partner reaches you in ~15 minutes',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB45309),
                          fontWeight: FontWeight.w500)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),

          _SectionHeader(
            title: 'INSTANT SERVICE',
          ),
          const SizedBox(height: 10),

          Builder(builder: (_) {
            final instant = services.where((s) => s.isInstant).toList();
            if (instant.isEmpty) return const _EmptyServices();
            return Column(
              children: instant
                  .map((s) => _ServiceRow(service: s, category: 'instant'))
                  .toList(),
            );
          }),

          if (combos.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader(title: 'INSTANT IRONING COMBOS'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: combos
                  .map((combo) => SizedBox(
                        width: (MediaQuery.of(context).size.width - 32 - 12) / 2,
                        child: _ComboCard(item: combo),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),
          const Center(
            child: Text(
              'All services are available with an easy to\nuse / opt out option.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SCHEDULED TAB CONTENT
// ═════════════════════════════════════════════════════════════════════════════

class _ScheduledView extends ConsumerWidget {
  const _ScheduledView({
    required this.services,
    required this.pickupSlot,
    required this.onPickupSlot,
  });

  final List<ServiceModel> services;
  final CheckoutSlot? pickupSlot;
  final ValueChanged<CheckoutSlot> onPickupSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always fetch slots for today — no date picker on standard tab
    final todayKey = formatDate(DateTime.now());
    final slotsAsync = ref.watch(standardTimeSlotsProvider(todayKey));

    // Delivery turnaround reflects what's actually in the cart — an order
    // mixing services (e.g. Wash & Fold + Dry Cleaning) takes the longest one,
    // matching how the backend computes the delivery date at checkout.
    final scheduledCartItems = ref
        .watch(cartProvider)
        .lineItems
        .where((i) => i.category == 'scheduled');
    final turnaroundHours = scheduledCartItems.isEmpty
        ? 24
        : scheduledCartItems
            .map((i) => i.service.turnaroundHours)
            .reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Services ─────────────────────────────────────────────────
          _SectionHeader(
            title: 'SCHEDULED SERVICE',
            note: 'Schedule at your convenience',
          ),
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final scheduled = services.where((s) => s.isScheduled).toList();
            if (scheduled.isEmpty) return const _EmptyServices();
            return Column(
              children: scheduled
                  .map((s) => _ServiceRow(service: s, category: 'scheduled'))
                  .toList(),
            );
          }),

          const SizedBox(height: 20),

          // ── Delivery notice ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kGreen.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kGreen.withAlpha(60)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery within $turnaroundHours hours',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14532D))),
                    const SizedBox(height: 2),
                    Text(
                        'Your order will be picked up and delivered back to you within $turnaroundHours hours.',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w500,
                            height: 1.4)),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Pickup time slots from API (instant slots excluded) ────────
          slotsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(color: _kBlue)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _ErrorView(
                message: 'Schedule not available right now.',
                onRetry: () =>
                    ref.invalidate(standardTimeSlotsProvider(todayKey)),
              ),
            ),
            data: (result) {
              // Filter out instant-type slots — standard tab only shows scheduled
              // slots. Also drop the "Full Day" placeholder the backend injects
              // only when the admin hasn't configured real slots for today —
              // it must not be rendered as a real bookable slot.
              final standardPickup = (result?.pickupSlots ?? [])
                  .where((s) => !s.isInstant && !s.isFallback)
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'PICKUP TIME'),
                  const SizedBox(height: 10),
                  if (standardPickup.isNotEmpty)
                    _ApiSlotList(
                      slots: standardPickup,
                      selected: pickupSlot,
                      onSelect: onPickupSlot,
                    )
                  else
                    const _NoSlotsCard(),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          const Center(
            child: Text(
              'All services are available with an easy to\nuse / opt out option.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── Location strip ────────────────────────────────────────────────────────────

class _LocationStrip extends StatelessWidget {
  const _LocationStrip({required this.address, required this.onTap});

  final dynamic address; // AddressModel?
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAddr = address != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            // Pin icon
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: hasAddr
                    ? _kBlue.withAlpha(18)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasAddr
                    ? Icons.location_on_rounded
                    : Icons.add_location_alt_rounded,
                size: 18,
                color: _kBlue,
              ),
            ),
            const SizedBox(width: 10),
            // Text
            Expanded(
              child: hasAddr
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Text(
                            address.type ?? 'Address',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _kBlue,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (address.isDefault == true) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCF5E8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Default',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D))),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 1),
                        Text(
                          address.fullAddress ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A1645),
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Add delivery address',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
            ),
            // Change / Add chevron
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kBlue.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasAddr ? 'Change' : 'Add',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab pill ──────────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  const _TabPill({
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? _kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: selected
                ? [BoxShadow(color: _kBlue.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: selected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.note});
  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _kBlue,
            letterSpacing: 0.4,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(
            note!,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Add-to-cart with Instant/Scheduled exclusivity ────────────────────────────
// Only one order type at a time. If the cart holds the other type, ask the
// user whether to clear it and start over with this service.
Future<void> handleAddToCart(
  BuildContext context,
  WidgetRef ref,
  ServiceModel service,
  String category,
) async {
  final cart = ref.read(cartProvider);
  if (cart.conflictsWith(category)) {
    final other = category == 'instant' ? 'Scheduled' : 'Instant';
    final label = category == 'instant' ? 'Instant' : 'Scheduled';
    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start a new order?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Your cart has $other services. You can order only one type at a '
            'time.\n\nClear the cart and add this $label service instead?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Cart'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kBlue),
            child: const Text('Clear & Add'),
          ),
        ],
      ),
    );
    if (replace == true) {
      await ref.read(cartProvider.notifier).replaceCartWith(service, category);
    }
    return;
  }
  await ref.read(cartProvider.notifier).addToCartOptimistic(service, category);
}

// ── Service row (cart-aware) ──────────────────────────────────────────────────

class _ServiceRow extends ConsumerWidget {
  const _ServiceRow({required this.service, required this.category});
  final ServiceModel service;
  final String category; // 'instant' | 'scheduled'

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('iron'))    return Icons.iron_rounded;
    if (n.contains('fold'))    return Icons.local_laundry_service_rounded;
    if (n.contains('dry'))     return Icons.dry_cleaning_rounded;
    if (n.contains('shoe'))    return Icons.shopping_bag_rounded;
    if (n.contains('premium')) return Icons.star_rounded;
    return Icons.local_laundry_service_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty     = ref.watch(cartProvider).quantityFor(service.id, category);
    final pending = ref.watch(cartProvider).isPending(service.id, category);
    final hasImage = service.imageUrl != null && service.imageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: qty > 0 ? const Color(0xFFF0F1FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty > 0 ? _kBlue : const Color(0xFFE9EDFA),
          width: qty > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Service image ────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              bottomLeft: Radius.circular(13),
            ),
            child: SizedBox(
              width: 80,
              height: 80,
              child: hasImage
                  ? Image.network(
                      service.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _FallbackIcon(
                        icon: _iconFor(service.name),
                        selected: qty > 0,
                      ),
                    )
                  : _FallbackIcon(
                      icon: _iconFor(service.name),
                      selected: qty > 0,
                    ),
            ),
          ),

          // ── Name + details ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A1645),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.descriptionFor(ServiceCategory.fromValue(category)).isNotEmpty
                        ? service.descriptionFor(ServiceCategory.fromValue(category))
                        : (service.durationFor(ServiceCategory.fromValue(category)) ?? ''),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // ── Add / Remove control ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: pending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kBlue,
                    ),
                  )
                : qty == 0
                    ? _AddButton(
                        onTap: () =>
                            handleAddToCart(context, ref, service, category),
                      )
                    : _RemoveButton(
                        onTap: () => ref
                            .read(cartProvider.notifier)
                            .decrementOrRemove(service.id, category),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Fallback icon when no image ───────────────────────────────────────────────

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.icon, required this.selected});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: selected ? _kBlue.withAlpha(28) : const Color(0xFFEEF0FF),
      child: Center(
        child: Icon(icon, color: _kBlue, size: 28),
      ),
    );
  }
}

// ── ADD button ────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'ADD',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ── Remove button (shown when service is in cart) ─────────────────────────────

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE53E3E), width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 14, color: Color(0xFF15803D)),
            SizedBox(width: 4),
            Text(
              'REMOVE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE53E3E),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sticky cart bar ───────────────────────────────────────────────────────────

class _CartBar extends ConsumerWidget {
  const _CartBar({required this.onCheckout});
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final count = cart.totalItemsCount;
    final total = cart.totalPrice;

    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cart summary
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count item${count == 1 ? '' : 's'} added',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Price at checkout',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A1645),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Proceed button
          GestureDetector(
            onTap: onCheckout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _kBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Proceed',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Combo card ────────────────────────────────────────────────────────────────

class _ComboCard extends StatelessWidget {
  const _ComboCard({required this.item});
  final ClothTypeModel item;

  @override
  Widget build(BuildContext context) {
    final badge = item.description;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDFA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A1645),
            ),
          ),
          const SizedBox(height: 6),
          if (item.hasInstantDiscount)
            Text(
              '₹${item.instantRate.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                decoration: TextDecoration.lineThrough,
              ),
            ),
          Text(
            '₹${item.effectiveInstantRate.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: item.hasInstantDiscount
                  ? Colors.green.shade700
                  : const Color(0xFF0A1645),
            ),
          ),
          if (badge != null && badge.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF5E8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── API-driven slot list ──────────────────────────────────────────────────────

class _ApiSlotList extends StatelessWidget {
  const _ApiSlotList({
    required this.slots,
    required this.selected,
    required this.onSelect,
  });

  final List<CheckoutSlot> slots;
  final CheckoutSlot? selected;
  final ValueChanged<CheckoutSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: slots.map((slot) {
        final active = selected?.label == slot.label;

        if (slot.isInstant) {
          // ── Instant option card ──────────────────────────────────────
          return GestureDetector(
            onTap: () => onSelect(slot),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: active ? _kAmber.withAlpha(18) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? _kAmber : const Color(0xFFE5E7EB),
                  width: active ? 2 : 1,
                ),
                boxShadow: [BoxShadow(
                    color: active
                        ? _kAmber.withAlpha(35)
                        : Colors.black.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: active ? _kAmber : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bolt_rounded, size: 18,
                      color: active ? Colors.white : _kAmber),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Instant',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900,
                              color: active ? _kAmber : const Color(0xFF0A1645))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kAmber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('~15 min',
                            style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    const Text('Delivery partner reaches you in ~15 minutes',
                        style: TextStyle(fontSize: 12,
                            color: Color(0xFF6B7280))),
                  ],
                )),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? _kAmber : const Color(0xFFD1D5DB),
                      width: active ? 6 : 2,
                    ),
                  ),
                ),
              ]),
            ),
          );
        }

        // ── Standard slot card ─────────────────────────────────────────
        return GestureDetector(
          onTap: () => onSelect(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEEF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? _kBlue : const Color(0xFFE5E7EB),
                width: active ? 1.5 : 1,
              ),
              boxShadow: [BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: active ? _kBlue : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule_rounded, size: 18,
                    color: active ? Colors.white : _kBlue),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.label,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: active ? _kBlue : const Color(0xFF0A1645))),
                  const SizedBox(height: 2),
                  Text('${slot.startTime} – ${slot.endTime}',
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF6B7280))),
                  if (slot.expectedTurnaround != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.timer_outlined, size: 12,
                          color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text(slot.expectedTurnaround!,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: active ? _kBlue.withAlpha(180)
                                  : const Color(0xFF9CA3AF))),
                    ]),
                  ],
                ],
              )),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? _kBlue : const Color(0xFFD1D5DB),
                    width: active ? 6 : 2,
                  ),
                ),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ── No slots card ─────────────────────────────────────────────────────────────

class _NoSlotsCard extends StatelessWidget {
  const _NoSlotsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDFA)),
      ),
      child: const Row(children: [
        Icon(Icons.event_busy_rounded, color: Color(0xFF9CA3AF), size: 20),
        SizedBox(width: 12),
        Expanded(child: Text(
          'Scheduled pickup unavailable today.\nPlease check back later.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        )),
      ]),
    );
  }
}


// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyServices extends StatelessWidget {
  const _EmptyServices();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDFA)),
      ),
      child: const Center(
        child: Text(
          'No services available right now.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
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

// ═════════════════════════════════════════════════════════════════════════════
// DATA CLASSES
// ═════════════════════════════════════════════════════════════════════════════

