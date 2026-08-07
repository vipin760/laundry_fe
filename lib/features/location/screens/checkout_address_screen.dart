import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../../checkout/screens/scheduling_screen.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1A23CC);
const _kBlueDk  = Color(0xFF0F1899);
const _kBg      = Color(0xFFF5F6FA);
const _kDark    = Color(0xFF0A1645);
const _kGrey    = Color(0xFF6B7280);
const _kGreen   = Color(0xFF15803D);
const _kGreenBg = Color(0xFFDCF5E8);
const _kRed     = Color(0xFFDC2626);

// ── Address-type config ───────────────────────────────────────────────────────
const _typeConfig = {
  'Home':  (icon: Icons.home_rounded,  color: Color(0xFF1A23CC), bg: Color(0xFFEEF0FF)),
  'Work':  (icon: Icons.work_rounded,  color: Color(0xFF7C3AED), bg: Color(0xFFF3E8FF)),
  'Other': (icon: Icons.place_rounded, color: Color(0xFFEA580C), bg: Color(0xFFFFF7ED)),
};
const _types = ['Home', 'Work', 'Other'];

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// Two phases:
//   list  — shows saved addresses; auto-skipped if empty
//   form  — add / edit a single address
// ═════════════════════════════════════════════════════════════════════════════

enum _Phase { loading, list, form }

class CheckoutAddressScreen extends ConsumerStatefulWidget {
  const CheckoutAddressScreen({super.key});

  @override
  ConsumerState<CheckoutAddressScreen> createState() =>
      _CheckoutAddressScreenState();
}

