import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/places_service.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue = Color(0xFF1A23CC);
const _kBg   = Color(0xFFF5F6FA);
const _kDark = Color(0xFF0A1645);
const _kGrey = Color(0xFF6B7280);

/// Shared "search for an address" bottom sheet — the manual fallback for
/// every screen that also offers a GPS "Use current location" button.
/// Used by both the full-screen location picker and the delivery map picker
/// so a denied/unavailable GPS permission never leaves the user stuck.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => LocationSearchSheet(
///     onPlaceSelected: (latLng, address) { ... },
///   ),
/// );
/// ```
class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({
    super.key,
    required this.onPlaceSelected,
    this.hint = 'Search area, street or landmark',
  });

  final void Function(LatLng latLng, String address) onPlaceSelected;
  final String hint;

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<PlacePrediction> _predictions = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loading = true);
      final results = await PlacesService.instance.autocomplete(val);
      if (mounted) setState(() { _predictions = results; _loading = false; });
    });
  }

  Future<void> _onTap(PlacePrediction p) async {
    final detail = await PlacesService.instance.getPlaceDetail(p.placeId);
    if (detail != null && mounted) {
      Navigator.pop(context);
      widget.onPlaceSelected(detail.latLng, p.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final viewInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(bottom: viewInset + bottomPad),
      child: Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onChanged: _onChanged,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _kDark,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: _kBlue, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: _kGrey),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _predictions = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Results
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2))
                : _predictions.isEmpty
                    ? _ctrl.text.isEmpty
                        ? const _SearchEmptyHint()
                        : const Center(
                            child: Text(
                              'No results found',
                              style: TextStyle(color: _kGrey, fontSize: 14),
                            ),
                          )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (_, i) {
                          final p = _predictions[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF0FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_rounded,
                                  size: 18, color: _kBlue),
                            ),
                            title: Text(
                              p.mainText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kDark,
                              ),
                            ),
                            subtitle: p.secondaryText.isNotEmpty
                                ? Text(
                                    p.secondaryText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _kGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : null,
                            onTap: () => _onTap(p),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyHint extends StatelessWidget {
  const _SearchEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Search for your area,\nstreet or landmark',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _kGrey,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
