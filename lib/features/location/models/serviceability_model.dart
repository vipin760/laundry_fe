class ServiceabilityResult {
  const ServiceabilityResult({
    required this.isServiceable,
    this.estimatedTime,
    this.zone,
    this.message,
    this.isUnverified = false,
  });

  final bool isServiceable;
  final String? estimatedTime; // e.g. "30 – 60 mins"
  final String? zone;          // e.g. "Zone A"
  final String? message;       // shown when not serviceable

  /// True when the check never completed (network/server error) — as opposed
  /// to completing and finding no coverage. Distinct so the UI can offer a
  /// retry instead of telling the user either that we deliver (we don't know)
  /// or that we don't (we didn't ask).
  final bool isUnverified;

  factory ServiceabilityResult.fromJson(Map<String, dynamic> json) {
    return ServiceabilityResult(
      isServiceable:
          json['isServiceable'] ?? json['serviceable'] ?? false,
      estimatedTime: json['estimatedTime'] ?? json['eta'],
      zone: json['zone'] ?? json['deliveryZone'],
      message: json['message'],
    );
  }

  /// Used when the serviceability check could not be completed.
  ///
  /// Deliberately not `isServiceable: true`: claiming coverage for a location
  /// that was never actually checked sends the user down a checkout they may
  /// not be able to finish, and is contradicted later by the server-side
  /// re-check at scheduling.
  static const ServiceabilityResult unverified = ServiceabilityResult(
    isServiceable: false,
    isUnverified: true,
    message: "We couldn't check delivery availability for this location. "
        'Please check your connection and try again.',
  );
}