class _CheckoutAddressScreenState
    extends ConsumerState<CheckoutAddressScreen> {
  _Phase _phase = _Phase.loading;

  // ── Form state ─────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  AddressModel? _editingAddress; // null = new address

  late final TextEditingController _houseCtrl;
  late final TextEditingController _buildingCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _landmarkCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _instructionsCtrl;

  String _type      = 'Home';
  bool   _isDefault = false;
  double? _lat;
  double? _lng;

  // Tracks which fields were auto-filled from GPS
  bool _areaAutoFilled    = false;
  bool _cityAutoFilled    = false;
  bool _stateAutoFilled   = false;
  bool _pincodeAutoFilled = false;

  bool _isFetchingGps = false;
  bool _isSaving      = false;

  // Tracks whether user has existing addresses (for back-nav in form)
  bool _hadAddresses = false;

  @override
  void initState() {
    super.initState();
    _houseCtrl        = TextEditingController();
    _buildingCtrl     = TextEditingController();
    _streetCtrl       = TextEditingController();
    _areaCtrl         = TextEditingController();
    _landmarkCtrl     = TextEditingController();
    _cityCtrl         = TextEditingController();
    _stateCtrl        = TextEditingController();
    _pincodeCtrl      = TextEditingController();
    _instructionsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _houseCtrl, _buildingCtrl, _streetCtrl, _areaCtrl,
      _landmarkCtrl, _cityCtrl, _stateCtrl, _pincodeCtrl, _instructionsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Decide phase based on addresses data ───────────────────────────────────

  void _resolvePhase(List<AddressModel> addresses) {
    if (_phase == _Phase.form) return; // user is already filling form — don't override
    if (addresses.isEmpty) {
      _hadAddresses = false;
      setState(() => _phase = _Phase.form);
    } else {
      _hadAddresses = true;
      setState(() => _phase = _Phase.list);
    }
  }

  // ── Switch to form (add or edit) ───────────────────────────────────────────

  void _openForm({AddressModel? existing}) {
    _editingAddress = existing;
    _houseCtrl.text        = existing?.houseNo      ?? '';
    _buildingCtrl.text     = existing?.buildingName ?? '';
    _streetCtrl.text       = existing?.street       ?? '';
    _areaCtrl.text         = existing?.area         ?? '';
    _landmarkCtrl.text     = existing?.landmark     ?? '';
    _cityCtrl.text         = existing?.city         ?? 'Bengaluru';
    _stateCtrl.text        = existing?.state        ?? 'Karnataka';
    _pincodeCtrl.text      = existing?.pincode      ?? '';
    _instructionsCtrl.text = existing?.instructions ?? '';
    _type      = existing?.type      ?? 'Home';
    _isDefault = existing?.isDefault ?? false;
    _lat       = existing?.lat;
    _lng       = existing?.lng;
    _areaAutoFilled    = false;
    _cityAutoFilled    = false;
    _stateAutoFilled   = false;
    _pincodeAutoFilled = false;
    setState(() => _phase = _Phase.form);
  }

  // ── Use current GPS location ───────────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingGps = true);

    // Permission check/request + services-off/denied-forever handling (with
    // Settings deep-links) all live in the shared service now. The manual
    // fields below are always visible, so a null result just leaves them for
    // the user to fill in — never a dead end.
    final pos = await LocationPermissionService.getCurrentPosition(context);
    if (pos == null) {
      if (mounted) setState(() => _isFetchingGps = false);
      return;
    }

    _lat = pos.latitude;
    _lng = pos.longitude;

    // ── Step 2: reverse geocode. On Flutter Web the `geocoding` package has
    // no platform implementation (see GeocodingService), so this can fail
    // even though the GPS fix above succeeded — report it distinctly and
    // keep the coordinates we already have.
    try {
      final marks = await GeocodingService.instance
          .placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty && mounted) {
        final p = marks.first;

        // Area: subLocality → neighbourhood → subAdministrativeArea
        final area = (p.subLocality?.isNotEmpty == true)
            ? p.subLocality!
            : (p.subAdministrativeArea ?? '');
        final city    = p.locality            ?? '';
        final state   = p.administrativeArea  ?? '';
        final pincode = p.postalCode          ?? '';

        setState(() {
          if (area.isNotEmpty) {
            _areaCtrl.text   = area;
            _areaAutoFilled  = true;
          }
          if (city.isNotEmpty) {
            _cityCtrl.text   = city;
            _cityAutoFilled  = true;
          }
          if (state.isNotEmpty) {
            _stateCtrl.text  = state;
            _stateAutoFilled = true;
          }
          if (pincode.isNotEmpty) {
            _pincodeCtrl.text   = pincode;
            _pincodeAutoFilled  = true;
          }
        });

        _snack('Location detected — please verify the fields');
      }
    } catch (e, stackTrace) {
      debugPrint('[Location] reverse geocode failed: $e\n$stackTrace');
      _snack(
        'Location found, but we could not auto-fill the address. Please fill it in manually.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isFetchingGps = false);
    }
  }

  // ── Select an address and proceed ─────────────────────────────────────────

  void _selectAndProceed(AddressModel addr) {
    ref.read(selectedAddressProvider.notifier).select(addr);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SchedulingScreen()),
      (r) => r.isFirst,
    );
  }

  // ── Save form ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    // If the user filled the form manually (no GPS used), lat/lng will be null.
    // Geocode from the entered area + city + state so every saved address
    // always carries coordinates — required for serviceability checks and
    // "Drop at Shop" nearby-shop lookups.
    double? resolvedLat = _lat;
    double? resolvedLng = _lng;

    if (resolvedLat == null || resolvedLng == null) {
      final parts = [
        _areaCtrl.text.trim(),
        _cityCtrl.text.trim(),
        _stateCtrl.text.trim(),
      ].where((s) => s.isNotEmpty).toList();

      if (parts.isNotEmpty) {
        try {
          final locations =
              await GeocodingService.instance.locationFromAddress(parts.join(', '));
          if (locations.isNotEmpty) {
            resolvedLat = locations.first.latitude;
            resolvedLng = locations.first.longitude;
          }
        } catch (e, stackTrace) {
          // Geocoding failed — continue without coordinates; the scheduling
          // screen will show an appropriate error when it needs them.
          debugPrint('[Location] forward geocode failed: $e\n$stackTrace');
        }
      }
    }

    final address = AddressModel(
      id:            _editingAddress?.id,
      houseNo:       _houseCtrl.text.trim(),
      buildingName:  _buildingCtrl.text.trim(),
      street:        _streetCtrl.text.trim(),
      area:          _areaCtrl.text.trim(),
      landmark:      _landmarkCtrl.text.trim(),
      city:          _cityCtrl.text.trim(),
      state:         _stateCtrl.text.trim(),
      pincode:       _pincodeCtrl.text.trim(),
      type:          _type,
      instructions:  _instructionsCtrl.text.trim(),
      isDefault:     _isDefault,
      lat:           resolvedLat,
      lng:           resolvedLng,
    );

    try {
      if (_editingAddress?.id != null) {
        await ref.read(addressesProvider.notifier).updateAddress(address);
        _snack('Address updated');
        setState(() => _phase = _Phase.list);
      } else {
        final alreadyExists =
            await ref.read(addressesProvider.notifier).addAddress(address);
        if (alreadyExists) {
          _snack('This address is already saved');
        }
        // Whether new or duplicate, select the address and proceed.
        final saved = ref.read(addressesProvider).value ?? [];
        final latest = saved.isNotEmpty ? saved.last : address;
        _selectAndProceed(latest);
      }
    } catch (e, stackTrace) {
      debugPrint('[Location] save address failed: $e\n$stackTrace');
      _snack('Failed to save address. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteAddress(AddressModel addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address?',
            style: TextStyle(fontWeight: FontWeight.w800, color: _kDark)),
        content: Text(addr.line1.isNotEmpty ? addr.line1 : addr.line2,
            style: const TextStyle(color: _kGrey, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _kGrey, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style:
                    TextStyle(color: _kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && addr.id != null) {
      try {
        await ref.read(addressesProvider.notifier).deleteAddress(addr.id!);
      } catch (e, stackTrace) {
        debugPrint('[Location] delete address failed: $e\n$stackTrace');
        _snack('Failed to delete address', isError: true);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _kRed : _kBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncAddresses = ref.watch(addressesProvider);

    // Resolve phase whenever data arrives (only if not already in form)
    asyncAddresses.whenData((list) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolvePhase(list);
      });
    });

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(asyncAddresses.value ?? []),
      body: asyncAddresses.when(
        loading: () => _phase == _Phase.form
            ? _buildForm()
            : const Center(
                child: CircularProgressIndicator(color: _kBlue)),
        error: (_, __) => _ErrorState(
            onRetry: () => ref.invalidate(addressesProvider)),
        data: (_) {
          switch (_phase) {
            case _Phase.loading:
              return const Center(
                  child: CircularProgressIndicator(color: _kBlue));
            case _Phase.list:
              return _buildList(asyncAddresses.value!);
            case _Phase.form:
              return _buildForm();
          }
        },
      ),
    );
  }

  AppBar _buildAppBar(List<AddressModel> addresses) {
    final bool canGoBack = _phase == _Phase.form && _hadAddresses;
    final title = _phase == _Phase.form
        ? (_editingAddress != null ? 'Edit Address' : 'Add Address')
        : 'Deliver To';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: canGoBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _kDark),
              onPressed: () => setState(() {
                _phase = _Phase.list;
                _editingAddress = null;
              }),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _kDark),
              onPressed: () => Navigator.pop(context),
            ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _kDark,
        ),
      ),
      centerTitle: true,
    );
  }

  // ── List view ──────────────────────────────────────────────────────────────

  Widget _buildList(List<AddressModel> addresses) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Section label
        const _Label('SAVED ADDRESSES'),
        const SizedBox(height: 10),

        ...addresses.map((addr) => _AddressCard(
              address: addr,
              onSelect: () => _selectAndProceed(addr),
              onEdit: () => _openForm(existing: addr),
              onDelete: () => _deleteAddress(addr),
            )),

        const SizedBox(height: 8),

        // Add new address button
        _OutlineAction(
          icon: Icons.add_circle_outline_rounded,
          label: 'Add New Address',
          onTap: () => _openForm(),
        ),
      ],
    );
  }

  // ── Add / Edit form ────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Use Current Location ─────────────────────────────────────
            _LocationBtn(
              isLoading: _isFetchingGps,
              onTap: _isFetchingGps ? null : _useCurrentLocation,
            ),
            const SizedBox(height: 20),

            // ── OR divider ───────────────────────────────────────────────
            const _OrDivider(),
            const SizedBox(height: 20),

            // ── Manual fields hint ───────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_note_rounded,
                      size: 16, color: Color(0xFFEA580C)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fill in your house, building & street manually.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── House / Flat (manual) ────────────────────────────────────
            _FieldSection(
              label: 'HOUSE / FLAT NO *',
              child: _FormField(
                controller: _houseCtrl,
                hint: 'e.g. 302, A Wing',
                icon: Icons.door_front_door_outlined,
                validator: _required,
              ),
            ),

            // ── Building (manual) ─────────────────────────────────────────
            _FieldSection(
              label: 'BUILDING / SOCIETY',
              child: _FormField(
                controller: _buildingCtrl,
                hint: 'e.g. Sunshine Apartments',
                icon: Icons.apartment_rounded,
              ),
            ),

            // ── Street (manual) ──────────────────────────────────────────
            _FieldSection(
              label: 'STREET / ROAD *',
              child: _FormField(
                controller: _streetCtrl,
                hint: 'e.g. MG Road, Lane 4',
                icon: Icons.fork_right_rounded,
                validator: _required,
              ),
            ),

            // ── Area (auto-fill, editable) ───────────────────────────────
            _FieldSection(
              label: 'AREA / LOCALITY *',
              autoFilled: _areaAutoFilled,
              child: _FormField(
                controller: _areaCtrl,
                hint: 'e.g. Satellite, Vastrapur',
                icon: Icons.location_city_rounded,
                validator: _required,
              ),
            ),

            // ── Landmark (manual, optional) ──────────────────────────────
            _FieldSection(
              label: 'LANDMARK (OPTIONAL)',
              child: _FormField(
                controller: _landmarkCtrl,
                hint: 'e.g. Near Iscon Circle',
                icon: Icons.flag_rounded,
              ),
            ),

            // ── City + State (auto-fill, editable) ───────────────────────
            _FieldSection(
              label: 'CITY & STATE *',
              autoFilled: _cityAutoFilled || _stateAutoFilled,
              child: Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _cityCtrl,
                      hint: 'City',
                      icon: Icons.location_on_rounded,
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormField(
                      controller: _stateCtrl,
                      hint: 'State',
                      icon: Icons.map_rounded,
                      validator: _required,
                    ),
                  ),
                ],
              ),
            ),

            // ── Pincode (auto-fill, editable) ────────────────────────────
            _FieldSection(
              label: 'PINCODE *',
              autoFilled: _pincodeAutoFilled,
              child: _FormField(
                controller: _pincodeCtrl,
                hint: '6-digit pincode',
                icon: Icons.pin_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'Required';
                  if ((v ?? '').trim().length != 6) return 'Must be 6 digits';
                  return null;
                },
              ),
            ),

            // ── Delivery instructions ─────────────────────────────────────
            _FieldSection(
              label: 'DELIVERY INSTRUCTIONS (OPTIONAL)',
              child: _FormField(
                controller: _instructionsCtrl,
                hint: 'e.g. Leave at door, ring bell twice',
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
            ),

            // ── Address type ──────────────────────────────────────────────
            const _Label('ADDRESS TYPE'),
            const SizedBox(height: 8),
            Row(
              children: _types
                  .map((t) => _TypeChip(
                        label: t,
                        icon: _typeConfig[t]!.icon,
                        selected: _type == t,
                        onTap: () => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // ── Set as default ────────────────────────────────────────────
            _DefaultToggle(
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 28),

            // ── Save button ───────────────────────────────────────────────
            _SaveButton(
              isLoading: _isSaving,
              isEditing: _editingAddress != null,
              onTap: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'Required' : null;
}

// ═════════════════════════════════════════════════════════════════════════════
// ADDRESS CARD
// ═════════════════════════════════════════════════════════════════════════════

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final AddressModel address;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[address.type] ?? _typeConfig['Other']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: address.isDefault
              ? _kBlue.withAlpha(100)
              : const Color(0xFFE9EDFA),
          width: address.isDefault ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cfg.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cfg.icon, size: 13, color: cfg.color),
                      const SizedBox(width: 4),
                      Text(address.type,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cfg.color)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kGreenBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 11, color: _kGreen),
                        SizedBox(width: 3),
                        Text('Default',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kGreen)),
                      ],
                    ),
                  ),
                const Spacer(),
                _IconBtn(
                    icon: Icons.edit_rounded,
                    color: _kBlue,
                    onTap: onEdit),
                const SizedBox(width: 4),
                _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: _kRed,
                    onTap: onDelete),
              ],
            ),
          ),

          // ── Address text ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.line1.isNotEmpty)
                  Text(address.line1,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kDark)),
                const SizedBox(height: 3),
                Text(address.line2,
                    style: const TextStyle(
                        fontSize: 13,
                        color: _kGrey,
                        fontWeight: FontWeight.w500,
                        height: 1.4)),
                if (address.instructions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 12, color: _kGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address.instructions,
                          style: const TextStyle(
                              fontSize: 12,
                              color: _kGrey,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // ── Select button ─────────────────────────────────────────────
          GestureDetector(
            onTap: onSelect,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: _kBlue),
                  SizedBox(width: 6),
                  Text('Deliver Here',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kBlue)),
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
// FORM SUB-WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _LocationBtn extends StatelessWidget {
  const _LocationBtn({required this.isLoading, this.onTap});
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onTap == null
                ? [_kBlue.withAlpha(140), _kBlueDk.withAlpha(140)]
                : [_kBlue, _kBlueDk],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: _kBlue.withAlpha(70),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.my_location_rounded,
                      size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Use Current Location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR FILL MANUALLY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade400,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      ],
    );
  }
}

