import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/cloth_type_model.dart';

// Cloth types are public (no auth required on the backend) — same reasoning
// as servicesProvider. Not autoDispose, so the pricing screen doesn't
// re-fetch and flash a loading spinner every time the user navigates back.
final clothTypesProvider = FutureProvider<List<ClothTypeModel>>((ref) async {
  try {
    debugPrint('[clothTypesProvider] Fetching ${ApiClient.baseUrl}/cloth-types');

    final response = await ApiClient.instance.get(
      '/cloth-types',
      options: Options(
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final payload = response.data;
    final rawData =
        payload is Map<String, dynamic> ? payload['data'] : payload;

    if (rawData is! List) return const [];

    // Parse defensively: a single malformed/legacy document (e.g. from stale
    // seed data) must not take down pricing for every item. Skip and log it
    // instead of letting one bad row crash the whole list.
    final clothTypes = <ClothTypeModel>[];
    for (final item in rawData.whereType<Map>()) {
      try {
        final normalized = item.map((k, v) => MapEntry(k.toString(), v));
        final clothType = ClothTypeModel.fromJson(normalized);
        if (clothType.isActive) clothTypes.add(clothType);
      } catch (e) {
        debugPrint('[clothTypesProvider] Skipping malformed cloth type: $e');
      }
    }

    debugPrint('[clothTypesProvider] Total active cloth types: ${clothTypes.length}');
    return clothTypes;
  } on DioException catch (e) {
    debugPrint('[clothTypesProvider] DioException type=${e.type} '
        'status=${e.response?.statusCode} msg=${e.message}');
    final msg = e.response?.data is Map<String, dynamic>
        ? (e.response!.data['message'] as String?)
        : null;
    throw Exception(
      msg ?? 'Failed to load pricing (${e.type.name}). Check connection.',
    );
  } catch (e, st) {
    debugPrint('[clothTypesProvider] Error: $e\n$st');
    throw Exception(e.toString());
  }
});
