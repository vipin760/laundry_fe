import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/address_model.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ADDRESSES LIST — AsyncNotifier (supports CRUD + optimistic updates)
// ═════════════════════════════════════════════════════════════════════════════

class AddressesNotifier extends AsyncNotifier<List<AddressModel>> {
  @override
  Future<List<AddressModel>> build() {
    // Depend on auth state rather than fetching unconditionally: on web,
    // this provider can be built before session restore (which is async)
    // finishes, and fetching before we know whether the user is logged in
    // causes an unauthenticated 401. Watching authProvider means this
    // rebuilds (and only then fetches) once restore completes or login
    // state actually changes.
    final auth = ref.watch(authProvider);
    if (!auth.isInitialized || !auth.isAuthenticated) return Future.value(const []);
    return _fetch();
  }

  // ── Remote fetch ───────────────────────────────────────────────────────────

  Future<List<AddressModel>> _fetch() async {
    try {
      final response = await ApiClient.instance.get('/user/addresses');
      final raw = response.data;
      final List items = raw is List
          ? raw
          : (raw['data'] ?? raw['addresses'] ?? []) as List;
      return items
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('[Location] fetch addresses failed: $e\n$stackTrace');
      return [];
    }
  }

  // ── Add ────────────────────────────────────────────────────────────────────
  // Returns true if the address already existed (duplicate), false if newly added.
  // API response shape: { address: {...}, alreadyExists: bool }

  Future<bool> addAddress(AddressModel address) async {
    final previous = state.value ?? [];

    // Optimistic: insert a temp item while waiting for server
    final temp = address.copyWith(id: '__temp__');
    state = AsyncData([...previous, temp]);

    try {
      final response = await ApiClient.instance.post(
        '/user/addresses',
        data: address.toJson(),
      );
      final data = response.data as Map<String, dynamic>;
      final alreadyExists = data['alreadyExists'] == true;
      final addressData = data['address'] as Map<String, dynamic>? ?? data;
      final saved = AddressModel.fromJson(addressData);

      if (alreadyExists) {
        // Roll back temp — existing address is already in the list.
        state = AsyncData(previous);
        return true;
      } else {
        state = AsyncData([...previous, saved]);
        return false;
      }
    } catch (e) {
      state = AsyncData(previous); // roll back
      rethrow;
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  Future<void> updateAddress(AddressModel address) async {
    if (address.id == null) return;
    final previous = state.value ?? [];

    state = AsyncData(
      previous.map((a) => a.id == address.id ? address : a).toList(),
    );

    try {
      final response = await ApiClient.instance.put(
        '/user/addresses/${address.id}',
        data: address.toJson(),
      );
      final data = response.data;
      final updated = AddressModel.fromJson(
        data is Map<String, dynamic> ? data : (data['data'] as Map<String, dynamic>),
      );
      state = AsyncData(
        previous.map((a) => a.id == address.id ? updated : a).toList(),
      );
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteAddress(String id) async {
    final previous = state.value ?? [];
    state = AsyncData(previous.where((a) => a.id != id).toList());

    try {
      await ApiClient.instance.delete('/user/addresses/$id');

      // selectedAddressProvider holds a disconnected snapshot (set once when
      // the user picks an address at checkout), not a live reference into
      // this list. If the deleted address was that snapshot, clear it too —
      // otherwise the pickup/scheduling screens keep showing the deleted
      // address until the provider is reset (e.g. app restart), which is
      // exactly the "needs a refresh" symptom this fixes.
      if (ref.read(selectedAddressProvider)?.id == id) {
        ref.read(selectedAddressProvider.notifier).clear();
      }
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  // ── Set default ────────────────────────────────────────────────────────────

  Future<void> setDefault(String id) async {
    final previous = state.value ?? [];
    // Optimistic: flip default flags locally
    state = AsyncData(
      previous
          .map((a) => a.copyWith(isDefault: a.id == id))
          .toList(),
    );
    try {
      await ApiClient.instance.put('/user/addresses/$id/default');
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  void refresh() => ref.invalidateSelf();
}

final addressesProvider =
    AsyncNotifierProvider<AddressesNotifier, List<AddressModel>>(
  AddressesNotifier.new,
);

// ═════════════════════════════════════════════════════════════════════════════
// SELECTED ADDRESS (used during checkout flow)
// StateProvider was removed in Riverpod v3 — use a plain Notifier instead.
// ═════════════════════════════════════════════════════════════════════════════

class _SelectedAddressNotifier extends Notifier<AddressModel?> {
  @override
  AddressModel? build() => null;

  void select(AddressModel? address) => state = address;
  void clear() => state = null;
}

final selectedAddressProvider =
    NotifierProvider<_SelectedAddressNotifier, AddressModel?>(
  _SelectedAddressNotifier.new,
);
