import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../location/models/address_model.dart';
import '../../location/providers/address_provider.dart';
import '../../location/screens/checkout_address_screen.dart';
import '../../services/providers/cart_provider.dart';
import '../models/checkout_models.dart';
import '../providers/checkout_slot_provider.dart';
import '../services/payment_service.dart';
import 'checkout_screen.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF2453FF);
const _kBlueBg = Color(0xFFEEF2FF);
const _kDark   = Color(0xFF0A1645);
const _kGrey   = Color(0xFF6B7280);
const _kBg     = Color(0xFFF4F6FB);
const _kGreen  = Color(0xFF15803D);
const _kGreenBg= Color(0xFFDCF5E8);

// ═════════════════════════════════════════════════════════════════════════════
class SchedulingScreen extends ConsumerStatefulWidget {
  const SchedulingScreen({super.key});
  @override
  ConsumerState<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends ConsumerState<SchedulingScreen> {
  final _paymentService = PaymentService();

  // hidden controllers used for API calls — NO hardcoded defaults.
  // Coordinates are populated from the saved address in _syncAddr().
  // Keeping these empty prevents silently using wrong coordinates when
  // the user enters an address manually without GPS.
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();

  // reception form
  final _receptionCtrl = TextEditingController();
  final _flatCtrl      = TextEditingController();
  final _secCtrl       = TextEditingController();
  final _notesCtrl     = TextEditingController();

  bool _addrSynced = false;

  CheckoutServiceType _serviceType = CheckoutServiceType.collectFromHome;
  CheckoutOptions?    _options;
  CheckoutShop?       _selectedShop;
  CheckoutSlot?       _pickupSlot;
  CheckoutSlot?       _deliverySlot;
  final CheckoutPaymentMethod _payMethod = CheckoutPaymentMethod.cashOnDelivery;
  List<CheckoutShop>  _shops = [];
  bool   _loadingOptions = false;
  String? _optionsError;

  // Standard time slots from the admin-managed API
  List<CheckoutSlot> _standardPickupSlots  = [];
  bool _loadingStandardSlots = false;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool get _needsAddress =>
      _serviceType == CheckoutServiceType.collectFromHome ||
      _serviceType == CheckoutServiceType.homeReception;

  @override
  void initState() {
    super.initState();
    // Slot chosen on the Pickup & Delivery screen — don't ask again here.
    _pickupSlot = ref.read(selectedPickupSlotProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoad());
  }

  void _syncAddr() {
    if (_addrSynced) return;
    final a = ref.read(selectedAddressProvider);
    if (a == null) return;
    _addrSynced = true;
    _addrCtrl.text = a.fullAddress;
    if (a.lat != null) _latCtrl.text = a.lat!.toString();
    if (a.lng != null) _lngCtrl.text = a.lng!.toString();
  }

  Future<void> _fetchStandardSlots() async {
    setState(() => _loadingStandardSlots = true);
    try {
      final result = await _paymentService.getStandardTimeSlots(date: _today);
      if (result != null && mounted) {
        final items = ref.read(cartProvider).lineItems;
        final allInstant =
            items.isNotEmpty && items.every((i) => i.category == 'instant');
        setState(() {
          _standardPickupSlots   = result.pickupSlots;
          if (allInstant) {
            // Auto-select the Instant slot so no user action is needed. Don't
            // fall back to a scheduled slot when Instant isn't in the list —
            // same reasoning as _applyOptions: this runs concurrently with
            // _fetchOptions (see _autoLoad's Future.wait) and would otherwise
            // race to silently overwrite a correct null/error state with a
            // wrong scheduled slot.
            if (_pickupSlot == null) {
              final instantSlot =
                  result.pickupSlots.where((s) => s.isInstant).firstOrNull;
              _pickupSlot = instantSlot;
              if (instantSlot == null) {
                _optionsError ??= 'Instant not available';
              }
            }
          } else {
            // Scheduled order — keep the slot chosen on the previous screen.
            _pickupSlot ??= ref.read(selectedPickupSlotProvider);
          }
          if (_deliverySlot == null && result.deliverySlots.isNotEmpty) {
            _deliverySlot = result.deliverySlots.first;
          }
        });
      }
    } catch (_) {
      // Non-fatal – slots section stays empty
    } finally {
      if (mounted) setState(() => _loadingStandardSlots = false);
    }
  }

  Future<void> _autoLoad() async {
    _syncAddr();
    await Future.wait([_fetchOptions(), _fetchStandardSlots()]);
  }

  Future<void> _fetchOptions() async {
    setState(() { _loadingOptions = true; _optionsError = null; });
    try {
      if (_needsAddress) {
        final addr = _buildAddress();
        if (addr == null) {
          // Silently bailing here used to leave the "Proceed" button
          // disabled with zero explanation — most commonly because the
          // selected address has no lat/lng (saved before GPS capture, or
          // geocoding failed at save time). Surface it so the user knows
          // to fix the address instead of a checkout page that just does
          // nothing.
          final missingCoords =
              _latCtrl.text.trim().isEmpty || _lngCtrl.text.trim().isEmpty;
          setState(() {
            _loadingOptions = false;
            _optionsError = missingCoords
                ? 'This address is missing a precise location. Please edit '
                    'it (use "Use Current Location" or search) or pick a '
                    'different address.'
                : 'Please add a valid pickup address.';
          });
          return;
        }
        final opts = await _paymentService.checkServiceability(
          serviceType: _serviceType, address: addr, date: _today,
        );
        // opts == null means the backend found no eligible shop near the
        // address. Do NOT fall back to CheckoutOptions.assumed() — that
        // produces locationId:'default' which causes a 500 on the order
        // endpoint. Show a clear error instead so the user can fix their
        // address or try a different location.
        if (opts == null) {
          throw Exception(
            'No laundry service is available at your address yet. '
            'Please try a different location or contact support.',
          );
        }
        _applyOptions(opts);
      } else {
        // Drop at Shop needs no address/coordinates — coordinates narrow the
        // shop list to "nearby" when available (e.g. a saved address exists),
        // but their absence just means "browse every active branch" instead
        // of blocking the flow (the backend's getNearbyShops already supports
        // both modes).
        final lat = double.tryParse(_latCtrl.text.trim());
        final lng = double.tryParse(_lngCtrl.text.trim());
        final shops = await _paymentService.getAvailableShops(
          latitude: lat, longitude: lng, date: _today);
        if (shops.isEmpty) throw Exception('No shops available right now.');
        setState(() {
          _shops = shops;
          _selectedShop = shops.firstWhere((s) => s.recommended, orElse: () => shops.first);
        });
        await _loadShopSlots();
      }
    } catch (e) {
      final raw = e.toString();
      setState(() => _optionsError =
          raw.startsWith('Exception: ') ? raw.substring(11) : raw);
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _loadShopSlots() async {
    if (_selectedShop == null) return;
    // For Drop at Shop the user physically walks in, so the shop's service
    // radius (which covers pickup/delivery reach) must not block them.
    // Use the shop's own coordinates — distance to itself is 0, so the
    // service-area check always passes and we get the shop's correct slot list.
    // Fall back to the user's home coords only if shop lat/lng are unavailable.
    final lat = _selectedShop!.latitude ?? double.tryParse(_latCtrl.text.trim());
    final lng = _selectedShop!.longitude ?? double.tryParse(_lngCtrl.text.trim());
    final res = await _paymentService.getCheckoutOptions(
      serviceType: CheckoutServiceType.dropAtShop,
      selectedShopId: _selectedShop!.id,
      date: _today, latitude: lat, longitude: lng,
    );
    if (res != null) _applyOptions(res);
  }

  void _applyOptions(CheckoutOptions opts) {
    final items = ref.read(cartProvider).lineItems;
    final allInstant =
        items.isNotEmpty && items.every((i) => i.category == 'instant');
    setState(() {
      _options = opts;
      // When the shop is temporarily at capacity the backend returns partial
      // options (no slots) with an availabilityWarning. Show the warning but
      // keep the button enabled — slots come from the standard-time-slots API
      // and the backend re-validates capacity at order creation time.
      if (opts.availabilityWarning != null) {
        _optionsError = opts.availabilityWarning;
      }
      if (allInstant) {
        // Instant order: auto-pick the Instant slot. If it's not in the list
        // (e.g. past today's cutoff), don't fall back to a scheduled slot —
        // that would send a scheduled pickupTime for an Instant-only cart and
        // surface a misleading "location closed at this time" error instead
        // of the real reason.
        final instantSlot =
            opts.pickupSlots.where((s) => s.isInstant).firstOrNull;
        _pickupSlot = instantSlot;
        if (instantSlot == null) {
          _optionsError = 'Instant not available';
        }
      } else if (opts.pickupSlots.isNotEmpty) {
        // Scheduled order: keep the slot chosen on the previous screen.
        _pickupSlot ??= ref.read(selectedPickupSlotProvider);
      }
      if (opts.deliverySlots.isNotEmpty) {
        _deliverySlot = opts.deliverySlots.first;
      }
    });
  }

  CheckoutAddress? _buildAddress({bool allowEmpty = false}) {
    final lat  = double.tryParse(_latCtrl.text.trim());
    final lng  = double.tryParse(_lngCtrl.text.trim());
    final text = _addrCtrl.text.trim();
    if (lat == null || lng == null) return null;
    if (!allowEmpty && text.isEmpty) return null;
    return CheckoutAddress(
      fullAddress: text.isEmpty ? 'Current location' : text,
      latitude: lat, longitude: lng, label: 'Primary',
    );
  }

  Future<void> _proceed() async {
    final cart = ref.read(cartProvider);
    final cartItems = cart.lineItems;
    final isAllInstant =
        cartItems.isNotEmpty && cartItems.every((i) => i.category == 'instant');

    if (_serviceType == CheckoutServiceType.homeReception &&
        (_receptionCtrl.text.trim().isEmpty || _flatCtrl.text.trim().isEmpty)) {
      setState(() => _optionsError = 'Reception name and flat number are required.');
      return;
    }

    if (isAllInstant && _pickupSlot == null) {
      setState(() => _optionsError = 'Instant not available');
      return;
    }
    if (!isAllInstant && _pickupSlot == null) {
      setState(() => _optionsError = 'Please select a pickup time slot.');
      return;
    }
    // Address is only required for the collect-from-home leg — Drop at Shop
    // is address-free, its authoritative requirement is the selected branch.
    final addr  = _needsAddress ? _buildAddress() : null;
    final selShop  = _serviceType == CheckoutServiceType.dropAtShop
        ? (_selectedShop ?? _options?.shop) : null;
    final asgShop  = _serviceType == CheckoutServiceType.dropAtShop
        ? selShop : _options?.shop;
    if (_needsAddress && addr == null) {
      setState(() => _optionsError = 'Please add a valid pickup address.');
      return;
    }
    if (asgShop == null) {
      setState(() => _optionsError = 'Could not determine the branch. Please retry.');
      return;
    }

    final ctx = CheckoutContext(
      serviceType: _serviceType,
      pickupAddress: addr,
      receptionDetails: _serviceType == CheckoutServiceType.homeReception
          ? ReceptionDetails(
              receptionName: _receptionCtrl.text.trim(),
              flatVillaNumber: _flatCtrl.text.trim(),
              securityInstructions: _secCtrl.text.trim(),
              pickupNotes: _notesCtrl.text.trim())
          : null,
      selectedShop: selShop,
      assignedShop: asgShop,
      pickupSlot: _pickupSlot,
      // Scheduled orders deliver on the SAME slot, shifted by the order's
      // turnaround — the backend derives this from the pickup slot, so
      // mirror it here for the summary.
      deliverySlot: isAllInstant ? _deliverySlot : _pickupSlot,
      paymentMethod: _payMethod,
      expectedAmount: cart.totalPrice,
    );

    // CheckoutScreen pops back with an error message when the customer's
    // selected branch (Drop at Shop) turned out to be unavailable at order
    // creation — refresh the branch list and surface it here instead of
    // leaving the customer on a checkout screen with nothing to fix.
    final result = await Navigator.push<String>(context,
        MaterialPageRoute(builder: (_) => CheckoutScreen(checkoutContext: ctx)));
    if (result != null && mounted) {
      setState(() => _optionsError = result);
      _fetchOptions();
    }
  }

  @override
  void dispose() {
    for (final c in [_latCtrl, _lngCtrl, _addrCtrl,
                     _receptionCtrl, _flatCtrl, _secCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Listen for late address arrival
    ref.listen(selectedAddressProvider, (prev, addr) {
      if (addr == null) return;
      // Re-validate whenever the address actually changes (user tapped "Change").
      // The !_addrSynced guard only covers the initial silent load in _syncAddr;
      // we must NOT skip this when the user picks a different address later.
      final changed = prev == null ||
          prev.fullAddress != addr.fullAddress ||
          prev.lat != addr.lat ||
          prev.lng != addr.lng;
      if (!changed) return;

      _addrSynced = true;
      _addrCtrl.text = addr.fullAddress;
      _latCtrl.text = addr.lat?.toString() ?? '';
      _lngCtrl.text = addr.lng?.toString() ?? '';
      // Immediately clear stale options so "Proceed to Pay" is disabled until
      // the new address is validated against the service area.
      if (mounted) setState(() { _options = null; _optionsError = null; });
      Future.wait([_fetchOptions(), _fetchStandardSlots()]);
    });

    final selectedAddr = ref.watch(selectedAddressProvider);
    final cart         = ref.watch(cartProvider);
    final cartItems    = cart.lineItems;
    final isAllInstant =
        cartItems.isNotEmpty && cartItems.every((i) => i.category == 'instant');
    // Turnaround reflects what's actually in the cart — an order mixing
    // services (e.g. 24h Wash & Fold + 48h Dry Cleaning) takes the longest
    // one, matching how the backend computes the delivery date at checkout.
    // Scheduled orders only — instant orders never reach this calculation.
    final scheduledCartItems = cartItems.where((i) => i.category == 'scheduled');
    final turnaroundHours = scheduledCartItems.isEmpty
        ? 24
        : scheduledCartItems
            .map((i) => i.service.turnaroundHours)
            .reduce((a, b) => a > b ? a : b);
    // For instant orders: just needs options resolved.
    // For scheduled orders: also requires the user to have selected a slot.
    final canProceed =
        _options != null && (isAllInstant || _pickupSlot != null);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [

          // ── 1. Delivery address ───────────────────────────────────────
          _SectionLabel(icon: Icons.location_on_rounded, label: 'Delivery Address'),
          const SizedBox(height: 8),
          _AddressCard(
            address: selectedAddr,
            onChangeTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CheckoutAddressScreen())),
          ),
          const SizedBox(height: 20),

          // ── 2. Order items ────────────────────────────────────────────
          _SectionLabel(icon: Icons.receipt_long_rounded, label: 'Order Summary'),
          const SizedBox(height: 8),
          _OrderItemsCard(items: cartItems),
          const SizedBox(height: 20),

          // ── 3. Service type ────────────────────────────────────────────
          _SectionLabel(icon: Icons.local_laundry_service_rounded, label: 'Service Type'),
          const SizedBox(height: 8),
          _ServiceTypeSelector(
            current: _serviceType,
            onChanged: (t) {
              setState(() {
                _serviceType = t;
                _options = null;
                _optionsError = null;
                _shops = [];
              });
              _fetchOptions();
            },
          ),
          const SizedBox(height: 20),

          // ── 4. Reception details (conditional) ────────────────────────
          if (_serviceType == CheckoutServiceType.homeReception) ...[
            _SectionLabel(icon: Icons.person_pin_circle_rounded, label: 'Reception Details'),
            const SizedBox(height: 8),
            _ReceptionForm(
              receptionCtrl: _receptionCtrl,
              flatCtrl: _flatCtrl,
              secCtrl: _secCtrl,
              notesCtrl: _notesCtrl,
            ),
            const SizedBox(height: 20),
          ],

          // ── 5. Shop selector (drop at shop) ───────────────────────────
          if (!_needsAddress && _shops.isNotEmpty) ...[
            _SectionLabel(icon: Icons.store_rounded, label: 'Choose Branch'),
            const SizedBox(height: 8),
            ..._shops.map((s) => _ShopCard(
              shop: s,
              selected: _selectedShop?.id == s.id,
              onTap: s.isOpen ? () async {
                setState(() => _selectedShop = s);
                await _loadShopSlots();
              } : null,
            )),
            const SizedBox(height: 20),
          ],

          // ── 6. Delivery Time ───────────────────────────────────────────
          // Instant orders: info banner (no slot selection needed).
          // Scheduled orders: the pickup slot was already chosen on the
          //   previous screen — show the DELIVERY time derived from it
          //   (same slot, shifted by the cart's turnaround) instead of
          //   asking for pickup again. Slot picker only appears as a
          //   fallback when no slot was chosen.
          if (isAllInstant) ...[
            if (_serviceType != CheckoutServiceType.dropAtShop) ...[
              const _InstantPickupBanner(),
              const SizedBox(height: 20),
            ],
          ] else if (_pickupSlot != null && !_pickupSlot!.isInstant) ...[
            _SectionLabel(
                icon: Icons.local_shipping_rounded, label: 'Delivery Time'),
            const SizedBox(height: 8),
            _NextDayDeliveryNote(
                slotLabel: _pickupSlot!.label,
                turnaroundHours: turnaroundHours),
            const SizedBox(height: 20),
          ] else ...[
            // Fallback — user reached checkout without picking a slot.
            _SectionLabel(icon: Icons.local_shipping_rounded, label: 'Pickup Time'),
            const SizedBox(height: 8),
            if (_loadingOptions || _loadingStandardSlots)
              const Center(child: CircularProgressIndicator(color: _kBlue))
            // The backend injects a "Full Day" placeholder only when the admin
            // hasn't configured real slots for today — never a real bookable
            // slot, so it must be excluded before checking/rendering the list.
            else if ((_options?.pickupSlots ?? [])
                .where((s) => !s.isInstant && !s.isFallback).isNotEmpty)
              _StandardSlotPicker(
                slots: _options!.pickupSlots
                    .where((s) => !s.isInstant && !s.isFallback).toList(),
                selected: _pickupSlot,
                onSelect: (s) => setState(() => _pickupSlot = s),
              )
            else if (_standardPickupSlots
                .where((s) => !s.isInstant && !s.isFallback).isNotEmpty)
              _StandardSlotPicker(
                slots: _standardPickupSlots
                    .where((s) => !s.isInstant && !s.isFallback).toList(),
                selected: _pickupSlot,
                onSelect: (s) => setState(() => _pickupSlot = s),
              )
            else
              _AnyTimeChip(label: 'Scheduled pickup unavailable today'),
            const SizedBox(height: 20),
          ],

          // ── 8. Loading / error state ───────────────────────────────────
          if (_loadingOptions) ...[
            _SectionLabel(icon: Icons.access_time_rounded, label: 'Checking Availability'),
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(color: _kBlue)),
            const SizedBox(height: 20),
          ],

          if (_optionsError != null && !_loadingOptions) ...[
            _ErrorCard(message: _optionsError!),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _fetchOptions,
                icon: const Icon(Icons.refresh_rounded, color: _kBlue),
                label: const Text('Retry', style: TextStyle(color: _kBlue, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── 9. Branch info ─────────────────────────────────────────────
          if (_options != null) ...[
            _SectionLabel(icon: Icons.store_rounded, label: 'Assigned Branch'),
            const SizedBox(height: 8),
            _AssignedShopBanner(
              options: _options!,
              serviceType: _serviceType,
              selectedShop: _selectedShop,
            ),
            const SizedBox(height: 20),
          ],

        ],
      ),

      // ── Bottom CTA ─────────────────────────────────────────────────────────
      bottomNavigationBar: _BottomBar(
        canProceed: canProceed,
        isLoading: _loadingOptions,
        isAllInstant: isAllInstant,
        onTap: _proceed,
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_rounded, color: _kDark),
    ),
    title: const Text('Checkout',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kDark)),
    centerTitle: true,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFFE9EDFA)),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// ADDRESS CARD
// ═════════════════════════════════════════════════════════════════════════════

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onChangeTap});
  final AddressModel? address;
  final VoidCallback onChangeTap;

  @override
  Widget build(BuildContext context) {
    if (address == null) {
      return GestureDetector(
        onTap: onChangeTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(border: true),
          child: const Row(children: [
            Icon(Icons.add_location_alt_rounded, color: _kBlue, size: 22),
            SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Delivery Address',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _kBlue)),
                SizedBox(height: 3),
                Text('Tap to add or select a saved address',
                    style: TextStyle(fontSize: 12, color: _kGrey)),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: _kGrey),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(border: true, borderColor: _kBlue.withAlpha(70)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.location_on_rounded, color: _kBlue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Badge(address!.type, bg: _kBlueBg, color: _kBlue),
              if (address!.isDefault) ...[
                const SizedBox(width: 6),
                const _Badge('Default', bg: _kGreenBg, color: _kGreen),
              ],
            ]),
            const SizedBox(height: 6),
            if (address!.line1.isNotEmpty)
              Text(address!.line1,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kDark)),
            const SizedBox(height: 2),
            Text(address!.line2,
                style: const TextStyle(fontSize: 13, color: _kGrey, height: 1.4)),
          ],
        )),
        GestureDetector(
          onTap: onChangeTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(8)),
            child: const Text('Change',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kBlue)),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ORDER ITEMS CARD
