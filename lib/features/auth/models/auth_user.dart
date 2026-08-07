class AuthUser {
  const AuthUser({
    this.id,
    this.email,
    required this.mobileNumber,
    this.name,
    this.role,
    this.photoUrl,
  });

  final String? id;
  final String? email;
  final String mobileNumber;
  final String? name;
  final String? role;
  final String? photoUrl;

  bool get isAdmin => role?.toLowerCase() == 'admin';

  bool get isDeliveryPartner => role?.toLowerCase() == 'delivery_partner';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      email: json['email']?.toString(),
      mobileNumber: (json['mobileNumber'] ??
              json['phone'] ??
              json['mobile'] ??
              '')
          .toString(),
      name: json['name']?.toString(),
      role: json['role']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'mobileNumber': mobileNumber,
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
    };
  }

  AuthUser copyWith({
    String? id,
    String? email,
    String? mobileNumber,
    String? name,
    String? role,
    String? photoUrl,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      name: name ?? this.name,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
