import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../referral/data/referral_api.dart';

import '../providers/auth_provider.dart';
import '../../../core/router/app_routes.dart';

// ── Primary brand colour ────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1A23CC);
const _kPrimaryDark = Color(0xFF0F1899);

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _nameController = TextEditingController();
  final _referralCodeController = TextEditingController();

  // 6 individual OTP box controllers + focus nodes
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _agreedToTerms = false;
  late final TapGestureRecognizer _termsTapRecognizer =
      TapGestureRecognizer()..onTap = () => context.push(AppRoutes.terms);
  late final TapGestureRecognizer _privacyTapRecognizer =
      TapGestureRecognizer()..onTap = () => context.push(AppRoutes.privacy);

  String get _otpValue =>
      _otpControllers.map((c) => c.text).join();

  /// Distribute a received/pasted code across the 6 boxes and auto-submit.
  void _fillOtp(String code) {
    final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return;
    for (var i = 0; i < 6; i++) {
      _otpControllers[i].text = i < digits.length ? digits[i] : '';
    }
    setState(() {});
    if (_otpValue.length == 6) {
      FocusScope.of(context).unfocus();
      _submit();
    }
  }

  @override
  void initState() {
    super.initState();
    // Navigation after login is handled exclusively by GoRouter's redirect
    // (via _AuthChangeNotifier + refreshListenable in app_router.dart).
    // Do NOT call _goHome() here — it races with the redirect and can cause
    // the app to stay stuck on the auth screen.
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _referralCodeController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  void _onOtpChanged(String value, int index) {
    // Autofill / paste can deliver the whole code into a single box.
    if (value.length > 1) {
      _fillOtp(value);
      return;
    }
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    // Auto-submit when all 6 filled
    if (_otpValue.length == 6) {
      FocusScope.of(context).unfocus();
      _submit();
    }
    setState(() {});
  }

  void _onOtpKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  void _clearOtp() {
    for (final c in _otpControllers) c.clear();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_agreedToTerms) return;
    final authState = ref.read(authProvider);
    // For OTP phase, validate boxes directly instead of form validator
    if (authState.isOtpSent && _otpValue.length < 6) {
      setState(() {});
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final mobileNumber = _mobileController.text.trim();

    if (!authState.isOtpSent) {
      // ✅ PHASE 1: Send OTP (keep original logic clean)
      final success = await ref
          .read(authProvider.notifier)
          .sendMobileOtp(mobileNumber);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent. Please check your SMS.'),
            backgroundColor: _kPrimary,
          ),
        );
      }
      return;
    }

    // ✅ PHASE 2: Verify OTP and create account
    final name = authState.isNewUser ? _nameController.text.trim() : null;
    await ref
        .read(authProvider.notifier)
        .verifyMobileOtp(mobileNumber, _otpValue.trim(), name: name);

    if (!mounted) return;

    // ✅ PHASE 3: Handle referral code for new users ONLY.
    // Uses the shared authenticated ApiClient (POST /referral/apply).
    // Referral codes for the new user themselves are generated server-side
    // at registration — no client call needed.
    if (authState.isNewUser && _referralCodeController.text.isNotEmpty) {
      try {
        await const ReferralApi().apply(_referralCodeController.text.trim());
        debugPrint('✓ Referral code applied');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✓ Referral applied! Rewards unlock after your first order.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Referral error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Referral code could not be applied: ${_referralErrorMessage(e)}',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  /// Extract a human-readable reason from a referral apply failure.
  String _referralErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
      }
      if (e.response?.statusCode == 404) return 'code not found';
    }
    return 'please try again from the Refer & Earn screen';
  }

  void _changeNumber() {
    ref.read(authProvider.notifier).resetOtpFlow();
    _nameController.clear();
    _referralCodeController.clear();
    _clearOtp();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    // Navigation is handled by GoRouter's redirect (app_router.dart).
    // When isAuthenticated becomes true, _AuthChangeNotifier fires
    // notifyListeners() → GoRouter re-evaluates redirect → navigates to /home.

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Clothing banner ─────────────────────────────────────────
                SizedBox(
                  height: screenHeight * 0.35,
                  child: Image.asset(
                    'assets/images/login_image.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                ),

                // ── Hero text block — tight to image ─────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: _kPrimary,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Let's get your laundry sorted",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Form section ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Mobile number field ───────────────────────────────
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        readOnly: authState.isOtpSent,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Mobile number',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 15,
                          ),
                          prefixIcon: GestureDetector(
                            onTap: () {}, // country picker placeholder
                            child: Container(
                              width: 78,
                              padding: const EdgeInsets.only(left: 16, right: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    '+91',
                                    style: TextStyle(
                                      color: _kPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: _kPrimary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 16,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: _kPrimary,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.2,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final mobile = value?.trim() ?? '';
                          if (mobile.isEmpty) return 'Enter your mobile number';
                          if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(mobile)) {
                            return 'Enter a valid mobile number';
                          }
                          return null;
                        },
                      ),

                      // ── OTP fields — shown only after OTP is sent ─────────
                      if (authState.isOtpSent) ...[
                        const SizedBox(height: 12),

                        if (authState.isNewUser) ...[
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                            decoration: _inputDecoration(
                              hint: 'Your name',
                              suffixIcon: const Icon(Icons.person_outline,
                                  color: Color(0xFF9CA3AF), size: 22),
                            ),
                            validator: (value) {
                              if (!(authState.isOtpSent && authState.isNewUser)) {
                                return null;
                              }
                              final name = value?.trim() ?? '';
                              if (name.isEmpty) return 'Enter your name';
                              if (name.length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // ── Referral Code Field (OPTIONAL) ─────────────────
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2453FF).withOpacity(0.05),
                              border: Border.all(
                                color: const Color(0xFF2453FF).withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.card_giftcard,
                                          size: 16,
                                          color: const Color(0xFF2453FF)
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Referral Code',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xFF2453FF),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Text(
                                      'Optional',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _referralCodeController,
                                  textCapitalization: TextCapitalization.characters,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (value) => setState(() {}),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF111827),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., JOHN_ABC123 (leave empty to skip)',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 13,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFD1D5DB),
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2453FF),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_referralCodeController.text.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                          size: 14,
                                          color: Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Bonus unlocks after your first order!',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── 6-box OTP input ────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) {
                            final filled = _otpControllers[i].text.isNotEmpty;
                            return SizedBox(
                              width: 46,
                              height: 52,
                              child: KeyboardListener(
                                focusNode: FocusNode(),
                                onKeyEvent: (e) => _onOtpKeyEvent(e, i),
                                child: TextFormField(
                                  controller: _otpControllers[i],
                                  focusNode: _otpFocusNodes[i],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  // iOS shows the SMS code above the keyboard;
                                  // it inserts the full code into the first box,
                                  // which _fillOtp() then spreads across all six.
                                  autofillHints: i == 0
                                      ? const [AutofillHints.oneTimeCode]
                                      : null,
                                  maxLengthEnforcement: MaxLengthEnforcement.none,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) => _onOtpChanged(v, i),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    filled: true,
                                    fillColor: filled
                                        ? const Color(0xFFEEF0FF)
                                        : Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: filled
                                            ? _kPrimary
                                            : const Color(0xFFD1D5DB),
                                        width: filled ? 1.8 : 1.2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: _kPrimary,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFEF4444),
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFEF4444),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (_) {
                                    if (i == 0 && _otpValue.length < 6) {
                                      return '';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                        if (_otpValue.isNotEmpty && _otpValue.length < 6)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Enter all 6 digits',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],

                      // ── Error banner ──────────────────────────────────────
                      if (authState.error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: const Color(0xFFFFD5DA)),
                          ),
                          child: Text(
                            authState.error!,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],

                      // ── Change number link (shown after OTP sent) ─────────
                      if (authState.isOtpSent)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: authState.isLoading ? null : _changeNumber,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Change number?',
                              style: TextStyle(
                                color: _kPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // ── Terms & Privacy consent ───────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              activeColor: _kPrimary,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (value) {
                                setState(() => _agreedToTerms = value ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms & Conditions',
                                      style: const TextStyle(
                                        color: _kPrimary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: _termsTapRecognizer,
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: const TextStyle(
                                        color: _kPrimary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: _privacyTapRecognizer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Log in button ─────────────────────────────────────
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (authState.isLoading || !_agreedToTerms)
                              ? null
                              : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimaryDark,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _kPrimaryDark.withAlpha(140),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  authState.isOtpSent
                                      ? (authState.isNewUser
                                          ? 'Create Account & Log in'
                                          : 'Verify OTP & Log in')
                                      : 'Send OTP',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
    String? counterText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 15,
      ),
      suffixIcon: suffixIcon,
      counterText: counterText,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 16,
      ),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD1D5DB),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _kPrimary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 1.5,
        ),
      ),
    );
  }
}