// ═════════════════════════════════════════════════════════════════════════════

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.items});
  final List<CartLineItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(),
        child: const Row(children: [
          Icon(Icons.shopping_cart_outlined, color: _kGrey, size: 20),
          SizedBox(width: 10),
          Text('Your cart is empty', style: TextStyle(color: _kGrey)),
        ]),
      );
    }
    return Container(
      decoration: _cardDeco(),
      child: Column(children: [
        ...items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.local_laundry_service_rounded,
                      color: _kBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.service.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14, color: _kDark)),
                    const SizedBox(height: 2),
                    Text('Starting at ₹${item.service.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: _kGrey)),
                  ],
                )),
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.category == 'instant'
                        ? const Color(0xFFFFFBEB)
                        : _kBlueBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.category == 'instant' ? '⚡ Instant' : '🕐 Scheduled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.category == 'instant'
                          ? const Color(0xFFD97706)
                          : _kBlue,
                    ),
                  ),
                ),
              ]),
            ),
            if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14,
                color: Color(0xFFF3F4F6)),
          ]);
        }),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SERVICE TYPE SELECTOR
// ═════════════════════════════════════════════════════════════════════════════

class _ServiceTypeSelector extends StatelessWidget {
  const _ServiceTypeSelector({required this.current, required this.onChanged});
  final CheckoutServiceType current;
  final ValueChanged<CheckoutServiceType> onChanged;

