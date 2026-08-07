/// The two order flows a customer can book a service through. Mirrors the
/// 'instant' / 'scheduled' strings used in [ServiceModel.categories] and
/// throughout the cart/pickup-delivery plumbing.
enum ServiceCategory {
  instant,
  scheduled;

  /// Parses a raw 'instant' | 'scheduled' string (as used by cart/category
  /// state that is still string-typed) into a [ServiceCategory]. Falls back
  /// to [instant] for any other value, matching [ServiceModel.isInstant]'s
  /// existing instant-first default.
  factory ServiceCategory.fromValue(String value) =>
      value == 'scheduled' ? ServiceCategory.scheduled : ServiceCategory.instant;
}

class ServiceModel {
  final String id;
  final String name;
  final double price;
  final String instantDescription;
  final String scheduledDescription;

  /// Admin-authored message shown on the Order Placed screen for Instant bookings.
  final String instantOrderPlacedMessage;

  /// Admin-authored message shown on the Order Placed screen for Scheduled bookings.
  final String scheduledOrderPlacedMessage;
  final String? icon;
  final String? imageUrl;
  final List<String> categories;

  /// Estimated duration text shown to customers browsing the Instant (same-day) flow, e.g. "60-90 mins".
  final String? instantDuration;

  /// Estimated duration text shown to customers browsing the Scheduled (time-slot) flow, e.g. "24-48 hrs".
  final String? scheduledDuration;

  /// Hours between pickup and delivery for scheduled orders (e.g. 24, 48). Defaults to 24.
  final int turnaroundHours;

  /// Minutes between pickup and delivery for instant orders (e.g. 60, 90). Defaults to 90.
  final int instantTurnaroundMinutes;
  final bool isAvailable;
  final bool isPopular;
  final int? popularOrder;

  ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    required this.instantDescription,
    required this.scheduledDescription,
    required this.instantOrderPlacedMessage,
    required this.scheduledOrderPlacedMessage,
    this.icon,
    this.imageUrl,
    this.categories = const [],
    this.instantDuration,
    this.scheduledDuration,
    this.turnaroundHours = 24,
    this.instantTurnaroundMinutes = 90,
    this.isAvailable = true,
    this.isPopular = false,
    this.popularOrder,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    // Parse categories array; fall back to legacy 'category' string field
    List<String> cats = const [];
    final rawCats = json['categories'];
    if (rawCats is List) {
      cats = rawCats.whereType<String>().toList();
    } else {
      // Legacy: single string field
      final legacy = json['category'] as String?;
      if (legacy != null && legacy.isNotEmpty) cats = [legacy];
    }

    return ServiceModel(
      id: json['_id'] as String,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      // Legacy documents (pre instant/scheduled split) only have a flat
      // `description` field — fall back to it, then to '', so a service
      // that hasn't been backfilled yet still renders instead of crashing.
      instantDescription: (json['instantDescription'] ?? json['description'])
              as String? ??
          '',
      scheduledDescription:
          (json['scheduledDescription'] ?? json['description']) as String? ??
              '',
      instantOrderPlacedMessage:
          json['instantOrderPlacedMessage'] as String? ?? '',
      scheduledOrderPlacedMessage:
          json['scheduledOrderPlacedMessage'] as String? ?? '',
      icon: json['icon'] as String?,
      imageUrl: json['imageUrl'] as String?,
      categories: cats,
      // Legacy documents (pre instant/scheduled split) only have a flat
      // `duration` field — fall back to it, same pattern as the descriptions
      // above, so a service that hasn't been backfilled yet still renders.
      instantDuration:
          (json['instantDuration'] ?? json['duration']) as String?,
      scheduledDuration:
          (json['scheduledDuration'] ?? json['duration']) as String?,
      turnaroundHours: (json['turnaroundHours'] as num?)?.toInt() ?? 24,
      instantTurnaroundMinutes:
          (json['instantTurnaroundMinutes'] as num?)?.toInt() ?? 90,
      isAvailable: json['isAvailable'] as bool? ?? true,
      isPopular: json['isPopular'] as bool? ?? false,
      popularOrder: (json['popularOrder'] as num?)?.toInt(),
    );
  }

  /// Whether this service is available for instant (same-day) pickup.
  bool get isInstant => categories.contains('instant');

  /// Whether this service supports scheduled (time-slot) booking.
  bool get isScheduled => categories.contains('scheduled');

  /// The customer-facing description for the given order type. Callers
  /// should never read [instantDescription] / [scheduledDescription]
  /// directly when rendering a specific order-type flow — always go through
  /// this so the two never get mixed up.
  String descriptionFor(ServiceCategory category) => switch (category) {
        ServiceCategory.scheduled => scheduledDescription,
        ServiceCategory.instant => instantDescription,
      };

  /// The admin-authored Order Placed screen message for the given order
  /// type. Purely a lookup — no calculation, no defaults derived from
  /// [instantDuration]/[scheduledDuration] or [turnaroundHours].
  String orderPlacedMessageFor(ServiceCategory category) => switch (category) {
        ServiceCategory.scheduled => scheduledOrderPlacedMessage,
        ServiceCategory.instant => instantOrderPlacedMessage,
      };

  /// The customer-facing estimated-duration text for the given order type.
  /// Free text only — never parsed, never drives delivery-date math (that's
  /// [turnaroundHours]/[instantTurnaroundMinutes]'s job).
  String? durationFor(ServiceCategory category) => switch (category) {
        ServiceCategory.scheduled => scheduledDuration,
        ServiceCategory.instant => instantDuration,
      };

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'price': price,
      'instantDescription': instantDescription,
      'scheduledDescription': scheduledDescription,
      'instantOrderPlacedMessage': instantOrderPlacedMessage,
      'scheduledOrderPlacedMessage': scheduledOrderPlacedMessage,
      if (icon != null) 'icon': icon,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'categories': categories,
      if (instantDuration != null) 'instantDuration': instantDuration,
      if (scheduledDuration != null) 'scheduledDuration': scheduledDuration,
      'turnaroundHours': turnaroundHours,
      'instantTurnaroundMinutes': instantTurnaroundMinutes,
      'isAvailable': isAvailable,
      'isPopular': isPopular,
      if (popularOrder != null) 'popularOrder': popularOrder,
    };
  }
}
