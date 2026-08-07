enum CheckoutServiceType {
  collectFromHome('collect_from_home'),
  dropAtShop('drop_at_shop'),
  homeReception('home_reception');

  const CheckoutServiceType(this.apiValue);
  final String apiValue;
}

/// How the finished/clean order gets back to the customer — independent of
/// [CheckoutServiceType], which only governs how the dirty laundry is collected.
enum DeliveryType {
  homeDelivery('HOME_DELIVERY'),
  selfPickup('SELF_PICKUP');

  const DeliveryType(this.apiValue);
  final String apiValue;
}

enum CheckoutPaymentMethod {
  upi('upi', 'UPI'),
  creditCard('credit_card', 'Credit Card'),
  debitCard('debit_card', 'Debit Card'),
  netBanking('net_banking', 'Net Banking'),
  wallet('wallet', 'Wallets'),
  cashOnDelivery('cash_on_delivery', 'Cash on Delivery');

  const CheckoutPaymentMethod(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static CheckoutPaymentMethod fromApi(String value) {
    return CheckoutPaymentMethod.values.firstWhere(
      (method) => method.apiValue == value,
      orElse: () => CheckoutPaymentMethod.upi,
    );
  }
}

class CheckoutAddress {
  const CheckoutAddress({
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final String fullAddress;
  final double latitude;
  final double longitude;
  final String? label;

  Map<String, dynamic> toJson() => {
        'fullAddress': fullAddress,
        'latitude': latitude,
        'longitude': longitude,
        if (label != null) 'label': label,
      };
}

class ReceptionDetails {
  const ReceptionDetails({
    required this.receptionName,
    required this.flatVillaNumber,
    this.securityInstructions,
    this.pickupNotes,
  });

  final String receptionName;
  final String flatVillaNumber;
  final String? securityInstructions;
  final String? pickupNotes;

  Map<String, dynamic> toJson() => {
        'receptionName': receptionName,
        'flatVillaNumber': flatVillaNumber,
        if (securityInstructions?.isNotEmpty ?? false)
          'securityInstructions': securityInstructions,
        if (pickupNotes?.isNotEmpty ?? false) 'pickupNotes': pickupNotes,
      };
}

class CheckoutSlot {
  const CheckoutSlot({
    required this.date,
    required this.label,
    required this.startTime,
    required this.endTime,
    this.id,
    this.remainingCapacity,
    this.isInstant = false,
    this.expectedTurnaround,
  });

  final String date;
  final String? id;
  final String label;
  final String startTime;
  final String endTime;
  final int? remainingCapacity;
  /// True when this is the "Instant" option — partner arrives in ~15 min.
  final bool isInstant;
  /// Admin-defined turnaround string, e.g. "2–3 hrs" or "~15 min".
  final String? expectedTurnaround;

  /// True for the server-injected "Full Day" placeholder the backend returns
  /// only when the admin hasn't configured any real slots for the requested
  /// day. It is never a real bookable slot — scheduled-slot UIs must treat
  /// its presence the same as an empty slot list, not render it as a choice.
  bool get isFallback => id == 'full-day';

  factory CheckoutSlot.fromJson(Map<String, dynamic> json, String date) {
    return CheckoutSlot(
      date: date,
      id: json['_id'] as String?,
      label: json['label'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      remainingCapacity: (json['remainingCapacity'] as num?)?.toInt(),
      isInstant: json['isInstant'] == true,
      expectedTurnaround: json['expectedTurnaround'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'label': label,
        'startTime': startTime,
        'endTime': endTime,
        if (isInstant) 'isInstant': true,
      };
}

/// Result from GET /standard-time-slots/available
class StandardSlotsResult {
  const StandardSlotsResult({
    required this.date,
    required this.pickupSlots,
    required this.deliverySlots,
  });

  final String date;
  final List<CheckoutSlot> pickupSlots;
  final List<CheckoutSlot> deliverySlots;

  factory StandardSlotsResult.fromJson(Map<String, dynamic> json, String date) {
    final d = json['date'] as String? ?? date;
    return StandardSlotsResult(
      date: d,
      pickupSlots: (json['pickupSlots'] as List? ?? [])
          .map((s) => CheckoutSlot.fromJson(s as Map<String, dynamic>, d))
          .toList(),
      deliverySlots: (json['deliverySlots'] as List? ?? [])
          .map((s) => CheckoutSlot.fromJson(s as Map<String, dynamic>, d))
          .toList(),
    );
  }
}

class CheckoutShop {
  const CheckoutShop({
    required this.id,
    required this.shopName,
    required this.fullAddress,
    this.distanceKm,
    this.isOpen = true,
    this.recommended = false,
    this.unavailableReason,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String shopName;
  final String fullAddress;
  final double? distanceKm;
  final bool isOpen;
  final bool recommended;
  final String? unavailableReason;
  /// Shop's own GPS coordinates — used in Drop at Shop flow so the
  /// serviceability check uses the shop's location (distance = 0) instead of
  /// the user's home address, which could be outside the pickup radius.
  final double? latitude;
  final double? longitude;

  factory CheckoutShop.fromLocationJson(Map<String, dynamic> json) {
    final shop = json['shop'] is Map<String, dynamic>
        ? json['shop'] as Map<String, dynamic>
        : json;
    return CheckoutShop(
      id: shop['_id'] ?? '',
      shopName: shop['shopName'] ?? '',
      fullAddress: shop['fullAddress'] ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      isOpen: json['isOpen'] ?? true,
      recommended: json['recommended'] ?? false,
      unavailableReason: json['unavailableReason'],
      latitude: (shop['latitude'] as num?)?.toDouble(),
      longitude: (shop['longitude'] as num?)?.toDouble(),
    );
  }
}

class CheckoutOptions {
  const CheckoutOptions({
    required this.shop,
    required this.pickupSlots,
    required this.deliverySlots,
    required this.paymentMethods,
    this.distanceKm,
    this.estimatedPickupTime,
    this.availabilityWarning,
  });

  final CheckoutShop shop;
  final double? distanceKm;
  final String? estimatedPickupTime;
  final List<CheckoutSlot> pickupSlots;
  final List<CheckoutSlot> deliverySlots;
  final List<CheckoutPaymentMethod> paymentMethods;

  /// Non-null when the nearest shop has a temporary availability issue
  /// (e.g. daily capacity reached, closed today). The user can still proceed —
  /// the backend will re-validate at order creation time.
  final String? availabilityWarning;

  /// Fallback used when the serviceability API is unavailable (403/404/network).
  /// Slots are left empty so the backend does not enforce a slot label —
  /// the location itself will determine whether slot matching is required.
  static CheckoutOptions assumed(String date) {
    return CheckoutOptions(
      shop: const CheckoutShop(
        id: 'default',
        shopName: 'LaundryBrew Branch',
        fullAddress: 'Nearest available branch',
        isOpen: true,
        recommended: true,
      ),
      distanceKm: null,
      estimatedPickupTime: '2–3 hrs',
      pickupSlots:   [],
      deliverySlots: [],
      paymentMethods: CheckoutPaymentMethod.values.toList(),
    );
  }

  factory CheckoutOptions.fromServiceabilityJson(
    Map<String, dynamic> json,
    String date,
  ) {
    final shop = json['shop'] as Map<String, dynamic>;
    return CheckoutOptions(
      shop: CheckoutShop.fromLocationJson(shop),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      estimatedPickupTime: json['estimatedPickupTime'],
      pickupSlots: (json['pickupSlots'] as List? ?? [])
          .map((slot) => CheckoutSlot.fromJson(slot, date))
          .toList(),
      deliverySlots: (json['deliverySlots'] as List? ?? [])
          .map((slot) => CheckoutSlot.fromJson(slot, date))
          .toList(),
      paymentMethods: (json['paymentMethods'] as List? ?? [])
          .map((method) => CheckoutPaymentMethod.fromApi(method.toString()))
          .toList(),
    );
  }
}

/// Lightweight yes/no result of a raw lat/lng serviceability check — used
/// wherever a location needs to be validated against shop coverage without
/// building a full [CheckoutOptions] (e.g. picking a return-delivery address
/// from saved addresses, where there's no slot/payment info to resolve yet).
class ServiceabilityCheck {
  const ServiceabilityCheck({
    required this.serviceable,
    this.reason,
    this.checkSkipped = false,
  });

  /// True when the location is within a shop's service radius (or the check
  /// itself couldn't run — see [checkSkipped] — so we don't block the user).
  final bool serviceable;

  /// Human-readable reason when [serviceable] is false.
  final String? reason;

  /// True when the backend check couldn't be completed (network/5xx/endpoint
  /// missing) and [serviceable] was defaulted to true so a transient error
  /// never blocks address selection — matches the fallback already used by
  /// the pin-drop location picker's serviceability check.
  final bool checkSkipped;
}

class CheckoutContext {
  const CheckoutContext({
    required this.serviceType,
    required this.paymentMethod,
    required this.expectedAmount,
    this.pickupSlot,
    this.deliverySlot,
    this.pickupAddress,
    this.receptionDetails,
    this.selectedShop,
    this.assignedShop,
  });

  final CheckoutServiceType serviceType;
  final CheckoutAddress? pickupAddress;
  final ReceptionDetails? receptionDetails;
  final CheckoutShop? selectedShop;
  final CheckoutShop? assignedShop;
  final CheckoutSlot? pickupSlot;
  final CheckoutSlot? deliverySlot;
  final CheckoutPaymentMethod paymentMethod;
  final double expectedAmount;

  Map<String, dynamic> toJson() => {
        'serviceType': serviceType.apiValue,
        if (assignedShop != null) 'locationId': assignedShop!.id,
        if (assignedShop == null && selectedShop != null)
          'locationId': selectedShop!.id,
        if (pickupAddress != null) 'address': pickupAddress!.fullAddress,
        if (pickupAddress != null) 'pickupLatitude': pickupAddress!.latitude,
        if (pickupAddress != null) 'pickupLongitude': pickupAddress!.longitude,
        if (pickupSlot != null) 'pickupDate': pickupSlot!.date,
        // Don't send pickupTime for Instant slots (startTime is empty/null)
        if (pickupSlot != null && pickupSlot!.startTime.isNotEmpty)
          'pickupTime': pickupSlot!.startTime,
        if (pickupSlot != null) 'pickupSlot': pickupSlot!.label,
        if (deliverySlot != null) 'deliverySlot': deliverySlot!.label,
        if (pickupAddress != null) 'pickupAddress': pickupAddress!.toJson(),
        if (receptionDetails != null)
          'receptionDetails': receptionDetails!.toJson(),
        if (selectedShop != null) 'selectedShopId': selectedShop!.id,
        'paymentMethod': paymentMethod.apiValue,
        'expectedAmount': expectedAmount,
      };
}