  static const _opts = [
    (type: CheckoutServiceType.collectFromHome,
     icon: Icons.home_rounded,
     label: 'Home Pickup',
     sub: 'We collect from your address'),
    (type: CheckoutServiceType.dropAtShop,
     icon: Icons.store_rounded,
     label: 'Drop at Shop',
     sub: 'Drop off at nearest branch'),
    (type: CheckoutServiceType.homeReception,
     icon: Icons.apartment_rounded,
     label: 'Reception Pickup',
     sub: 'Collection via building desk'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      child: Column(children: [
        ..._opts.asMap().entries.map((e) {
          final opt = e.value;
          final sel = current == opt.type;
          final isLast = e.key == _opts.length - 1;
          return Column(children: [
            GestureDetector(
              onTap: () => onChanged(opt.type),
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sel ? _kBlue : _kBlueBg,
                      borderRadius: BorderRadius.circular(9)),
                    child: Icon(opt.icon, size: 18,
                        color: sel ? Colors.white : _kBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opt.label,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14,
                              color: sel ? _kBlue : _kDark)),
                      Text(opt.sub,
                          style: const TextStyle(fontSize: 12, color: _kGrey)),
                    ],
                  )),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: sel ? _kBlue : const Color(0xFFD1D5DB),
                          width: sel ? 6 : 2),
                    ),
                  ),
                ]),
              ),
            ),
            if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14,
                color: Color(0xFFF3F4F6)),
          ]);
        }),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHOP CARD
