import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../models/service_model.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';

const _cartStorageKey = 'laundry_user_cart_v1';

/// Composite key so the same service added from Instant and Scheduled tabs
/// are treated as separate line items.
String cartItemKey(String serviceId, String category) => '${serviceId}_$category';

/// Wipes the legacy local cart cache. A plain function (not a provider read)
/// so callers outside this file — namely AuthNotifier.logout() — can clear
/// it without reaching into `cartProvider.notifier`. CartNotifier.build()
/// already `ref.watch(authProvider)` and resets itself to an empty
/// [CartState] the moment auth flips to logged-out, so the in-memory side is
/// handled reactively; this only needs to cover the persisted cache.
///
/// Do NOT replace this with `ref.read(cartProvider.notifier).clearCart()`
/// from auth_provider.dart — cart_provider.dart imports auth_provider.dart
/// (to watch it), so reading cartProvider's notifier from inside
/// AuthNotifier's own method closes the loop and Riverpod's
/// circular-dependency guard throws (CartNotifier "depends on itself").
Future<void> clearCartLocalCache(SharedPreferences prefs) async {
  await prefs.remove(_cartStorageKey);
}

class CartLineItem {
  const CartLineItem({
    required this.service,
    required this.quantity,
    required this.category,
  });

  final ServiceModel service;
  final int quantity;

  /// 'instant' or 'scheduled'
  final String category;

  String get key => cartItemKey(service.id, category);

  CartLineItem copyWith({ServiceModel? service, int? quantity, String? category}) {
    return CartLineItem(
      service: service ?? this.service,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
    );
  }
}

class CartState {
  const CartState({
    this.items = const <String, CartLineItem>{},
    this.pendingKeys = const <String>{},
    this.isLoading = false,
    this.errorMessage,
  });

  /// Keyed by cartItemKey(serviceId, category).
  final Map<String, CartLineItem> items;
  final Set<String> pendingKeys;
  final bool isLoading;
  final String? errorMessage;

  List<CartLineItem> get lineItems => items.values.toList(growable: false);

  int get uniqueItemsCount => items.length;

  int get totalItemsCount =>
      items.values.fold<int>(0, (sum, item) => sum + item.quantity);

  double get totalPrice => items.values.fold<double>(
        0,
        (sum, item) => sum + (item.service.price * item.quantity),
      );

  int quantityFor(String serviceId, String category) =>
      items[cartItemKey(serviceId, category)]?.quantity ?? 0;

  /// Category of the items currently in the cart ('instant'/'scheduled'),
  /// or null when the cart is empty. Only one category is allowed at a time.
  String? get cartCategory =>
      items.isEmpty ? null : items.values.first.category;

  /// True when adding [category] would mix Instant and Scheduled services.
  bool conflictsWith(String category) =>
      cartCategory != null && cartCategory != category;

  bool isPending(String serviceId, String category) =>
      pendingKeys.contains(cartItemKey(serviceId, category));

