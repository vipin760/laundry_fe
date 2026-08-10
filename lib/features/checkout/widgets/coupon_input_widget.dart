import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/services/coupon_service.dart';

class CouponInputWidget extends ConsumerStatefulWidget {
  final String orderId;
  final double orderAmount;
  final Function(double) onCouponApplied;

  const CouponInputWidget({
    super.key,
    required this.orderId,
    required this.orderAmount,
    required this.onCouponApplied,
  });

  @override
  ConsumerState<CouponInputWidget> createState() => _CouponInputWidgetState();
}

class _CouponInputWidgetState extends ConsumerState<CouponInputWidget> {
  late TextEditingController _couponController;
  late CouponService _couponService;
  CouponDiscount? _appliedCoupon;
  bool _isLoading = false;
  String? _error;
  List<Coupon> _availableCoupons = [];

  @override
  void initState() {
    super.initState();
    _couponController = TextEditingController();
    _couponService = CouponService();
    _loadAvailableCoupons();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableCoupons() async {
    try {
      final coupons = await _couponService.getMyCoupons();
      if (mounted) {
        setState(() {
          _availableCoupons = coupons;
        });
      }
    } catch (e) {
      debugPrint('Error loading coupons: $e');
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a coupon code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final discount = await _couponService.applyToOrder(widget.orderId, code);

      if (mounted) {
        setState(() {
          _appliedCoupon = discount;
          _isLoading = false;
        });

        widget.onCouponApplied(discount.finalAmount);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Coupon applied! Save ₹${discount.discountAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeCoupon() async {
    // Best-effort: undo the server-side apply, but clear local state
    // regardless of whether the backend call succeeds (e.g. it's a no-op
    // if nothing was actually applied server-side yet).
    try {
      await _couponService.removeFromOrder(widget.orderId);
    } catch (e) {
      debugPrint('Error removing coupon: $e');
    }
    if (!mounted) return;
    setState(() {
      _couponController.clear();
      _appliedCoupon = null;
      _error = null;
    });
    widget.onCouponApplied(widget.orderAmount);
  }

  void _applySuggested(String code) {
    _couponController.text = code;
    _applyCoupon();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Applied Coupon Banner ────────────────────────────
        if (_appliedCoupon != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✓ ${_appliedCoupon!.couponCode} Applied',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You save ₹${_appliedCoupon!.discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _removeCoupon,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

        // ── Coupon Input ────────────────────────────────────
        if (_appliedCoupon == null) ...[
          TextFormField(
            controller: _couponController,
            textCapitalization: TextCapitalization.characters,
            enabled: !_isLoading,
            // Rebuilds on every keystroke so the "Apply" checkmark (which
            // depends on _couponController.text.isNotEmpty) actually
            // repaints. Also clears any leftover error from a previous
            // apply attempt so it doesn't linger on a code you've since
            // changed.
            onChanged: (_) => setState(() {
              if (_error != null) _error = null;
            }),
            decoration: InputDecoration(
              hintText: 'Enter coupon code',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFD1D5DB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFD1D5DB),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2453FF),
                  width: 1.5,
                ),
              ),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _couponController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: _applyCoupon,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2453FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        )
                      : null,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Available Coupons ────────────────────────────────
        if (_availableCoupons.isNotEmpty && _appliedCoupon == null) ...[
          const Text(
            'Available Offers',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableCoupons.take(3).map((coupon) {
                final isEligible = widget.orderAmount >= coupon.minimumOrderAmount;
                final discountLabel = coupon.discountType == CouponDiscountType.percentage
                    ? '${coupon.discountValue.toStringAsFixed(0)}% OFF'
                    : '₹${coupon.discountValue.toStringAsFixed(0)} OFF';
                return GestureDetector(
                  onTap: isEligible ? () => _applySuggested(coupon.couponCode) : null,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEligible
                          ? const Color(0xFF2453FF).withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                      border: Border.all(
                        color: isEligible
                            ? const Color(0xFF2453FF).withValues(alpha: 0.3)
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon.couponCode,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isEligible
                                ? const Color(0xFF2453FF)
                                : Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          discountLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isEligible
                                ? const Color(0xFF2453FF)
                                : Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Min ₹${coupon.minimumOrderAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isEligible
                                ? const Color(0xFF6B7280)
                                : Color(0xFFBFBFBF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