// ═════════════════════════════════════════════════════════════════════════════

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop, required this.selected, this.onTap});
  final CheckoutShop shop;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(
          border: true,
          borderColor: selected ? _kBlue : const Color(0xFFE5E7EB),
          borderWidth: selected ? 1.5 : 1,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? _kBlue : _kBlueBg,
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.store_rounded, size: 18,
                color: selected ? Colors.white : _kBlue),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(shop.shopName,
                    style: const TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 14, color: _kDark)),
                if (shop.recommended) ...[
                  const SizedBox(width: 6),
                  const _Badge('Recommended', bg: _kBlueBg, color: _kBlue),
                ],
              ]),
              const SizedBox(height: 3),
              Text(shop.fullAddress,
                  style: const TextStyle(fontSize: 12, color: _kGrey)),
              if (shop.distanceKm != null) ...[
                const SizedBox(height: 3),
                Text('${shop.distanceKm!.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _kGreen)),
              ],
            ],
          )),
          if (!shop.isOpen)
            const _Badge('Closed', bg: Color(0xFFFEF2F2), color: Color(0xFFDC2626)),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ASSIGNED SHOP BANNER
// ═════════════════════════════════════════════════════════════════════════════

class _AssignedShopBanner extends StatelessWidget {
  const _AssignedShopBanner({
    required this.options, required this.serviceType, this.selectedShop});
  final CheckoutOptions options;
  final CheckoutServiceType serviceType;
  final CheckoutShop? selectedShop;

