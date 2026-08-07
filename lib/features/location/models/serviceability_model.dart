class ServiceabilityResult {
  const ServiceabilityResult({
    required this.isServiceable,
    this.estimatedTime,
    this.zone,
    this.message,
  });

  final bool isServiceable;
  final String? estimatedTime; // e.g. "30 – 60 mins"
  final String? zone;          // e.g. "Zone A"
  final String? message;       // shown when not serviceable

  factory ServiceabilityResult.fromJson(Map<String, dynamic> json) {
    return ServiceabilityResult(
      isServiceable:
          json['isServiceable'] ?? json['serviceable'] ?? false,
      estimatedTime: json['estimatedTime'] ?? json['eta'],
      zone: json['zone'] ?? json['deliveryZone'],
      message: json['message'],
    );
  }

  /// Fallback used when the serviceability API does not exist yet.
  static const ServiceabilityResult assumed = ServiceabilityResult(
    isServiceable: true,
    estimatedTime: '30 – 60 mins',
    zone: 'Zone A',
  );
}
