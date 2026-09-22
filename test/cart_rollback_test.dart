import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:laudry_app/core/api/api_client.dart';
import 'package:laudry_app/features/auth/providers/auth_provider.dart';
import 'package:laudry_app/features/services/models/service_model.dart';
import 'package:laudry_app/features/services/providers/cart_provider.dart';

/// Adapter that fails every request, standing in for "the server never took
/// the change" — offline, timeout, or a 5xx.
class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'simulated network failure',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Adapter that accepts every request.
class _SucceedingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ServiceModel _service(String id) => ServiceModel(
      id: id,
      name: 'Service $id',
      price: 100,
      instantDescription: '',
      scheduledDescription: '',
      instantOrderPlacedMessage: '',
      scheduledOrderPlacedMessage: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalAdapter = ApiClient.instance.httpClientAdapter;
    container = ProviderContainer();

    // cartProvider watches authProvider and resets itself whenever auth state
    // changes, so let session restore finish before touching the cart —
    // otherwise the rebuild wipes whatever the test just added.
    container.read(authProvider);
    for (var i = 0; i < 50; i++) {
      if (container.read(authProvider).isInitialized) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    container.read(cartProvider);
  });

  tearDown(() {
    ApiClient.instance.httpClientAdapter = originalAdapter;
    container.dispose();
  });

  group('cart server sync rollback (BUG-003)', () {
    test('a rejected add is rolled back and reported', () async {
      ApiClient.instance.httpClientAdapter = _FailingAdapter();
      final notifier = container.read(cartProvider.notifier);

      final added = await notifier.addToCartOptimistic(_service('a'), 'instant');

      // The item never reached the server cart that checkout reads, so it must
      // not be left sitting in the on-screen cart.
      expect(added, isFalse);
      expect(container.read(cartProvider).items, isEmpty);
      expect(container.read(cartProvider).quantityFor('a', 'instant'), 0);
      expect(container.read(cartProvider).errorMessage, isNotNull);
    });

    test('a successful add is kept', () async {
      ApiClient.instance.httpClientAdapter = _SucceedingAdapter();
      final notifier = container.read(cartProvider.notifier);

      final added = await notifier.addToCartOptimistic(_service('a'), 'instant');

      expect(added, isTrue);
      expect(container.read(cartProvider).quantityFor('a', 'instant'), 1);
      expect(container.read(cartProvider).errorMessage, isNull);
    });

    test('a rejected removal puts the item back', () async {
      ApiClient.instance.httpClientAdapter = _SucceedingAdapter();
      final notifier = container.read(cartProvider.notifier);
      await notifier.addToCartOptimistic(_service('a'), 'instant');
      expect(container.read(cartProvider).quantityFor('a', 'instant'), 1);

      ApiClient.instance.httpClientAdapter = _FailingAdapter();
      await notifier.removeFromCart('a', 'instant');

      // Still in the server's cart — hiding it would let a "removed" item ship.
      expect(container.read(cartProvider).quantityFor('a', 'instant'), 1);
      expect(container.read(cartProvider).errorMessage, isNotNull);
    });

    test('a rejected decrement-to-zero restores the line', () async {
      ApiClient.instance.httpClientAdapter = _SucceedingAdapter();
      final notifier = container.read(cartProvider.notifier);
      await notifier.addToCartOptimistic(_service('a'), 'instant');

      ApiClient.instance.httpClientAdapter = _FailingAdapter();
      await notifier.decrementOrRemove('a', 'instant');

      expect(container.read(cartProvider).quantityFor('a', 'instant'), 1);
      expect(container.read(cartProvider).errorMessage, isNotNull);
    });

    test('rolling back one line leaves other lines untouched', () async {
      ApiClient.instance.httpClientAdapter = _SucceedingAdapter();
      final notifier = container.read(cartProvider.notifier);
      await notifier.addToCartOptimistic(_service('keep'), 'instant');

      ApiClient.instance.httpClientAdapter = _FailingAdapter();
      await notifier.addToCartOptimistic(_service('fails'), 'instant');

      expect(container.read(cartProvider).quantityFor('keep', 'instant'), 1);
      expect(container.read(cartProvider).quantityFor('fails', 'instant'), 0);
    });

    test('acknowledgeError lets an identical failure notify again', () async {
      ApiClient.instance.httpClientAdapter = _FailingAdapter();
      final notifier = container.read(cartProvider.notifier);

      await notifier.addToCartOptimistic(_service('a'), 'instant');
      expect(container.read(cartProvider).errorMessage, isNotNull);

      notifier.acknowledgeError();
      expect(container.read(cartProvider).errorMessage, isNull);

      await notifier.addToCartOptimistic(_service('a'), 'instant');
      expect(container.read(cartProvider).errorMessage, isNotNull);
    });
  });
}
