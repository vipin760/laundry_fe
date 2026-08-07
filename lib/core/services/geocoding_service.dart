import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as native;

/// Platform-agnostic replacement for `package:geocoding`'s [Placemark],
/// covering the fields the app actually reads from a reverse-geocode result.
class GeoPlacemark {
  const GeoPlacemark({
    this.name,
    this.subThoroughfare,
    this.thoroughfare,
    this.subLocality,
    this.subAdministrativeArea,
    this.locality,
    this.administrativeArea,
    this.postalCode,
  });

  final String? name;
  final String? subThoroughfare;
  final String? thoroughfare;
  final String? subLocality;
  final String? subAdministrativeArea;
  final String? locality;
  final String? administrativeArea;
  final String? postalCode;
}

class GeoLocation {
  const GeoLocation({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

/// Reverse/forward geocoding that actually works on Flutter Web.
///
/// The `geocoding` package (baseflow) only ships Android and iOS platform
/// implementations — there is no `geocoding_web` package, so
/// `GeocodingPlatform.instance` is null on web and every call to
/// `placemarkFromCoordinates()` / `locationFromAddress()` throws a null-check
/// error immediately.
///
/// - Mobile/desktop: delegates to `package:geocoding` (native platform APIs).
/// - Web: calls OpenStreetMap's Nominatim API — free, no API key required.
///   Usage policy (https://operations.osmfoundation.org/policies/nominatim/)
///   caps public use at ~1 request/second, which a manual "Use Current
///   Location" tap comfortably satisfies.
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  Future<List<GeoPlacemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    if (!kIsWeb) {
      try {
        final marks = await native.placemarkFromCoordinates(latitude, longitude);
        return marks
            .map((p) => GeoPlacemark(
                  name: p.name,
                  subThoroughfare: p.subThoroughfare,
                  thoroughfare: p.thoroughfare,
                  subLocality: p.subLocality,
                  subAdministrativeArea: p.subAdministrativeArea,
                  locality: p.locality,
                  administrativeArea: p.administrativeArea,
                  postalCode: p.postalCode,
                ))
            .toList();
      } catch (e, stackTrace) {
        debugPrint('[Geocoding] reverseGeocode (native) failed: $e\n$stackTrace');
        rethrow;
      }
    }

    try {
      final response = await _dio.get('/reverse', queryParameters: {
        'format': 'jsonv2',
        'lat': latitude,
        'lon': longitude,
        'addressdetails': 1,
        'zoom': 18,
      });
      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw StateError('Nominatim reverse geocode error: ${data['error']}');
      }

      final address = ((data['address'] as Map?) ?? {}).cast<String, dynamic>();
      final mark = GeoPlacemark(
        name: data['name'] as String?,
        subThoroughfare: address['house_number'] as String?,
        thoroughfare: address['road'] as String?,
        subLocality: (address['suburb'] ??
            address['neighbourhood'] ??
            address['quarter']) as String?,
        subAdministrativeArea: address['county'] as String?,
        locality: (address['city'] ?? address['town'] ?? address['village'])
            as String?,
        administrativeArea: address['state'] as String?,
        postalCode: address['postcode'] as String?,
      );
      return [mark];
    } catch (e, stackTrace) {
      debugPrint('[Geocoding] reverseGeocode (web/Nominatim) failed: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<GeoLocation>> locationFromAddress(String address) async {
    if (!kIsWeb) {
      try {
        final locations = await native.locationFromAddress(address);
        return locations
            .map((l) => GeoLocation(latitude: l.latitude, longitude: l.longitude))
            .toList();
      } catch (e, stackTrace) {
        debugPrint('[Geocoding] forwardGeocode (native) failed: $e\n$stackTrace');
        rethrow;
      }
    }

    try {
      final response = await _dio.get('/search', queryParameters: {
        'format': 'jsonv2',
        'q': address,
        'limit': 1,
      });
      final results = (response.data as List).cast<Map<String, dynamic>>();
      if (results.isEmpty) return [];

      final r = results.first;
      return [
        GeoLocation(
          latitude: double.parse(r['lat'] as String),
          longitude: double.parse(r['lon'] as String),
        ),
      ];
    } catch (e, stackTrace) {
      debugPrint('[Geocoding] forwardGeocode (web/Nominatim) failed: $e\n$stackTrace');
      rethrow;
    }
  }
}
