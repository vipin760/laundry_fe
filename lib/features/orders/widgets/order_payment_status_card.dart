import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_text.dart';
import '../models/order_model.dart';
import 'invoice_download_button.dart';

const _kGreen = Color(0xFF12B76A);
const _kGreenBg = Color(0xFFECFDF5);
const _kAmber = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed = Color(0xFFD92D20);
const _kRedBg = Color(0xFFFEF3F2);
const _kText = Color(0xFF0A1645);
const _kMuted = Color(0xFF7D86A5);

/// Banner for the delivery-time QR states of an unpaid order:
///  * QR on screen at the door → "Awaiting Payment"
///  * QR timed out            → "QR expired" with the way forward
/// Renders nothing for any other state.
class PaymentQrStatusBanner extends StatelessWidget {
  final OrderModel order;
  const PaymentQrStatusBanner({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.isAwaitingQrPayment) {
      return _banner(
        bg: _kAmberBg,
        accent: _kAmber,
        leading: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _kAmber),
        ),
        title: 'Awaiting Payment',
        body:
            'Scan the QR shown by your delivery partner with any UPI app and pay ₹${order.effectiveAmount.toStringAsFixed(2)}. This screen updates by itself once the payment is confirmed.',
      );
    }
    if (order.isQrExpired) {
      return _banner(
        bg: _kRedBg,
        accent: _kRed,
        leading: const Icon(Icons.timer_off_rounded, color: _kRed, size: 22),
        title: 'Payment QR expired',
        body:
            'No payment was received on that QR. Ask your delivery partner to show a new one, or pay in the app.',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _banner({
    required Color bg,
    required Color accent,
    required Widget leading,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: leading,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(title, fontWeight: FontWeight.w800, color: accent),
                const SizedBox(height: 3),
                AppText(body, fontSize: 12, color: _kText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Payment Successful" receipt: order id, amount, method, transaction
/// reference and completion time — straight from what the server recorded
/// after verifying the payment — plus the invoice download.
class PaymentReceiptCard extends StatelessWidget {
  final OrderModel order;
  const PaymentReceiptCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final paidAt = order.paymentCompletedAt;
    final method = order.paymentMethod ??
        (order.paymentChannel == 'ONLINE' ? 'Online payment' : null);
    final reference = order.paymentTransactionId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGreenBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _kGreen, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Payment Successful',
                        fontWeight: FontWeight.w800, color: _kGreen),
                    const SizedBox(height: 3),
                    AppText(
                      '₹${order.effectiveAmount.toStringAsFixed(2)} paid successfully',
                      fontSize: 12,
                      color: _kText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _line('Order ID', '#${order.displayNumber}'),
                _line('Amount paid', '₹${order.effectiveAmount.toStringAsFixed(2)}'),
                if (method != null) _line('Payment method', method),
                if (reference != null) _line('Transaction ref', reference, mono: true),
                if (paidAt != null)
                  _line('Date & time',
                      DateFormat('MMM dd, yyyy · hh:mm a').format(paidAt.toLocal())),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InvoiceDownloadButton(orderId: order.id),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, fontSize: 12, color: _kMuted),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kText,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