class _FieldSection extends StatelessWidget {
  const _FieldSection({
    required this.label,
    required this.child,
    this.autoFilled = false,
  });

  final String label;
  final Widget child;
  final bool autoFilled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _kGrey,
                  letterSpacing: 0.5,
                ),
              ),
              if (autoFilled) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kGreenBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'GPS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _kGreen,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _kDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, size: 18, color: _kBlue),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontSize: 11,
          color: Color(0xFFDC2626),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _kBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kBlue : const Color(0xFFE5E7EB),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20,
                  color: selected ? Colors.white : _kGrey),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _kGrey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultToggle extends StatelessWidget {
  const _DefaultToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDFA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded,
              size: 18, color: Color(0xFFEAB308)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set as default address',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kDark)),
                SizedBox(height: 2),
                Text('Used automatically during checkout',
                    style: TextStyle(
                        fontSize: 12,
                        color: _kGrey,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: _kBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isLoading,
    required this.isEditing,
    this.onTap,
  });

  final bool isLoading;
  final bool isEditing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: onTap == null ? _kBlue.withAlpha(160) : _kBlue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: _kBlue.withAlpha(80),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Update Address' : 'Save & Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MISC SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: _kGrey,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction(
      {required this.icon,
      required this.label,
      required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9EDFA)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: _kBlue),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kBlue)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: _kGrey),
          const SizedBox(height: 12),
          const Text('Failed to load addresses',
              style: TextStyle(color: _kGrey, fontSize: 14)),
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
    );
  }
}
