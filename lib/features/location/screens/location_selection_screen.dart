import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../models/address_model.dart';
import '../providers/location_provider.dart';
import '../widgets/location_search_sheet.dart';
import 'saved_addresses_screen.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1A23CC);
const _kBlueDk   = Color(0xFF0F1899);
const _kDark     = Color(0xFF0A1645);
const _kGrey     = Color(0xFF6B7280);
const _kGreen    = Color(0xFF15803D);
const _kGreenBg  = Color(0xFFDCF5E8);
const _kRed      = Color(0xFFDC2626);
const _kRedBg    = Color(0xFFFEE2E2);

// Default centre — Satellite, Ahmedabad
const _kDefaultLatLng = LatLng(23.0285, 72.5094);

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

enum _Phase { locating, confirming, serviceable, unserviceable }

class LocationSelectionScreen extends ConsumerStatefulWidget {
  const LocationSelectionScreen({super.key, this.initialLatLng});
  final LatLng? initialLatLng;

  @override
  ConsumerState<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState
    extends ConsumerState<LocationSelectionScreen>
    with TickerProviderStateMixin {
  // Map
  GoogleMapController? _mapCtrl;
  late LatLng _center;
  bool _isMoving = false;

  // Address
  String _address = 'Move map to set your location';
  bool _isGeocoding = false;
  Timer? _geocodeDebounce;

  // Phase
  _Phase _phase = _Phase.locating;

  // Pin bounce animation
  late final AnimationController _pinAnim;
  late final Animation<double> _pinLift;

  @override
  void initState() {
    super.initState();
    _center = widget.initialLatLng ?? _kDefaultLatLng;

    _pinAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pinLift = Tween<double>(begin: 0, end: -14).animate(
      CurvedAnimation(parent: _pinAnim, curve: Curves.easeOut),
    );

    _geocodeWithDelay(_center, immediate: true);
  }

  @override
  void dispose() {
    _pinAnim.dispose();
    _geocodeDebounce?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Geocoding ──────────────────────────────────────────────────────────────

  void _geocodeWithDelay(LatLng pos, {bool immediate = false}) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 600),
      () => _reverseGeocode(pos),
    );
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final marks = await GeocodingService.instance
          .placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty && mounted) {
        final p = marks.first;
        final parts = <String>[
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
          if ((p.postalCode ?? '').isNotEmpty) p.postalCode!,
        ];
        setState(() {
          _address = parts.isNotEmpty ? parts.join(', ') : 'Selected location';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[Location] reverse geocode failed: $e\n$stackTrace');
      if (mounted) setState(() => _address = 'Unable to fetch address');
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  // ── Map callbacks ──────────────────────────────────────────────────────────

  void _onCameraMove(CameraPosition pos) {
    _center = pos.target;
    if (!_isMoving) {
      setState(() => _isMoving = true);
      _pinAnim.forward();
      // Reset to locating phase when user drags
      if (_phase != _Phase.locating) {
        setState(() => _phase = _Phase.locating);
      }
    }
  }

  void _onCameraIdle() {
    setState(() => _isMoving = false);
    _pinAnim.reverse();
    _geocodeWithDelay(_center);
  }

  // ── GPS ────────────────────────────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    // Handles permission checks/requests, "denied forever" → Settings, and
    // "services off" → Settings, all with a friendly dialog. Falls back to
    // null (and the search bar stays right there) rather than dead-ending.
    final pos = await LocationPermissionService.getCurrentPosition(context);
    if (pos == null || !mounted) return;

    _mapCtrl?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 16),
      ),
    );
  }

  // ── Confirm → serviceability check ────────────────────────────────────────

  Future<void> _confirmLocation() async {
    ref.read(locationProvider.notifier).setLocation(_center, _address);
    setState(() => _phase = _Phase.confirming);

    await ref.read(locationProvider.notifier).checkServiceability();

    if (!mounted) return;
    final result = ref.read(locationProvider).serviceability;
    setState(() {
      _phase = (result?.isServiceable == true)
          ? _Phase.serviceable
          : _Phase.unserviceable;
    });
  }

  // ── Open search sheet ──────────────────────────────────────────────────────

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSearchSheet(
        onPlaceSelected: (latLng, address) {
          _mapCtrl?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 16),
            ),
          );
          setState(() {
            _center = latLng;
            _address = address;
            _phase = _Phase.locating;
          });
        },
      ),
    );
  }

  // ── Navigate to saved addresses ────────────────────────────────────────────

  void _proceedToAddressSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SavedAddressesScreen(
          autoFill: AddressModel(
            area: _extractArea(),
            city: _extractCity(),
            state: _extractState(),
            pincode: _extractPincode(),
            lat: _center.latitude,
            lng: _center.longitude,
          ),
        ),
      ),
    );
  }

  // Simple extraction helpers from reverse-geocoded string
  String _extractArea() {
    final parts = _address.split(', ');
    return parts.isNotEmpty ? parts[0] : '';
  }

  String _extractCity() {
    final parts = _address.split(', ');
    return parts.length > 1 ? parts[1] : '';
  }

  String _extractState() {
    final parts = _address.split(', ');
    return parts.length > 2 ? parts[2] : '';
  }

  String _extractPincode() {
    final match = RegExp(r'\b\d{6}\b').firstMatch(_address);
    return match?.group(0) ?? '';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad    = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _center, zoom: 16),
            onMapCreated: (c) => _mapCtrl = c,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Floating pin ───────────────────────────────────────────────
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _pinLift,
                builder: (_, _) => Transform.translate(
                  offset: Offset(0, _pinLift.value - 29),
                  child: _MapPin(lifted: _isMoving),
                ),
              ),
            ),
          ),

          // ── Top bar ────────────────────────────────────────────────────
          Positioned(
            top: topPad + 10,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _IconCircle(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _openSearch,
                    child: _SearchBar(hint: 'Search area, street or landmark'),
                  ),
                ),
              ],
            ),
          ),

          // ── My-location FAB ────────────────────────────────────────────
          Positioned(
            bottom: _bottomPanelHeight(bottomPad) + 16,
            right: 16,
            child: _IconCircle(
              icon: Icons.my_location_rounded,
              iconColor: _kBlue,
              onTap: _goToMyLocation,
            ),
          ),

          // ── Bottom panel ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              phase: _phase,
              address: _address,
              isGeocoding: _isGeocoding,
              serviceability: ref.watch(locationProvider).serviceability,
              bottomPad: bottomPad,
              onConfirm: _confirmLocation,
              onTryAgain: () => setState(() => _phase = _Phase.locating),
              onProceed: _proceedToAddressSelection,
            ),
          ),
        ],
      ),
    );
  }

  double _bottomPanelHeight(double bottomPad) {
    switch (_phase) {
      case _Phase.locating:
        return 170 + bottomPad;
      case _Phase.confirming:
        return 120 + bottomPad;
      case _Phase.serviceable:
        return 210 + bottomPad;
      case _Phase.unserviceable:
        return 190 + bottomPad;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM PANEL
// ═════════════════════════════════════════════════════════════════════════════

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.phase,
    required this.address,
    required this.isGeocoding,
    required this.serviceability,
    required this.bottomPad,
    required this.onConfirm,
    required this.onTryAgain,
    required this.onProceed,
  });

  final _Phase phase;
  final String address;
  final bool isGeocoding;
  final dynamic serviceability;
  final double bottomPad;
  final VoidCallback onConfirm;
  final VoidCallback onTryAgain;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _phaseContent(),
          ),
        ],
      ),
    );
  }

  Widget _phaseContent() {
    switch (phase) {
      case _Phase.locating:
        return _LocatingContent(
          key: const ValueKey('locating'),
          address: address,
          isGeocoding: isGeocoding,
          onConfirm: onConfirm,
        );
      case _Phase.confirming:
        return const _ConfirmingContent(key: ValueKey('confirming'));
      case _Phase.serviceable:
        return _ServiceableContent(
          key: const ValueKey('serviceable'),
          eta: serviceability?.estimatedTime ?? '30 – 60 mins',
          zone: serviceability?.zone ?? 'Zone A',
          onProceed: onProceed,
        );
      case _Phase.unserviceable:
        return _UnserviceableContent(
          key: const ValueKey('unserviceable'),
          message: serviceability?.message ??
              'Sorry, we don\'t deliver to this area yet.',
          onTryAgain: onTryAgain,
        );
    }
  }
}