  @override
  Widget build(BuildContext context) {
    final shop = serviceType == CheckoutServiceType.dropAtShop
        ? (selectedShop ?? options.shop) : options.shop;
    final dist = (options.distanceKm ?? shop.distanceKm ?? 0).toStringAsFixed(1);
    final label = serviceType == CheckoutServiceType.dropAtShop
        ? 'Selected Branch' : 'Assigned Branch';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBlue.withAlpha(20), _kBlue.withAlpha(8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withAlpha(60)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: _kBlue, letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(shop.shopName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kDark)),
            Text(shop.fullAddress,
                style: const TextStyle(fontSize: 12, color: _kGrey)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$dist km',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kBlue)),
          if (options.estimatedPickupTime != null)
            Text(options.estimatedPickupTime!,
                style: const TextStyle(fontSize: 11, color: _kGrey)),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SLOT PICKER
// ═════════════════════════════════════════════════════════════════════════════
// STANDARD SLOT PICKER (admin-managed global slots + Instant option)
// ═════════════════════════════════════════════════════════════════════════════

const _kAmber    = Color(0xFFD97706);
const _kAmberBg  = Color(0xFFFFFBEB);

class _StandardSlotPicker extends StatelessWidget {
  const _StandardSlotPicker({
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
          return _InstantOptionCard(
            active: active,
            onTap: () => onSelect(slot),
          );
        }
        return _StandardSlotCard(
          slot: slot,
          active: active,
          onTap: () => onSelect(slot),
        );
      }).toList(),
    );
  }
}

