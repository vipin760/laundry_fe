import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_notification_model.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.unread = 0,
    this.isLoading = false,
    this.error,
  });

  final List<AppNotificationModel> items;
  final int unread;
  final bool isLoading;
  final String? error;

  NotificationsState copyWith({
    List<AppNotificationModel>? items,
    int? unread,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unread: unread ?? this.unread,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    // Gate on auth restoration rather than fetching unconditionally: on
    // web this provider can build before session restore (async) finishes,
    // and fetching before we know the user is logged in sends an
    // unauthenticated request. Watching authProvider re-triggers this once
    // restore completes (or login state actually changes).
    final auth = ref.watch(authProvider);
    final willFetch = auth.isInitialized && auth.isAuthenticated;
    if (willFetch) {
      Future.microtask(refresh);
    }
    // isLoading only makes sense while a fetch is actually pending — for a
    // logged-out (or not-yet-restored) user, `willFetch` is false and there
    // is no in-flight request to wait on, so it must not be left stuck true.
    return NotificationsState(isLoading: willFetch);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await ApiClient.instance.get(
        '/notifications',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final payload = response.data;
      final rawData =
          payload is Map<String, dynamic> ? payload['data'] : payload;
      final unread = payload is Map<String, dynamic>
          ? (payload['unread'] as num?)?.toInt() ?? 0
          : 0;

      final items = (rawData is List)
          ? rawData
              .whereType<Map>()
              .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
              .map(AppNotificationModel.fromJson)
              .toList(growable: false)
          : const <AppNotificationModel>[];

      state = state.copyWith(
          items: items, unread: unread, isLoading: false, clearError: true);
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['message'] as String?)
          : null;
      state = state.copyWith(
          isLoading: false, error: msg ?? 'Could not load notifications.');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Marks everything read on the server and locally.
  Future<void> markAllRead() async {
    if (state.unread == 0) return;
    try {
      await ApiClient.instance.patch('/notifications/read');
      state = state.copyWith(
        unread: 0,
        items: state.items
            .map((n) => AppNotificationModel(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  type: n.type,
                  orderId: n.orderId,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList(growable: false),
      );
    } catch (_) {
      // Non-fatal — badge simply stays until next successful sync.
    }
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
        NotificationsNotifier.new);