// ── Locating phase ────────────────────────────────────────────────────────────

class _LocatingContent extends StatelessWidget {
  const _LocatingContent({
    super.key,
    required this.address,
    required this.isGeocoding,
    required this.onConfirm,
  });

  final String address;
  final bool isGeocoding;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DELIVER HERE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _kGrey,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on_rounded,
                  size: 18, color: _kBlue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isGeocoding
                  ? const _AddressShimmer()
                  : Text(
                      address,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                        height: 1.45,
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PrimaryBtn(
          label: 'Confirm Location',
          icon: Icons.check_circle_outline_rounded,
          onTap: isGeocoding ? null : onConfirm,
          disabled: isGeocoding,
        ),
      ],
    );
  }
}

// ── Confirming phase ──────────────────────────────────────────────────────────

class _ConfirmingContent extends StatelessWidget {
  const _ConfirmingContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 8),
        CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5),
        SizedBox(height: 14),
        Text(
          'Checking serviceability…',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kGrey,
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }
}

// ── Serviceable phase ─────────────────────────────────────────────────────────

class _ServiceableContent extends StatelessWidget {
  const _ServiceableContent({
    super.key,
    required this.eta,
    required this.zone,
    required this.onProceed,
  });

  final String eta;
  final String zone;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _kGreenBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: _kGreen),
              SizedBox(width: 6),
              Text(
                'We deliver here! 🎉',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _InfoChip(
              icon: Icons.electric_bolt_rounded,
              label: eta,
              color: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFEA580C),
              textColor: const Color(0xFFEA580C),
            ),
            const SizedBox(width: 10),
            _InfoChip(
              icon: Icons.place_rounded,
              label: zone,
              color: const Color(0xFFEEF0FF),
              iconColor: _kBlue,
              textColor: _kBlue,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PrimaryBtn(
          label: 'Choose Delivery Address',
          icon: Icons.arrow_forward_rounded,
          onTap: onProceed,
        ),
      ],
    );
  }
}