class _InstantOptionCard extends StatelessWidget {
  const _InstantOptionCard({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: active ? _kAmber.withAlpha(15) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _kAmber : const Color(0xFFE5E7EB),
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: _kAmber.withAlpha(40), blurRadius: 10, offset: const Offset(0, 3))]
              : [const BoxShadow(color: Color(0x09000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: active ? _kAmber : _kAmberBg,
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
                        color: active ? _kAmber : _kDark)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAmberBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kAmber.withAlpha(60)),
                  ),
                  child: const Text('~15 min',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                          color: _kAmber)),
                ),
              ]),
              const SizedBox(height: 3),
              const Text('Delivery partner reaches you in ~15 minutes',
                  style: TextStyle(fontSize: 12, color: _kGrey)),
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
}

class _StandardSlotCard extends StatelessWidget {
  const _StandardSlotCard({
    required this.slot, required this.active, required this.onTap,
  });
  final CheckoutSlot slot;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: active ? _kBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _kBlue : const Color(0xFFE5E7EB),
            width: active ? 1.5 : 1,
          ),
          boxShadow: [const BoxShadow(
              color: Color(0x09000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: active ? _kBlue : _kBlueBg,
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
                      color: active ? _kBlue : _kDark)),
              const SizedBox(height: 2),
              Text('${slot.startTime} – ${slot.endTime}',
                  style: const TextStyle(fontSize: 12, color: _kGrey)),
              if (slot.expectedTurnaround != null) ...[
                const SizedBox(height: 2),
                Text(slot.expectedTurnaround!,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: active ? _kBlue.withAlpha(180) : _kGrey)),
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
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RECEPTION FORM
// ═════════════════════════════════════════════════════════════════════════════

class _ReceptionForm extends StatelessWidget {
  const _ReceptionForm({
    required this.receptionCtrl, required this.flatCtrl,
    required this.secCtrl, required this.notesCtrl});
  final TextEditingController receptionCtrl, flatCtrl, secCtrl, notesCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(children: [
        _Field(ctrl: receptionCtrl, hint: 'Reception / lobby name', icon: Icons.person_rounded),
        const SizedBox(height: 10),
        _Field(ctrl: flatCtrl, hint: 'Flat / villa number', icon: Icons.apartment_rounded),
        const SizedBox(height: 10),
        _Field(ctrl: secCtrl, hint: 'Security instructions (optional)', icon: Icons.security_rounded),
        const SizedBox(height: 10),
        _Field(ctrl: notesCtrl, hint: 'Pickup notes (optional)', icon: Icons.notes_rounded, maxLines: 2),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.ctrl, required this.hint, required this.icon, this.maxLines = 1});
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: _kDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: _kGrey),
        prefixIcon: Icon(icon, size: 18, color: _kBlue),
        filled: true, fillColor: _kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM BAR
// ═════════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canProceed,
    required this.isLoading,
    required this.isAllInstant,
    required this.onTap,
  });
  final bool canProceed;
  final bool isLoading;
  final bool isAllInstant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withAlpha(18), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info note
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF9CA3AF)),
                SizedBox(width: 5),
                Text(
                  'Final price will be confirmed by admin after pickup',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: canProceed && !isLoading ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: canProceed && !isLoading ? _kBlue : _kBlue.withAlpha(120),
                borderRadius: BorderRadius.circular(14),
                boxShadow: canProceed && !isLoading ? [
                  BoxShadow(color: _kBlue.withAlpha(80),
                      blurRadius: 12, offset: const Offset(0, 4))
                ] : [],
              ),
              child: isLoading
                  ? const Center(child: SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
                  : Center(child: Text(
                      isAllInstant ? 'Proceed to Checkout' : 'Proceed to Schedule',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                          color: Colors.white))),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═════════════════════════════════════════════════════════════════════════════

