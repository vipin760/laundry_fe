import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/service_model.dart';

// Services are public (no auth required on the backend).
// Not autoDispose — result stays cached so navigating away and back does not
// trigger a new network call and show a loading spinner again.
final servicesProvider = FutureProvider<List<ServiceModel>>((ref) async {
  try {
    debugPrint('[servicesProvider] Fetching ${ApiClient.baseUrl}/services');

    final response = await ApiClient.instance.get(
      '/services',
      options: Options(
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    debugPrint('[servicesProvider] Status: ${response.statusCode}');

    final payload = response.data;
    final rawData =
        payload is Map<String, dynamic> ? payload['data'] : payload;

    debugPrint('[servicesProvider] rawData: ${rawData.runtimeType}, '
        'count: ${rawData is List ? (rawData as List).length : "not a list"}');

    if (rawData is! List) return const [];

    final services = (rawData as List)
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .map(ServiceModel.fromJson)
        .toList(growable: false);

    final available = services
        .where((s) => s.isAvailable)
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    debugPrint('[servicesProvider] Total: ${services.length}, '
        'available: ${available.length}');
    return available;
  } on DioException catch (e) {
    debugPrint('[servicesProvider] DioException type=${e.type} '
        'status=${e.response?.statusCode} msg=${e.message}');
    final msg = e.response?.data is Map<String, dynamic>
        ? (e.response!.data['message'] as String?)
        : null;
    throw Exception(
      msg ?? 'Failed to load services (${e.type.name}). Check connection.',
    );
  } catch (e, st) {
    debugPrint('[servicesProvider] Error: $e\n$st');
    throw Exception(e.toString());
  }
});

// ─── Popular services (admin-selected top 3, in admin order) ─────────────────
// Falls back to the first 3 available services when the admin hasn't
// marked any service as popular yet.
final popularServicesProvider =
    FutureProvider<List<ServiceModel>>((ref) async {
  try {
    final response = await ApiClient.instance.get(
      '/services',
      queryParameters: {'popular': 'true'},
      options: Options(
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final payload = response.data;
    final rawData = payload is Map<String, dynamic> ? payload['data'] : payload;

    if (rawData is List && rawData.isNotEmpty) {
      final popular = rawData
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .map(ServiceModel.fromJson)
          .where((s) => s.isAvailable)
          .toList()
        ..sort((a, b) => (a.popularOrder ?? 99).compareTo(b.popularOrder ?? 99));
      if (popular.isNotEmpty) return popular.take(3).toList(growable: false);
    }

    // Fallback: first 3 of the full catalogue
    final all = await ref.watch(servicesProvider.future);
    return all.take(3).toList(growable: false);
  } on DioException {
    final all = await ref.watch(servicesProvider.future);
    return all.take(3).toList(growable: false);
  }
});

// ─── Paginated services (All Services lazy horizontal scroll) ────────────────

class PaginatedServicesState {
  const PaginatedServicesState({
    this.services = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.total = 0,
    this.error,
  });

  final List<ServiceModel> services;
  final bool isLoading;      // first page
  final bool isLoadingMore;  // subsequent pages
  final bool hasMore;
  final int total;
  final String? error;

  PaginatedServicesState copyWith({
    List<ServiceModel>? services,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    String? error,
    bool clearError = false,
  }) {
    return PaginatedServicesState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PaginatedServicesNotifier extends Notifier<PaginatedServicesState> {
  static const int pageSize = 8;
  int _page = 0;
  bool _fetching = false;

  @override
  PaginatedServicesState build() {
    // Kick off the first page after build returns the initial state.
    Future.microtask(loadFirstPage);
    return const PaginatedServicesState(isLoading: true);
  }

  Future<void> loadFirstPage() async {
    _page = 0;
    state = state.copyWith(
        services: [], isLoading: true, hasMore: true, clearError: true);
    await _loadNext();
  }

  /// Called when the user scrolls near the end of the row.
  Future<void> loadMore() async {
    if (_fetching || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    await _loadNext();
  }

  Future<void> _loadNext() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final nextPage = _page + 1;
      final response = await ApiClient.instance.get(
        '/services',
        queryParameters: {'page': nextPage, 'limit': pageSize},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final payload = response.data;
      final rawData =
          payload is Map<String, dynamic> ? payload['data'] : payload;
      final total = payload is Map<String, dynamic>
          ? (payload['total'] as num?)?.toInt()
          : null;

      final fetched = (rawData is List)
          ? rawData
              .whereType<Map>()
              .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
              .map(ServiceModel.fromJson)
              .where((s) => s.isAvailable)
              .toList(growable: false)
          : const <ServiceModel>[];

      _page = nextPage;
      final combined = [...state.services, ...fetched];
      final hasMore = total != null
          ? _page * pageSize < total
          : fetched.length == pageSize;

      state = state.copyWith(
        services: combined,
        isLoading: false,
        isLoadingMore: false,
        hasMore: hasMore,
        total: total ?? combined.length,
        clearError: true,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['message'] as String?)
          : null;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: msg ?? 'Failed to load services.',
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, isLoadingMore: false, error: e.toString());
    } finally {
      _fetching = false;
    }
  }
}

final paginatedServicesProvider =
    NotifierProvider<PaginatedServicesNotifier, PaginatedServicesState>(
        PaginatedServicesNotifier.new);
