class ClothTypeModel {
  final String id;
  final String name;
  final String? category; // ironing | shoeCleaning | dryCleaning | washFold | washIron | membership
  final String? subcategory; // unisex | men | women | kids | household | delicate | package | plan | ironPass | smartPass | combo
  final double instantRate;
  final double scheduledRate;
  final double? discountInstantRate;
  final double? discountScheduledRate;
  final bool isActive;
  final String? description;
  final List<String>? includes;
  final List<String>? excludedItems;
  final int? validityDays;

  const ClothTypeModel({
    required this.id,
    required this.name,
    this.category,
    this.subcategory,
    required this.instantRate,
    required this.scheduledRate,
    this.discountInstantRate,
    this.discountScheduledRate,
    this.isActive = true,
    this.description,
    this.includes,
    this.excludedItems,
    this.validityDays,
  });

  factory ClothTypeModel.fromJson(Map<String, dynamic> json) {
    return ClothTypeModel(
      id: json['_id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unnamed item',
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      // Defaults to 0 (meaning "not offered for this service type", same
      // convention as an explicit 0 — see _pricingRowFor) rather than
      // throwing, so a stale/malformed document can't crash the whole list.
      instantRate: (json['instantRate'] as num?)?.toDouble() ?? 0,
      scheduledRate: (json['scheduledRate'] as num?)?.toDouble() ?? 0,
      discountInstantRate: (json['discountInstantRate'] as num?)?.toDouble(),
      discountScheduledRate: (json['discountScheduledRate'] as num?)?.toDouble(),
      isActive: json['isActive'] as bool? ?? true,
      description: json['description'] as String?,
      includes: (json['includes'] as List?)?.map((e) => e.toString()).toList(),
      excludedItems:
          (json['excludedItems'] as List?)?.map((e) => e.toString()).toList(),
      validityDays: (json['validityDays'] as num?)?.toInt(),
    );
  }

  bool get hasInstantDiscount => discountInstantRate != null;
  bool get hasScheduledDiscount => discountScheduledRate != null;

  double get effectiveInstantRate => discountInstantRate ?? instantRate;
  double get effectiveScheduledRate => discountScheduledRate ?? scheduledRate;
}
