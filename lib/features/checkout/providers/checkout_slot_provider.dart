import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/checkout_models.dart';

/// Pickup slot chosen on the Pickup & Delivery (Scheduled tab) screen.
/// Carried into the scheduling/checkout flow so the user is not asked to
/// pick the time again — delivery is derived from it (next day, same slot).
class SelectedPickupSlotNotifier extends Notifier<CheckoutSlot?> {
  @override
  CheckoutSlot? build() => null;

  void set(CheckoutSlot? slot) => state = slot;
  void clear() => state = null;
}

final selectedPickupSlotProvider =
    NotifierProvider<SelectedPickupSlotNotifier, CheckoutSlot?>(
        SelectedPickupSlotNotifier.new);
