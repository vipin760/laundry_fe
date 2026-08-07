import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../../location/widgets/location_search_sheet.dart';

// ── Brand colour ──────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF1A23CC);
const _kBlueDk = Color(0xFF0F1899);

// Default pin — Satellite, Ahmedabad
const _kDefaultLatLng = LatLng(23.0285, 72.5094);

// ── Result model ──────────────────────────────────────────────────────────────

class MapPickerResult {
  const MapPickerResult({required this.latLng, required this.address});
  final LatLng latLng;
  final String address;
}

// ═════════════════════════════════════════════════════════════════════════════
// MAP PICKER SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initialLatLng});

  /// Pre-centre the map here (e.g. GPS position or previously saved location).
  final LatLng? initialLatLng;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  late LatLng _centerLatLng;
  String _address = 'Move the map to pin your location';
  bool _isGeocoding = false;
  bool _isMoving    = false;

  @override
  void initState() {
    super.initState();
    _centerLatLng = widget.initialLatLng ?? _kDefaultLatLng;
    _reverseGeocode(_centerLatLng);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Reverse-geocode a LatLng into a human-readable address ─────────────────
  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final placemarks = await GeocodingService.instance.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.name ?? '').isNotEmpty &&
              p.name != p.thoroughfare &&
              p.name != p.subLocality)
            p.name!,
          if ((p.thoroughfare ?? '').isNotEmpty) p.thoroughfare!,
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

  // ── Animate map to current GPS position ────────────────────────────────────
  Future<void> _goToMyLocation() async {
    // Handles permission ask/re-ask, "denied forever" → Settings, and
    // "services off" → Settings. On any failure the search bar up top is
    // always right there as the manual fallback.
    final pos = await LocationPermissionService.getCurrentPosition(context);
    if (pos == null || !mounted) return;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 16,
        ),
      ),
    );
  }

  // ── Manual search fallback ──────────────────────────────────────────────
  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSearchSheet(
        onPlaceSelected: (latLng, address) {
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 16),
            ),
          );
          setState(() {
            _centerLatLng = latLng;
            _address = address;
          });
        },
      ),
    );
  }

  void _onConfirm() {
    if (_isGeocoding) return;
    Navigator.pop(
      context,
      MapPickerResult(latLng: _centerLatLng, address: _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad    = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _centerLatLng,
              zoom: 16,
            ),
            onMapCreated: (ctrl) => _mapController = ctrl,
            onCameraMove: (pos) {
              _centerLatLng = pos.target;
              if (!_isMoving) setState(() => _isMoving = true);
            },
            onCameraIdle: () {
              setState(() => _isMoving = false);
              _reverseGeocode(_centerLatLng);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Centered floating pin ───────────────────────────────────────
          // The pin stays fixed; the map moves under it, giving the Zepto
          // / Blinkit feel. The pin lifts slightly while the camera moves.
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shadow under the pin head (appears when lifted)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isMoving ? 0.0 : 1.0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(60),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Pin head + stem (lifts when map is moving)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(
                      0,
                      _isMoving ? -14 : 0,
                      0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Head
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kBlue, _kBlueDk],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: _kBlue.withAlpha(80),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_laundry_service_rounded,
                            size: 16,
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
                        // Tip dot
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _kBlueDk,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Ground shadow dot (shrinks when pin lifts)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isMoving ? 8 : 14,
                    height: _isMoving ? 4 : 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(_isMoving ? 30 : 55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top bar ─────────────────────────────────────────────────────
          Positioned(
            top: topPad + 10,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(22),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              size: 18, color: _kBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _address == 'Move the map to pin your location'
                                  ? 'Search area, street or landmark'
                                  : _address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0A1645),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── My-location FAB ─────────────────────────────────────────────
          Positioned(
            bottom: 160 + bottomPad,
            right: 16,
            child: _CircleButton(
              icon: Icons.my_location_rounded,
              onTap: _goToMyLocation,
              iconColor: _kBlue,
            ),
          ),

          // ── Bottom confirm card ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ConfirmCard(
              address: _address,
              isGeocoding: _isGeocoding,
              onConfirm: _onConfirm,
              bottomPad: bottomPad,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _CircleButton extends StatelessWidget {
  const _CircleButton({
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(28),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.address,
    required this.isGeocoding,
    required this.onConfirm,
    required this.bottomPad,
  });

  final String address;
  final bool isGeocoding;
  final VoidCallback onConfirm;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(22),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Label
          const Text(
            'DELIVERY TO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),

          // Address row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded,
                    size: 20, color: _kBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: isGeocoding
                    ? const _AddressShimmer()
                    : Text(
                        address,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A1645),
                          height: 1.45,
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Confirm button
          GestureDetector(
            onTap: isGeocoding ? null : onConfirm,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isGeocoding
                      ? [_kBlue.withAlpha(160), _kBlueDk.withAlpha(160)]
                      : [_kBlue, _kBlueDk],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isGeocoding
                    ? []
                    : [
                        BoxShadow(
                          color: _kBlue.withAlpha(80),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: isGeocoding
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
                  : const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer placeholder while geocoding ───────────────────────────────────────

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

  Widget _bar(double width) {
    return Container(
      height: 13,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
