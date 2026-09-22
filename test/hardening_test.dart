import 'package:flutter_test/flutter_test.dart';

import 'package:laudry_app/core/config/payment_config.dart';
import 'package:laudry_app/core/router/app_routes.dart';
import 'package:laudry_app/features/delivery/providers/delivery_orders_provider.dart';
import 'package:laudry_app/features/orders/models/order_model.dart';

void main() {
  group('OrderStatusMapper (BUG-020)', () {
    test('maps every known backend status', () {
      expect(OrderStatusMapper.fromApi('ORDER_PLACED'), OrderStatus.orderPlaced);
      expect(OrderStatusMapper.fromApi('PICKUP_ASSIGNED'),
          OrderStatus.pickupAssigned);
      expect(OrderStatusMapper.fromApi('ITEMIZED'), OrderStatus.itemized);
      expect(OrderStatusMapper.fromApi('PROCESSING'), OrderStatus.brewing);
      expect(OrderStatusMapper.fromApi('OUT_FOR_DELIVERY'),
          OrderStatus.outForDelivery);
      expect(OrderStatusMapper.fromApi('READY_FOR_PICKUP'),
          OrderStatus.readyForPickup);
      expect(OrderStatusMapper.fromApi('COMPLETED'), OrderStatus.completed);
      expect(OrderStatusMapper.fromApi('CANCELLED'), OrderStatus.cancelled);
    });

    test('an unrecognised status is unknown, never "just placed"', () {
      // The whole point of BUG-020: a status added server-side must not be
      // silently rendered as the first step of the timeline.
      expect(OrderStatusMapper.fromApi('AWAITING_QC'), OrderStatus.unknown);
      expect(OrderStatusMapper.fromApi(''), OrderStatus.unknown);
      expect(OrderStatusMapper.fromApi(null), OrderStatus.unknown);
      expect(OrderStatusMapper.fromApi(42), OrderStatus.unknown);
      expect(OrderStatusMapper.fromApi({'a': 1}), OrderStatus.unknown);
    });

    test('unknown and cancelled have no place on the timeline', () {
      expect(OrderStatusMapper.timelineIndex(OrderStatus.unknown), isNull);
      expect(OrderStatusMapper.timelineIndex(OrderStatus.cancelled), isNull);
      expect(OrderStatusMapper.timelineIndex(OrderStatus.orderPlaced), 0);
      expect(OrderStatusMapper.timelineIndex(OrderStatus.brewing), 3);
      // Self-pickup's READY_FOR_PICKUP shares the dispatch step rather than
      // falling through to step 1 as it used to on the orders list.
      expect(OrderStatusMapper.timelineIndex(OrderStatus.readyForPickup), 4);
      expect(OrderStatusMapper.timelineIndex(OrderStatus.completed), 4);
    });

    test('every status has a label, including unknown', () {
      for (final status in OrderStatus.values) {
        expect(OrderStatusMapper.label(status), isNotEmpty);
      }
      expect(OrderStatusMapper.label(OrderStatus.unknown), 'In Progress');
    });

    test('apiKey round-trips the known statuses', () {
      for (final status in OrderStatus.values) {
        final key = OrderStatusMapper.apiKey(status);
        if (status == OrderStatus.unknown) {
          expect(key, isNull);
        } else {
          expect(OrderStatusMapper.fromApi(key), status);
        }
      }
    });
  });

  group('OrderModel.fromJson resilience (white-screen prevention)', () {
    Map<String, dynamic> validOrder() => {
          '_id': 'order-1',
          'orderNumber': 'LB-0001',
          'status': 'PROCESSING',
          'paymentStatus': 'COMPLETED',
          'totalAmount': 450,
          'createdAt': '2026-09-01T10:00:00.000Z',
        };

    test('parses a well-formed order', () {
      final order = OrderModel.fromJson(validOrder());
      expect(order.id, 'order-1');
      expect(order.status, OrderStatus.brewing);
      expect(order.paymentStatus, PaymentStatus.completed);
      expect(order.totalAmount, 450);
    });

    test('survives a missing or unparseable createdAt', () {
      // Previously DateTime.parse(null) threw, which blanked every screen
      // that renders an order.
      final noDate = validOrder()..remove('createdAt');
      expect(() => OrderModel.fromJson(noDate), returnsNormally);

      final badDate = validOrder()..['createdAt'] = 'not-a-date';
      expect(() => OrderModel.fromJson(badDate), returnsNormally);
    });

    test('survives nested refs arriving as ids instead of objects', () {
      // Mongo-style unpopulated references come back as bare id strings.
      final json = validOrder()
        ..['customer'] = '64f0c9a2e13b'
        ..['deliveryAddress'] = '64f0c9a2e13c'
        ..['receptionDetails'] = '64f0c9a2e13d'
        ..['locationSnapshot'] = 'shop-1';

      late final OrderModel order;
      expect(() => order = OrderModel.fromJson(json), returnsNormally);
      expect(order.customer, isNull);
      expect(order.deliveryAddress, isNull);
      expect(order.shopName, isNull);
    });

    test('an unknown status parses rather than throwing', () {
      final json = validOrder()..['status'] = 'AWAITING_QC';
      final order = OrderModel.fromJson(json);
      expect(order.status, OrderStatus.unknown);
    });

    test('non-string status/paymentStatus do not throw', () {
      final json = validOrder()
        ..['status'] = 7
        ..['paymentStatus'] = false
        ..['deliveryType'] = 3;
      late final OrderModel order;
      expect(() => order = OrderModel.fromJson(json), returnsNormally);
      expect(order.status, OrderStatus.unknown);
      expect(order.paymentStatus, PaymentStatus.pending);
    });
  });

  group('OtpThrottleState (BUG-019)', () {
    test('starts with a full set of attempts and is not locked', () {
      const throttle = OtpThrottleState();
      expect(throttle.isLocked, isFalse);
      expect(throttle.attemptsLeft, OtpThrottleState.maxAttempts);
      expect(throttle.remainingLockout, Duration.zero);
    });

    test('counts down remaining attempts', () {
      const throttle = OtpThrottleState(failedAttempts: 3);
      expect(throttle.attemptsLeft, OtpThrottleState.maxAttempts - 3);
      expect(throttle.isLocked, isFalse);
    });

    test('reports locked while the lockout is in the future', () {
      final throttle = OtpThrottleState(
        failedAttempts: OtpThrottleState.maxAttempts,
        lockedUntil: DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(throttle.isLocked, isTrue);
      expect(throttle.attemptsLeft, 0);
      expect(throttle.remainingLockout.inSeconds, greaterThan(25));
    });

    test('a past lockout is no longer locking and never reports negative time',
        () {
      final throttle = OtpThrottleState(
        failedAttempts: OtpThrottleState.maxAttempts,
        lockedUntil: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      expect(throttle.isLocked, isFalse);
      expect(throttle.remainingLockout, Duration.zero);
    });
  });

  group('PaymentConfig.prefillFor (BUG-016)', () {
    test('uses the signed-in user details', () {
      final prefill = PaymentConfig.prefillFor(
        contact: '+919876543210',
        email: 'customer@example.com',
      );
      expect(prefill['contact'], '+919876543210');
      expect(prefill['email'], 'customer@example.com');
    });

    test('omits missing fields instead of sending placeholder data', () {
      // The old hardcoded '8888888888' / 'test@razorpay.com' went out on real
      // transactions; absent fields should simply be collected by Razorpay.
      expect(PaymentConfig.prefillFor(contact: null, email: null), isEmpty);
      expect(PaymentConfig.prefillFor(contact: '  ', email: ''), isEmpty);

      final partial = PaymentConfig.prefillFor(contact: '9876543210');
      expect(partial, containsPair('contact', '9876543210'));
      expect(partial.containsKey('email'), isFalse);
    });
  });

  group('AppRoutes.isPublic (BUG-008 — Apple 5.1.1(v) guest browsing)', () {
    test('browsable content is reachable without an account', () {
      for (final route in [
        AppRoutes.home,
        AppRoutes.services,
        AppRoutes.ironing,
        AppRoutes.dryCleaning,
        AppRoutes.pricing,
        AppRoutes.support,
        AppRoutes.faqs,
        AppRoutes.howItWorks,
        AppRoutes.terms,
        AppRoutes.privacy,
        AppRoutes.more,
        AppRoutes.about,
        AppRoutes.blog,
      ]) {
        expect(AppRoutes.isPublic(route), isTrue, reason: '$route should be public');
      }
    });

    test('account-owned areas stay gated', () {
      for (final route in [
        AppRoutes.orders,
        AppRoutes.orderReview,
        AppRoutes.wallet,
        AppRoutes.addMoney,
        AppRoutes.profile,
        AppRoutes.addresses,
        AppRoutes.notifications,
        AppRoutes.pickupDelivery,
        AppRoutes.deliveryPartnerHome,
        AppRoutes.devScreens,
      ]) {
        expect(AppRoutes.isPublic(route), isFalse,
            reason: '$route should require auth');
      }
    });

    test('query strings and sub-paths are classified by their route tree', () {
      expect(AppRoutes.isPublic('/services?ref=LBX123'), isTrue);
      expect(AppRoutes.isPublic('/services/anything/deeper'), isTrue);
      expect(AppRoutes.isPublic('/orders/tracking/confirmed'), isFalse);
      // A private route must not be let through by sharing a public prefix.
      expect(AppRoutes.isPublic('/profile/notifications'), isFalse);
      expect(AppRoutes.isPublic('/homework'), isFalse);
    });
  });
}
