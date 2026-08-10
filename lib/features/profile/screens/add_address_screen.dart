import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../../location/models/address_model.dart';

const _kBlue   = Color(0xFF2453FF);
const _kBorder = Color(0xFFDDE1EE);
const _kIcon   = Color(0xFF9BA3C0);
const _kText   = Color(0xFF1A1D2E);
const _kHint   = Color(0xFFB0B7CC);

class AddAddressScreen extends StatefulWidget {
  final AddressModel? existing;
  const AddAddressScreen({super.key, this.existing});
  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _nameCtrl     = TextEditingController();
  final _mobileCtrl   = TextEditingController();
  final _pincodeCtrl  = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _stateCtrl    = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  String  _type     = 'Home';
  bool    _saving   = false;
  bool    _locating = false;
  bool    _fetching = false;
  double? _lat, _lng;

  String? _cityError;

  // True while City/State still hold the Bengaluru/Karnataka default rather
  // than a value the user typed or GPS/pincode resolved — lets those lookups
  // override the default even though it made the fields non-empty.
  bool _cityStateDefaulted = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _addressCtrl.text  = [a.houseNo, a.buildingName, a.street, a.area]
          .where((s) => s.isNotEmpty).join(', ');
      _pincodeCtrl.text  = a.pincode;
      _cityCtrl.text     = a.city;
      _stateCtrl.text    = a.state;
      _landmarkCtrl.text = a.landmark;
      _type = a.type;
      _lat  = a.lat;
      _lng  = a.lng;
    } else {
      _cityCtrl.text      = 'Bengaluru';
      _stateCtrl.text     = 'Karnataka';
      _cityStateDefaulted = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();    _mobileCtrl.dispose();
    _pincodeCtrl.dispose(); _addressCtrl.dispose();
    _cityCtrl.dispose();    _stateCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  // ── Pincode Fetch ──────────────────────────────────────────────────────────

  Future<void> _fetchPin() async {
    final pin = _pincodeCtrl.text.trim();
    if (pin.length != 6) { _toast('Enter a valid 6-digit PIN first'); return; }
    setState(() => _fetching = true);
    try {
      final res  = await Dio().get('https://api.postalpincode.in/pincode/$pin');
      final body = (res.data as List).first as Map;
      if (body['Status'] == 'Success') {
        final po = (body['PostOffice'] as List).first as Map;
        setState(() {
          final district = po['District'] as String? ?? '';
          final state    = po['State']    as String? ?? '';
          if ((_cityCtrl.text.trim().isEmpty || _cityStateDefaulted) && district.isNotEmpty) {
            _cityCtrl.text = district;
          }
          if ((_stateCtrl.text.trim().isEmpty || _cityStateDefaulted) && state.isNotEmpty) {
            _stateCtrl.text = state;
          }
          _cityStateDefaulted = false;
        });
        _toast('Address filled from PIN!', ok: true);
      } else {
        _toast('No results for PIN $pin');
      }
    } catch (e, stackTrace) {
      debugPrint('[Location] pincode fetch failed: $e\n$stackTrace');
      _toast('Could not fetch. Check connection.');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  // ── GPS ────────────────────────────────────────────────────────────────────

  Future<void> _gps() async {
    setState(() => _locating = true);

    // Permission/services handling (with Settings deep-links on denied-
    // forever / services-off) lives in the shared service now. The manual
    // fields below stay editable regardless, so a null result just leaves
    // the user to type the address in themselves.
    final pos = await LocationPermissionService.getCurrentPosition(
      context,
      timeout: const Duration(seconds: 10),
    );
    if (pos == null) {
      if (mounted) setState(() => _locating = false);
      return;
    }

    // ── Step 2: reverse geocode.
    try {
      final marks =
          await GeocodingService.instance.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isEmpty) {
        _toast('Could not resolve address');
        return;
      }
      final m = marks.first;
      setState(() {
        _lat = pos.latitude; _lng = pos.longitude;
        final city  = m.locality           ?? '';
        final state = m.administrativeArea ?? '';
        if (_pincodeCtrl.text.trim().isEmpty)  _pincodeCtrl.text  = m.postalCode        ?? '';
        if ((_cityCtrl.text.trim().isEmpty || _cityStateDefaulted) && city.isNotEmpty)   _cityCtrl.text  = city;
        if ((_stateCtrl.text.trim().isEmpty || _cityStateDefaulted) && state.isNotEmpty) _stateCtrl.text = state;
        _cityStateDefaulted = false;
        if (_landmarkCtrl.text.trim().isEmpty) _landmarkCtrl.text = m.name               ?? '';
        if (_addressCtrl.text.trim().isEmpty) {
          _addressCtrl.text =
              [m.subThoroughfare, m.thoroughfare, m.subLocality]
                  .where((s) => s != null && s.isNotEmpty).join(', ');
        }
      });
      _toast('Location detected!', ok: true);
    } catch (e, stackTrace) {
      debugPrint('[Location] reverse geocode failed: $e\n$stackTrace');
      // GPS succeeded even though reverse geocoding failed — keep the
      // coordinates so serviceability/nearby-shop lookups still work.
      _lat = pos.latitude;
      _lng = pos.longitude;
      _toast('Location found, but address lookup failed. Please fill it in manually.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Basic validation
    if (_cityCtrl.text.trim().isEmpty) {
      setState(() => _cityError = 'City is required');
      return;
    }
    if (_pincodeCtrl.text.trim().isNotEmpty && _pincodeCtrl.text.trim().length != 6) {
      _toast('Enter a valid 6-digit PIN'); return;
    }
    setState(() { _saving = true; _cityError = null; });

    // Always send every field so the backend does a clean full-replacement.
    // houseNo / buildingName / area are intentionally empty — the combined
    // address text lives entirely in `street`.
    final body = <String, dynamic>{
      'type':         _type,
      'houseNo':      '',
      'buildingName': '',
      'street':       _addressCtrl.text.trim(),
      'area':         '',
      'city':         _cityCtrl.text.trim(),
      'state':        _stateCtrl.text.trim(),
      'pincode':      _pincodeCtrl.text.trim(),
      'landmark':     _landmarkCtrl.text.trim(),
      'instructions': '',
      if (_lat != null) 'lat': _lat,
      if (_lng != null) 'lng': _lng,
    };
    try {
      final dio = ApiClient.instance;
      if (widget.existing?.id != null) {
        await dio.put('/user/addresses/${widget.existing!.id}', data: body);
      } else {
        await dio.post('/user/addresses', data: body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('[Location] save address failed: $e\n$stackTrace');
      setState(() => _saving = false);
      _toast('Failed: ${e.toString().split('\n').first}');
    }
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? _kBlue : Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kText),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          isEdit ? 'Edit Address' : 'Add New Address',
          style: const TextStyle(color: _kText, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Fill the details to save your address',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
          ]),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Address Type Card ────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Address Type',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _typeChip('Home',  Icons.home_rounded),
                      const SizedBox(width: 10),
                      _typeChip('Work',  Icons.work_outline_rounded),
                      const SizedBox(width: 10),
                      _typeChip('Other', Icons.location_on_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Full Name ────────────────────────────────────────────────
            _FieldLabel('Full Name'),
            _InputBox(ctrl: _nameCtrl, hint: 'Enter full name', icon: Icons.person_outline_rounded),
            const SizedBox(height: 16),

            // ── Mobile ───────────────────────────────────────────────────
            _FieldLabel('Mobile Number'),
            _MobileBox(ctrl: _mobileCtrl),
            const SizedBox(height: 16),

            // ── Pincode ──────────────────────────────────────────────────
            _FieldLabel('Pincode'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _InputBox(
                    ctrl: _pincodeCtrl,
                    hint: 'Enter pincode',
                    icon: Icons.location_on_outlined,
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  ),
                ),
                const SizedBox(width: 10),
                _FetchBtn(loading: _fetching, onTap: _fetchPin),
              ],
            ),
            const SizedBox(height: 16),

            // ── OR divider ────────────────────────────────────────────────
            _OrDivider(),
            const SizedBox(height: 14),

            // ── Use Current Location ──────────────────────────────────────
            _LocationRow(loading: _locating, onTap: _gps),
            const SizedBox(height: 20),

            // ── Address ──────────────────────────────────────────────────
            _FieldLabel('Address'),
            _AddressBox(ctrl: _addressCtrl),
            const SizedBox(height: 16),

            // ── City / State ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('City / Town'),
                      _InputBox(
                        ctrl: _cityCtrl,
                        hint: 'Select city',
                        icon: Icons.location_city_outlined,
                        suffix: const Icon(Icons.keyboard_arrow_down_rounded, color: _kIcon, size: 20),
                        errorText: _cityError,
                        onChanged: (_) => setState(() { _cityError = null; _cityStateDefaulted = false; }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('State'),
                      _InputBox(
                        ctrl: _stateCtrl,
                        hint: 'Select state',
                        icon: Icons.location_on_outlined,
                        suffix: const Icon(Icons.keyboard_arrow_down_rounded, color: _kIcon, size: 20),
                        onChanged: (_) => setState(() => _cityStateDefaulted = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Landmark ─────────────────────────────────────────────────
            _FieldLabel('Landmark (Optional)'),
            _InputBox(
              ctrl: _landmarkCtrl,
              hint: 'Nearby landmark, e.g. Near Metro Station',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 28),

            // ── Save Button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor: _kBlue.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(
                        isEdit ? 'Update Address' : 'Save Address',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Address type chip ──────────────────────────────────────────────────────

  Widget _typeChip(String label, IconData icon) {
    final active = _type == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _kBlue : _kBorder, width: active ? 1.8 : 1.2),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: active ? _kBlue : _kIcon),
            const SizedBox(width: 5),
            Expanded(
              child: Text(label, style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600,
                color: active ? _kBlue : Colors.grey[600],
              )),
            ),
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: active ? _kBlue : _kBorder, width: 2),
                color: active ? _kBlue : Colors.transparent,
              ),
              child: active
                  ? const Center(child: Icon(Icons.circle, size: 5, color: Colors.white))
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
      );
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.formatters,
    this.suffix,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController    ctrl;
  final String                   hint;
  final IconData                 icon;
  final TextInputType?           keyboard;
  final List<TextInputFormatter>? formatters;
  final Widget?                  suffix;
  final String?                  errorText;
  final ValueChanged<String>?    onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller:      ctrl,
        keyboardType:    keyboard,
        inputFormatters: formatters,
        onChanged:       onChanged,
        style: const TextStyle(fontSize: 14, color: _kText, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText:    hint,
          hintStyle:   const TextStyle(color: _kHint, fontSize: 13.5),
          errorText:   errorText,
          prefixIcon:  Icon(icon, size: 20, color: _kIcon),
          suffixIcon:  suffix,
          filled:      true,
          fillColor:   Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBlue, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBlue, width: 1.6),
          ),
        ),
      );
}