BoxDecoration _cardDeco({
  bool border = false,
  Color borderColor = const Color(0xFFE9EDFA),
  double borderWidth = 1,
}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: border ? Border.all(color: borderColor, width: borderWidth) : null,
    boxShadow: const [BoxShadow(
        color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 2))],
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.bg, required this.color});
  final String label;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Shown instead of the slot picker when all cart items are "instant" category.
class _InstantPickupBanner extends StatelessWidget {
  const _InstantPickupBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kAmberBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAmber.withAlpha(80)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kAmber,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Instant Pickup',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _kAmber)),
              SizedBox(height: 3),
              Text(
                'A delivery partner will reach you in ~15 minutes',
                style: TextStyle(fontSize: 12, color: _kGrey),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Shown in place of a slot picker when the branch has no slots configured.
/// Communicates "any time is fine" instead of showing an error.
class _AnyTimeChip extends StatelessWidget {
  const _AnyTimeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kBlueBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBlue.withAlpha(60)),
      ),
      child: Row(children: [
        const Icon(Icons.access_time_rounded, size: 16, color: _kBlue),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kBlue)),
      ]),
    );
  }
}

/// Shows when the scheduled order will be delivered: the same slot the user
/// picked, shifted forward by the cart's turnaround (max across its scheduled
/// services — see [_SchedulingScreenState.build]). Defaults to next day (24h)
/// when no per-service turnaround applies.
class _NextDayDeliveryNote extends StatelessWidget {
  const _NextDayDeliveryNote({
    required this.slotLabel,
    this.turnaroundHours = 24,
  });
  final String slotLabel;
  final int turnaroundHours;

  @override
  Widget build(BuildContext context) {
    final deliveryDay = DateTime.now().add(Duration(hours: turnaroundHours));
    final dateStr = DateFormat('EEE, dd MMM').format(deliveryDay);
    final daysAhead = (turnaroundHours / 24).ceil();
    final timing = daysAhead <= 1 ? 'next day' : '$daysAhead days later';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kGreenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withAlpha(70)),
      ),
      child: Row(children: [
        const Icon(Icons.local_shipping_rounded, size: 16, color: _kGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Delivery: $dateStr · $slotLabel ($timing, same slot)',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kGreen),
          ),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: _kGrey),
      const SizedBox(width: 6),
      Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: _kGrey, letterSpacing: 0.6)),
    ]);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
}
