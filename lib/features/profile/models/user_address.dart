import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class UserAddress {
  final String  id;
  final String? houseNo;
  final String? buildingName;
  final String? street;
  final String? area;
  final String? landmark;
  final String? city;
  final String? state;
  final String? pincode;
  final String  type;
  final String? instructions;
  final bool    isDefault;
  final double? lat;
  final double? lng;

  const UserAddress({
    required this.id,
    this.houseNo,
    this.buildingName,
    this.street,
    this.area,
    this.landmark,
    this.city,
    this.state,
    this.pincode,
    this.type      = 'Home',
    this.instructions,
    this.isDefault = false,
    this.lat,
    this.lng,
  });

  factory UserAddress.fromJson(Map<String, dynamic> j) => UserAddress(
        id:           j['id']  as String? ?? j['_id'] as String? ?? '',
        houseNo:      j['houseNo']      as String?,
        buildingName: j['buildingName'] as String?,
        street:       j['street']       as String?,
        area:         j['area']         as String?,
        landmark:     j['landmark']     as String?,
        city:         j['city']         as String?,
        state:        j['state']        as String?,
        pincode:      j['pincode']      as String?,
        type:         j['type']         as String? ?? 'Home',
        instructions: j['instructions'] as String?,
        isDefault:    j['isDefault']    as bool?   ?? false,
        lat:          (j['lat']  as num?)?.toDouble(),
        lng:          (j['lng']  as num?)?.toDouble(),
      );

  /// Single-line display string.
  String get fullLine {
    return [houseNo, buildingName, street, area, city, state, pincode]
        .where((s) => s != null && s!.isNotEmpty)
        .join(', ');
  }

  /// Pre-fills the form's combined address textarea.
  String get addressLine {
    return [houseNo, buildingName, street, area]
        .where((s) => s != null && s!.isNotEmpty)
        .join(', ');
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AddressService {
  final Dio _dio = ApiClient.instance;

  Future<List<UserAddress>> getAll() async {
    final res  = await _dio.get('/user/addresses');
    final body = res.data as Map<String, dynamic>;
    final list = body['data'] as List? ?? [];
    return list.map((e) => UserAddress.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserAddress> create(Map<String, dynamic> data) async {
    final res  = await _dio.post('/user/addresses', data: data);
    final body = res.data as Map<String, dynamic>;
    return UserAddress.fromJson(body['address'] as Map<String, dynamic>);
  }

  Future<UserAddress> update(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/user/addresses/$id', data: data);
    return UserAddress.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/user/addresses/$id');
  }

  Future<List<UserAddress>> setDefault(String id) async {
    await _dio.put('/user/addresses/$id/default');
    return getAll();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final addressesProvider =
    AsyncNotifierProvider<AddressesNotifier, List<UserAddress>>(
  AddressesNotifier.new,
);

class AddressesNotifier extends AsyncNotifier<List<UserAddress>> {
  final _svc = AddressService();

  @override
  Future<List<UserAddress>> build() => _svc.getAll();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_svc.getAll);
  }

  Future<void> delete(String id) async {
    await _svc.delete(id);
    state = await AsyncValue.guard(_svc.getAll);
  }

  Future<void> setDefault(String id) async {
    state = AsyncValue.data(await _svc.setDefault(id));
  }
}
