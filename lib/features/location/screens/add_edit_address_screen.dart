import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue  = Color(0xFF1A23CC);
const _kBg    = Color(0xFFF5F6FA);
const _kDark  = Color(0xFF0A1645);
const _kGrey  = Color(0xFF6B7280);

// ── Address types ─────────────────────────────────────────────────────────────
const _types = ['Home', 'Work', 'Other'];
const _typeIcons = {
  'Home':  Icons.home_rounded,
  'Work':  Icons.work_rounded,
  'Other': Icons.place_rounded,
};

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AddEditAddressScreen extends ConsumerStatefulWidget {
  const AddEditAddressScreen({super.key, this.existing, this.autoFill});

  /// Non-null when editing a saved address.
  final AddressModel? existing;

  /// Non-null when adding from the map flow (pre-fills area/city/state/pin).
  final AddressModel? autoFill;

  @override
  ConsumerState<AddEditAddressScreen> createState() =>
      _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends ConsumerState<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Controllers
  late final TextEditingController _houseCtrl;
  late final TextEditingController _buildingCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _landmarkCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _instructionsCtrl;

  String _type = 'Home';
  bool _isDefault = false;

  double? _lat;
  double? _lng;
  bool _isFetchingGps = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final src = widget.existing ?? widget.autoFill;

    _houseCtrl       = TextEditingController(text: src?.houseNo ?? '');
    _buildingCtrl    = TextEditingController(text: src?.buildingName ?? '');
    _streetCtrl      = TextEditingController(text: src?.street ?? '');
    _areaCtrl        = TextEditingController(text: src?.area ?? '');
    _landmarkCtrl    = TextEditingController(text: src?.landmark ?? '');
    _cityCtrl        = TextEditingController(text: src?.city ?? '');
    _stateCtrl       = TextEditingController(text: src?.state ?? '');
    _pincodeCtrl     = TextEditingController(text: src?.pincode ?? '');
    _instructionsCtrl = TextEditingController(text: src?.instructions ?? '');

    _type      = widget.existing?.type ?? 'Home';
    _isDefault = widget.existing?.isDefault ?? false;
    _lat       = src?.lat;
    _lng       = src?.lng;
  }

  // ── Use current GPS location ───────────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingGps = true);

    final pos = await LocationPermissionService.getCurrentPosition(context);
    if (pos == null) {
      if (mounted) setState(() => _isFetchingGps = false);
      return;
    }

    _lat = pos.latitude;
    _lng = pos.longitude;

    try {
      final marks = await GeocodingService.instance
          .placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty && mounted) {
        final p = marks.first;

        final area = (p.subLocality?.isNotEmpty == true)
            ? p.subLocality!
            : (p.subAdministrativeArea ?? '');
        final city    = p.locality            ?? '';
        final state   = p.administrativeArea  ?? '';
        final pincode = p.postalCode          ?? '';

        setState(() {
          if (area.isNotEmpty) _areaCtrl.text = area;
          if (city.isNotEmpty) _cityCtrl.text = city;
          if (state.isNotEmpty) _stateCtrl.text = state;
          if (pincode.isNotEmpty) _pincodeCtrl.text = pincode;
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

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFDC2626) : _kBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    for (final c in [
      _houseCtrl, _buildingCtrl, _streetCtrl, _areaCtrl,
      _landmarkCtrl, _cityCtrl, _stateCtrl, _pincodeCtrl,
      _instructionsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    // If the user filled the form manually (no GPS used), lat/lng will be
    // null. Geocode from the entered area + city + state so every saved
    // address always carries coordinates — required for serviceability
    // checks and "Drop at Shop" nearby-shop lookups.
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
          debugPrint('[Location] forward geocode failed: $e\n$stackTrace');
        }
      }
    }

    final address = AddressModel(
      id: widget.existing?.id,
      houseNo: _houseCtrl.text.trim(),
      buildingName: _buildingCtrl.text.trim(),
      street: _streetCtrl.text.trim(),
      area: _areaCtrl.text.trim(),
      landmark: _landmarkCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      type: _type,
      instructions: _instructionsCtrl.text.trim(),
      isDefault: _isDefault,
      lat: resolvedLat,
      lng: resolvedLng,
    );

    try {
      if (_isEditing) {
        await ref.read(addressesProvider.notifier).updateAddress(address);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Address updated successfully'),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
          Navigator.pop(context);
        }
      } else {
        final alreadyExists =
            await ref.read(addressesProvider.notifier).addAddress(address);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(alreadyExists
                ? 'This address is already saved'
                : 'Address saved successfully'),
            backgroundColor: alreadyExists
                ? const Color(0xFFF59E0B)
                : const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Address' : 'Add Address',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _kDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Use Current Location ───────────────────────────────────
              _LocationBtn(
                isLoading: _isFetchingGps,
                onTap: _isFetchingGps ? null : _useCurrentLocation,
              ),
              const SizedBox(height: 16),
              const _OrDivider(),
              const SizedBox(height: 16),

              // ── Address type selector ──────────────────────────────────
              _Section(
                label: 'ADDRESS TYPE',
                child: Row(
                  children: _types.map((t) => _TypeChip(
                    label: t,
                    icon: _typeIcons[t]!,
                    selected: _type == t,
                    onTap: () => setState(() => _type = t),
                  )).toList(),
                ),
              ),

              // ── House / Flat ───────────────────────────────────────────
              _Section(
                label: 'HOUSE / FLAT NUMBER',
                child: _Field(
                  controller: _houseCtrl,
                  hint: 'e.g. 302, A Wing',
                  icon: Icons.door_front_door_outlined,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),

              // ── Building ───────────────────────────────────────────────
              _Section(
                label: 'BUILDING / SOCIETY NAME',
                child: _Field(
                  controller: _buildingCtrl,
                  hint: 'e.g. Sunshine Apartments',
                  icon: Icons.apartment_rounded,
                ),
              ),

              // ── Street ────────────────────────────────────────────────
              _Section(
                label: 'STREET / ROAD',
                child: _Field(
                  controller: _streetCtrl,
                  hint: 'e.g. MG Road, Lane 4',
                  icon: Icons.fork_right_rounded,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),

              // ── Area / Locality ────────────────────────────────────────
              _Section(
                label: 'AREA / LOCALITY',
                child: _Field(
                  controller: _areaCtrl,
                  hint: 'e.g. Satellite, Vastrapur',
                  icon: Icons.location_city_rounded,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),

              // ── Landmark ──────────────────────────────────────────────
              _Section(
                label: 'LANDMARK (OPTIONAL)',
                child: _Field(
                  controller: _landmarkCtrl,
                  hint: 'e.g. Near Iscon Circle',
                  icon: Icons.flag_rounded,
                ),
              ),

              // ── City + State ───────────────────────────────────────────
              _Section(
                label: 'CITY & STATE',
                child: Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _cityCtrl,
                        hint: 'City',
                        icon: Icons.location_on_rounded,
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        controller: _stateCtrl,
                        hint: 'State',
                        icon: Icons.map_rounded,
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Pincode ───────────────────────────────────────────────
              _Section(
                label: 'PINCODE',
                child: _Field(
                  controller: _pincodeCtrl,
                  hint: '6-digit pincode',
                  icon: Icons.pin_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Required';
                    if (t.length != 6) return 'Must be 6 digits';
                    return null;
                  },
                ),
              ),

              // ── Delivery instructions ──────────────────────────────────
              _Section(
                label: 'DELIVERY INSTRUCTIONS (OPTIONAL)',
                child: _Field(
                  controller: _instructionsCtrl,
                  hint: 'e.g. Leave at door, call before delivery',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
              ),

              const SizedBox(height: 4),

              // ── Set as default ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
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
                          Text(
                            'Set as default address',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Used automatically during checkout',
                            style: TextStyle(
                              fontSize: 12,
                              color: _kGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isDefault,
                      activeThumbColor: _kBlue,
                      onChanged: (v) => setState(() => _isDefault = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Save button ───────────────────────────────────────────
              GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _saving
                        ? _kBlue.withAlpha(160)
                        : _kBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _saving
                        ? []
                        : [
                            BoxShadow(
                              color: _kBlue.withAlpha(80),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: _saving
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _isEditing
                                  ? 'Update Address'
                                  : 'Save Address',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FORM WIDGETS
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
                ? [_kBlue.withAlpha(140), _kBlue.withAlpha(140)]
                : [_kBlue, const Color(0xFF0F1899)],
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
                  Icon(Icons.my_location_rounded, size: 18, color: Colors.white),
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

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

// ── Address type chip ─────────────────────────────────────────────────────────

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
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : _kGrey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _kGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
