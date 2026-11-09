import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../features/auth/providers/auth_provider.dart';
import '../../features/orders/providers/orders_provider.dart';
import '../api/api_client.dart';

/// "Something about this order's payment changed — go refetch it."
///
/// The payload is only ever a *hint*: screens react by re-reading the order
/// from the API, so a spoofed/duplicated/out-of-order event can never make
/// the UI claim a payment succeeded. [orderId] is `'*'` for "refresh
/// everything" (app resumed, socket reconnected).
class OrderPaymentEvent {
  final String orderId;

  /// Monotonic counter so two consecutive events for the same order are
  /// still distinct state changes (Riverpod would otherwise dedupe them).
  final int seq;

  const OrderPaymentEvent(this.orderId, this.seq);

  bool concerns(String id) => orderId == '*' || orderId == id;
}

class OrderPaymentEventNotifier extends Notifier<OrderPaymentEvent?> {
  int _seq = 0;

  @override
  OrderPaymentEvent? build() => null;

  void emit(String orderId) => state = OrderPaymentEvent(orderId, ++_seq);
}

final orderPaymentEventProvider =
    NotifierProvider<OrderPaymentEventNotifier, OrderPaymentEvent?>(
  OrderPaymentEventNotifier.new,
);

/// Keeps one authenticated socket open for the signed-in customer so a
/// payment confirmed server-side (signed webhook, even while this app was in
/// the background or the customer's phone was offline) shows up on screen
/// with no manual refresh. Watch this provider once, from the app root.
///
/// Belt and braces, because sockets drop: on every (re)connect and every app
/// resume it also triggers a full refresh, and the order detail screen polls
/// the server-verified payment status while a payment is outstanding.
final orderRealtimeProvider = Provider<void>((ref) {
  final token = ref.watch(authProvider.select((s) => s.token));
  if (token == null || token.isEmpty) return;

  void refreshEverything() {
    ref.read(ordersProvider.notifier).fetchOrders();
    ref.read(orderPaymentEventProvider.notifier).emit('*');
  }

  void onPaymentChanged(dynamic payload) {
    final id = payload is Map
        ? (payload['_id'] ?? payload['orderId'])?.toString()
        : null;
    ref.read(ordersProvider.notifier).fetchOrders();
    ref.read(orderPaymentEventProvider.notifier).emit(id ?? '*');
  }

  final socket = io.io(
    ApiClient.baseUrl.replaceFirst(RegExp(r'/$'), ''),
    io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(15000)
        .disableAutoConnect()
        .build(),
  );

  var connectedBefore = false;
  socket.onConnect((_) {
    // Anything that happened while we were disconnected was missed — catch up.
    if (connectedBefore) refreshEverything();
    connectedBefore = true;
  });
  socket.on('order:payment_updated', onPaymentChanged);
  socket.on('order:payment_qr_updated', onPaymentChanged);
  socket.connect();

  final observer = _ResumeObserver(refreshEverything);
  WidgetsBinding.instance.addObserver(observer);

  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    socket
      ..off('order:payment_updated')
      ..off('order:payment_qr_updated')
      ..dispose();
  });
});

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResume);
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
