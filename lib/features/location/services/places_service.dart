import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Same key used for the Maps SDK. Supply at build time with:
//   flutter build web --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
const _kMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

// ═════════════════════════════════════════════════════════════════════════════
// DATA CLASSES
// ═════════════════════════════════════════════════════════════════════════════

class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured =
        json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return PlacePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structured['main_text'] as String? ?? json['description'],
      secondaryText: structured['secondary_text'] as String? ?? '',
    );
  }
}

class PlaceDetail {
  const PlaceDetail({
    required this.latLng,
    required this.formattedAddress,
    this.postalCode,
    this.city,
    this.state,
    this.area,
  });

  final LatLng latLng;
  final String formattedAddress;
  final String? postalCode;
  final String? city;
  final String? state;
  final String? area;
}

// ═════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═════════════════════════════════════════════════════════════════════════════

class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://maps.googleapis.com/maps/api/place',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // ── Autocomplete ───────────────────────────────────────────────────────────

  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().length < 2) return [];
    if (_kMapsApiKey.isEmpty) {
      debugPrint(
          '[Places] GOOGLE_MAPS_API_KEY is not configured — autocomplete disabled.');
      return [];
    }
    try {
      final response = await _dio.get(
        '/autocomplete/json',
        queryParameters: {
          'input': input,
          'key': _kMapsApiKey,
          'components': 'country:in',
          'types': 'geocode',
          'language': 'en',
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        debugPrint('[Places] autocomplete HTTP status=${data['status']}');
        return [];
      }
      final predictions = data['predictions'] as List;
      return predictions
          .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('[Places] autocomplete failed: $e\n$stackTrace');
      return [];
    }
  }

  // ── Place details (LatLng + address components) ────────────────────────────

  Future<PlaceDetail?> getPlaceDetail(String placeId) async {
    if (_kMapsApiKey.isEmpty) {
      debugPrint(
          '[Places] GOOGLE_MAPS_API_KEY is not configured — getPlaceDetail disabled.');
      return null;
    }
    try {
      final response = await _dio.get(
        '/details/json',
        queryParameters: {
          'place_id': placeId,
          'key': _kMapsApiKey,
          'fields':
              'geometry,formatted_address,address_components',
          'language': 'en',
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final result = data['result'] as Map<String, dynamic>;
      final loc = result['geometry']['location'] as Map<String, dynamic>;
      final latLng = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
      final formatted = result['formatted_address'] as String? ?? '';

      // Parse address components
      final components =
          (result['address_components'] as List?) ?? [];
      String? postal, city, state, area;

      for (final comp in components) {
        final types = (comp['types'] as List).cast<String>();
        final longName = comp['long_name'] as String;
        if (types.contains('postal_code')) postal = longName;
        if (types.contains('locality')) city = longName;
        if (types.contains('administrative_area_level_1')) state = longName;
        if (types.contains('sublocality_level_1') ||
            types.contains('sublocality')) {
          area = longName;
        }
      }

      return PlaceDetail(
        latLng: latLng,
        formattedAddress: formatted,
        postalCode: postal,
        city: city,
        state: state,
        area: area,
      );
    } catch (e, stackTrace) {
      debugPrint('[Places] getPlaceDetail failed: $e\n$stackTrace');
      return null;
    }
  }
}
