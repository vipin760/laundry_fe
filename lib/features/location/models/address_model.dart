class AddressModel {
  const AddressModel({
    this.id,
    this.houseNo = '',
    this.buildingName = '',
    this.street = '',
    this.area = '',
    this.landmark = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.type = 'Home',
    this.instructions = '',
    this.isDefault = false,
    this.lat,
    this.lng,
  });

  final String? id;
  final String houseNo;
  final String buildingName;
  final String street;
  final String area;
  final String landmark;
  final String city;
  final String state;
  final String pincode;
  final String type;         // 'Home' | 'Work' | 'Other'
  final String instructions;
  final bool isDefault;
  final double? lat;
  final double? lng;

  // ── Display helpers ──────────────────────────────────────────────────────────

  String get line1 {
    return [houseNo, buildingName].where((s) => s.isNotEmpty).join(', ');
  }

  String get line2 {
    return [street, area, city, pincode]
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  String get fullAddress {
    return [houseNo, buildingName, street, area, landmark, city, state, pincode]
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  bool get isEmpty =>
      houseNo.isEmpty && street.isEmpty && area.isEmpty && city.isEmpty;

  // ── Serialisation ────────────────────────────────────────────────────────────

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: (json['id'] ?? json['_id'])?.toString(),
      houseNo: json['houseNo'] ?? json['house_no'] ?? '',
      buildingName: json['buildingName'] ?? json['building_name'] ?? '',
      street: json['street'] ?? '',
      area: json['area'] ?? json['locality'] ?? '',
      landmark: json['landmark'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: (json['pincode'] ?? json['postal_code'] ?? '').toString(),
      type: json['type'] ?? json['addressType'] ?? 'Home',
      instructions:
          json['instructions'] ?? json['deliveryInstructions'] ?? '',
      isDefault: json['isDefault'] ?? json['is_default'] ?? false,
      lat: (json['lat'] ?? json['latitude'] as num?)?.toDouble(),
      lng: (json['lng'] ?? json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'houseNo': houseNo,
        'buildingName': buildingName,
        'street': street,
        'area': area,
        'landmark': landmark,
        'city': city,
        'state': state,
        'pincode': pincode,
        'type': type,
        'instructions': instructions,
        'isDefault': isDefault,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  AddressModel copyWith({
    String? id,
    String? houseNo,
    String? buildingName,
    String? street,
    String? area,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    String? type,
    String? instructions,
    bool? isDefault,
    double? lat,
    double? lng,
  }) {
    return AddressModel(
      id: id ?? this.id,
      houseNo: houseNo ?? this.houseNo,
      buildingName: buildingName ?? this.buildingName,
      street: street ?? this.street,
      area: area ?? this.area,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      type: type ?? this.type,
      instructions: instructions ?? this.instructions,
      isDefault: isDefault ?? this.isDefault,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}
