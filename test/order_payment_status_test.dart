import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laudry_app/core/realtime/order_realtime.dart';
import 'package:laudry_app/features/orders/models/order_model.dart';
import 'package:laudry_app/features/orders/widgets/order_payment_status_card.dart';

Map<String, dynamic> _orderJson({Map<String, dynamic> extra = const {}}) => {
      '_id': '6af1bc33a22b463f9dede6bd',
      'orderNumber': 'LB10001',
      'items': [],
      'totalAmount': 480,
      'billAmount': 480,
      'status': 'OUT_FOR_DELIVERY',
      'paymentStatus': 'PENDING',
      'createdAt': '2026-11-09T10:00:00.000Z',
      ...extra,
    };

void main() {
  group('OrderModel payment fields', () {
    test('a legacy order with none of the new fields still parses, all null', () {
      final o = OrderModel.fromJson(_orderJson());
      expect(o.paymentMethod, isNull);
      expect(o.paymentTransactionId, isNull);
      expect(o.paymentCompletedAt, isNull);
      expect(o.isAwaitingQrPayment, isFalse);
      expect(o.isQrExpired, isFalse);
    });

    test('QR_GENERATED on an unpaid order means "awaiting payment"', () {
      final o = OrderModel.fromJson(_orderJson(extra: {'paymentQrStatus': 'QR_GENERATED'}));
      expect(o.isAwaitingQrPayment, isTrue);
      expect(o.isQrExpired, isFalse);
      expect(o.paymentStatus, PaymentStatus.pending);
    });

    test('EXPIRED on an unpaid order means the QR timed out', () {
      final o = OrderModel.fromJson(_orderJson(extra: {'paymentQrStatus': 'EXPIRED'}));
      expect(o.isQrExpired, isTrue);
      expect(o.isAwaitingQrPayment, isFalse);
    });

    test('a paid order parses the receipt data and ignores any stale QR flag', () {
      final o = OrderModel.fromJson(_orderJson(extra: {
        'paymentStatus': 'COMPLETED',
        'paymentQrStatus': 'QR_GENERATED', // stale denormalized hint must not win
        'paymentMethod': 'UPI',
        'paymentTransactionId': 'RRN123456',
        'paymentChannel': 'QR',
        'paymentCompletedAt': '2026-11-09T12:30:00.000Z',
      }));
      expect(o.paymentStatus, PaymentStatus.completed);
      expect(o.paymentMethod, 'UPI');
      expect(o.paymentTransactionId, 'RRN123456');
      expect(o.paymentChannel, 'QR');
      expect(o.paymentCompletedAt, DateTime.utc(2026, 11, 9, 12, 30));
      expect(o.isAwaitingQrPayment, isFalse);
      expect(o.isQrExpired, isFalse);
    });

    test('a malformed completion timestamp degrades to null instead of throwing', () {
      final o = OrderModel.fromJson(_orderJson(extra: {'paymentCompletedAt': 'not-a-date'}));
      expect(o.paymentCompletedAt, isNull);
    });
  });

  group('PaymentQrStatusBanner', () {
    Future<void> pump(WidgetTester t, OrderModel o) =>
        t.pumpWidget(MaterialApp(home: Scaffold(body: PaymentQrStatusBanner(order: o))));

    testWidgets('shows "Awaiting Payment" with the amount while a QR is live', (t) async {
      await pump(t, OrderModel.fromJson(_orderJson(extra: {'paymentQrStatus': 'QR_GENERATED'})));
      expect(find.text('Awaiting Payment'), findsOneWidget);
      expect(find.textContaining('₹480.00'), findsOneWidget);
    });

    testWidgets('shows the expired notice', (t) async {
      await pump(t, OrderModel.fromJson(_orderJson(extra: {'paymentQrStatus': 'EXPIRED'})));
      expect(find.text('Payment QR expired'), findsOneWidget);
    });

    testWidgets('renders nothing when no QR is involved', (t) async {
      await pump(t, OrderModel.fromJson(_orderJson()));
      expect(find.text('Awaiting Payment'), findsNothing);
      expect(find.text('Payment QR expired'), findsNothing);
    });
  });

  group('OrderPaymentEvent', () {
    test('consecutive events for the same order are distinct state changes', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(orderPaymentEventProvider.notifier);

      notifier.emit('abc');
      final first = c.read(orderPaymentEventProvider)!;
      notifier.emit('abc');
      final second = c.read(orderPaymentEventProvider)!;

      expect(second.seq, greaterThan(first.seq));
    });

    test('"*" concerns every order; a specific id concerns only itself', () {
      const all = OrderPaymentEvent('*', 1);
      const one = OrderPaymentEvent('abc', 2);
      expect(all.concerns('abc'), isTrue);
      expect(all.concerns('xyz'), isTrue);
      expect(one.concerns('abc'), isTrue);
      expect(one.concerns('xyz'), isFalse);
    });
  });
}