  CartState copyWith({
    Map<String, CartLineItem>? items,
    Set<String>? pendingKeys,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CartState(
      items: items ?? this.items,
      pendingKeys: pendingKeys ?? this.pendingKeys,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  final Dio _dio = ApiClient.instance;

  @override
  CartState build() {
    // Depend on auth state rather than firing unconditionally: on web,
    // this provider can be built before session restore (which is async)
    // finishes, and fetching before we know whether the user is logged in
    // causes an unauthenticated 401. Watching authProvider means this
    // rebuilds (and only then fetches) once restore completes or login
    // state actually changes.
    final auth = ref.watch(authProvider);
    if (auth.isInitialized && auth.isAuthenticated) {
      Future.microtask(() => fetchCartFromServer());
    }
    return const CartState();
  }

  Future<void> fetchCartFromServer() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _dio.get('/cart');
      final data = response.data;

      final List serverItems =
          (data != null && data['items'] != null) ? data['items'] as List : [];

      final nextItems = <String, CartLineItem>{};
      for (final item in serverItems) {
        final serviceId = item['serviceId'].toString();
        final category = (item['category'] as String?) ?? 'instant';
        final key = cartItemKey(serviceId, category);
        nextItems[key] = CartLineItem(
          service: ServiceModel(
            id: serviceId,
            name: item['serviceNameSnapshot'] ?? '',
            price: (item['unitPriceSnapshot'] as num).toDouble(),
            instantDescription: '',
            scheduledDescription: '',
            instantOrderPlacedMessage: '',
            scheduledOrderPlacedMessage: '',
            turnaroundHours: (item['turnaroundHoursSnapshot'] as num?)?.toInt() ?? 24,
            instantTurnaroundMinutes:
                (item['instantTurnaroundMinutesSnapshot'] as num?)?.toInt() ?? 90,
          ),
          quantity: (item['quantity'] as num).toInt(),
          category: category,
        );
      }

      state = state.copyWith(items: nextItems, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Returns false (and sets [CartState.errorMessage]) when the add would mix
  /// Instant and Scheduled services — only one type is allowed per order.
  Future<bool> addToCartOptimistic(ServiceModel service, String category) async {
    if (state.conflictsWith(category)) {
      state = state.copyWith(
        errorMessage: category == 'instant'
            ? 'Your cart has Scheduled services. Clear it to add Instant services.'
            : 'Your cart has Instant services. Clear it to add Scheduled services.',
      );
      return false;
    }

    final key = cartItemKey(service.id, category);
    final nextItems = Map<String, CartLineItem>.from(state.items);
    if (nextItems.containsKey(key)) return true;

    nextItems[key] = CartLineItem(service: service, quantity: 1, category: category);
    _setPending(key);
    state = state.copyWith(items: nextItems, clearError: true);

    try {
      await _dio.post(
        '/cart/items',
        data: {'serviceId': service.id, 'quantity': 1, 'category': category},
      );
    } catch (_) {
      state = state.copyWith(errorMessage: 'Failed to sync with server');
    } finally {
      _markSettled(key);
    }
    return true;
  }

  /// Empties the cart (server + local) and adds [service]. Used when the user
  /// confirms switching between Instant and Scheduled order types.
  Future<void> replaceCartWith(ServiceModel service, String category) async {
    final existing = state.lineItems;
    for (final item in existing) {
      await removeFromCart(item.service.id, item.category);
    }
    await addToCartOptimistic(service, category);
  }

  Future<void> decrementOrRemove(String serviceId, String category) async {
    final key = cartItemKey(serviceId, category);
    final existing = state.items[key];
    if (existing == null) return;

    final nextItems = Map<String, CartLineItem>.from(state.items);
    final removing = existing.quantity <= 1;

    if (removing) {
      nextItems.remove(key);
    } else {
      nextItems[key] = existing.copyWith(quantity: existing.quantity - 1);
    }

    _setPending(key);
    state = state.copyWith(items: nextItems, clearError: true);

    try {
      if (removing) {
        await _dio.delete(
          '/cart/items/$serviceId',
          queryParameters: {'category': category},
        );
      } else {
        await _dio.post(
          '/cart/items',
          data: {'serviceId': serviceId, 'quantity': -1, 'category': category},
        );
      }
    } catch (_) {
      state = state.copyWith(errorMessage: 'Failed to sync with server');
    } finally {
      _markSettled(key);
    }
  }

  Future<void> removeFromCart(String serviceId, String category) async {
    final key = cartItemKey(serviceId, category);
    if (!state.items.containsKey(key)) return;

    final nextItems = Map<String, CartLineItem>.from(state.items)..remove(key);
    _setPending(key);
    state = state.copyWith(items: nextItems, clearError: true);

    try {
      await _dio.delete(
        '/cart/items/$serviceId',
        queryParameters: {'category': category},
      );
    } catch (_) {
      state = state.copyWith(errorMessage: 'Failed to sync with server');
    } finally {
      _markSettled(key);
    }
  }

  /// Clears in-memory cart and any legacy local cache. Called on logout.
  Future<void> clearCart() async {
    state = const CartState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartStorageKey);
    } catch (_) {}
  }

  void _setPending(String key) {
    state = state.copyWith(
      pendingKeys: <String>{...state.pendingKeys, key},
    );
  }

  void _markSettled(String key) {
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!ref.mounted) return;
      final next = <String>{...state.pendingKeys}..remove(key);
      state = state.copyWith(pendingKeys: next);
    });
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