// ── Unserviceable phase ───────────────────────────────────────────────────────

class _UnserviceableContent extends StatelessWidget {
  const _UnserviceableContent({
    super.key,
    required this.message,
    required this.onTryAgain,
  });

  final String message;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kRedBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.cancel_rounded, size: 22, color: _kRed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Not deliverable here',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kRed,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF991B1B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OutlineBtn(
          label: 'Try Another Location',
          icon: Icons.map_rounded,
          onTap: onTryAgain,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── Animated map pin ──────────────────────────────────────────────────────────

class _MapPin extends StatelessWidget {
  const _MapPin({this.lifted = false});
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Head
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBlue, _kBlueDk],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: _kBlue.withAlpha(lifted ? 100 : 60),
                blurRadius: lifted ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_laundry_service_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        // Stem
        Container(
          width: 2.5,
          height: 18,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kBlue, _kBlueDk],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Tip
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: _kBlueDk,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 1),
        // Ground shadow
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: lifted ? 8 : 14,
          height: lifted ? 4 : 6,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(lifted ? 28 : 55),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}

// ── Search bar (tappable) ─────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: _kBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Circle icon button ────────────────────────────────────────────────────────

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.onTap,
    this.iconColor = const Color(0xFF0A1645),
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1C000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

// ── Info chip (ETA, Zone) ─────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Address shimmer ───────────────────────────────────────────────────────────

class _AddressShimmer extends StatelessWidget {
  const _AddressShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(double.infinity),
        const SizedBox(height: 6),
        _bar(200),
      ],
    );
  }

  Widget _bar(double width) => Container(
        height: 13,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.icon,
    this.onTap,
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled
                ? [_kBlue.withAlpha(130), _kBlueDk.withAlpha(130)]
                : [_kBlue, _kBlueDk],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: _kBlue.withAlpha(70),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBlue, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: _kBlue),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
