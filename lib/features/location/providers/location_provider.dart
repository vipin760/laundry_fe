import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../models/serviceability_model.dart';

// ═════════════════════════════════════════════════════════════════════════════
// STATE
// ═════════════════════════════════════════════════════════════════════════════

class LocationState {
  const LocationState({
    this.latLng,
    this.rawAddress,
    this.serviceability,
    this.isChecking = false,
    this.serviceabilityError,
  });

  final LatLng? latLng;
  final String? rawAddress;
  final ServiceabilityResult? serviceability;
  final bool isChecking;
  final String? serviceabilityError;

  bool get hasLocation => latLng != null;
  bool get isServiceable => serviceability?.isServiceable == true;
  bool get hasChecked => serviceability != null;

  LocationState copyWith({
    LatLng? latLng,
    String? rawAddress,
    ServiceabilityResult? serviceability,
    bool? isChecking,
    String? serviceabilityError,
    bool clearServiceability = false,
    bool clearError = false,
  }) {
    return LocationState(
      latLng: latLng ?? this.latLng,
      rawAddress: rawAddress ?? this.rawAddress,
      serviceability: clearServiceability
          ? null
          : (serviceability ?? this.serviceability),
      isChecking: isChecking ?? this.isChecking,
      serviceabilityError: clearError
          ? null
          : (serviceabilityError ?? this.serviceabilityError),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// NOTIFIER
// ═════════════════════════════════════════════════════════════════════════════

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  /// Update selected pin position + address label.
  void setLocation(LatLng latLng, String address) {
    state = state.copyWith(
      latLng: latLng,
      rawAddress: address,
      clearServiceability: true,
      clearError: true,
    );
  }

  /// Call backend to check if the selected coordinates are in a delivery zone.
  Future<void> checkServiceability() async {
    final pos = state.latLng;
    if (pos == null) return;

    state = state.copyWith(
      isChecking: true,
      clearServiceability: true,
      clearError: true,
    );

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Correct endpoint: GET /locations/serviceability with lat/lng/date as
      // query params. Returns null body when no shop is in range.
      final response = await ApiClient.instance.get(
        '/locations/serviceability',
        queryParameters: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'date': today,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      // Backend returns the nearest eligible shop object, or null/empty when
      // no shop covers the location.
      final isServiceable = data != null && data['shop'] != null;

      final result = ServiceabilityResult(
        isServiceable: isServiceable,
        estimatedTime: data?['estimatedPickupTime'] as String?,
        // Use the shop's city as a human-readable zone label.
        zone: (data?['shop'] as Map<String, dynamic>?)?['city'] as String?,
        message: isServiceable
            ? null
            : 'No laundry service is available in your area yet.',
      );

      state = state.copyWith(
        serviceability: result,
        isChecking: false,
      );
    } catch (_) {
      // Network / server error — assume serviceable so the flow is not blocked.
      state = state.copyWith(
        serviceability: ServiceabilityResult.assumed,
        isChecking: false,
      );
    }
  }

  void resetServiceability() {
    state = state.copyWith(clearServiceability: true, clearError: true);
  }

  void reset() => state = const LocationState();
}

// ═════════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═════════════════════════════════════════════════════════════════════════════

final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);