class _MobileBox extends StatelessWidget {
  const _MobileBox({required this.ctrl});
  final TextEditingController ctrl;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: _kBorder))),
            child: Row(children: [
              Icon(Icons.phone_outlined, size: 18, color: _kIcon),
              const SizedBox(width: 6),
              const Text('+91', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kText)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _kIcon),
            ]),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kText),
              decoration: const InputDecoration(
                hintText: 'Enter mobile number',
                hintStyle: TextStyle(color: _kHint, fontSize: 13.5),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              ),
            ),
          ),
        ]),
      );
}

class _FetchBtn extends StatelessWidget {
  const _FetchBtn({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Fetch Address',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ]);
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Row(children: [
            SizedBox(
              width: 24, height: 24,
              child: loading
                  ? const CircularProgressIndicator(strokeWidth: 2.2, color: _kBlue)
                  : const Icon(Icons.my_location_rounded, color: _kBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loading ? 'Detecting location…' : 'Use My Current Location',
                    style: const TextStyle(color: _kBlue, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text('Detect your location automatically',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ]),
        ),
      );
}

class _AddressBox extends StatefulWidget {
  const _AddressBox({required this.ctrl});
  final TextEditingController ctrl;
  @override
  State<_AddressBox> createState() => _AddressBoxState();
}

class _AddressBoxState extends State<_AddressBox> {
  int _len = 0;
  @override
  void initState() {
    super.initState();
    _len = widget.ctrl.text.length;
    widget.ctrl.addListener(_upd);
  }
  void _upd() => setState(() => _len = widget.ctrl.text.length);
  @override
  void dispose() { widget.ctrl.removeListener(_upd); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(Icons.location_city_outlined, size: 20, color: _kIcon),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.ctrl,
                maxLines:   4,
                maxLength:  200,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                style: const TextStyle(fontSize: 14, color: _kText),
                decoration: const InputDecoration(
                  hintText: 'House no., Building, Street, Area',
                  hintStyle: TextStyle(color: _kHint, fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
          Text('$_len/200', style: const TextStyle(color: _kHint, fontSize: 11.5)),
        ]),
      );
}
