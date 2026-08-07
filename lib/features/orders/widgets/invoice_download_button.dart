import 'package:flutter/material.dart';

import '../../checkout/services/payment_service.dart';
import '../models/invoice_model.dart';
import '../services/invoice_saver.dart';

const _kPrimary = Color(0xFF2453FF);
const _kPrimaryBg = Color(0xFFEEF2FF);
const _kRed = Color(0xFFD92D20);
const _kText = Color(0xFF0A1645);

/// Renders nothing until an invoice actually exists for this order (i.e. the
/// order has been paid — invoices are generated on payment capture). Before
/// that, callers should show a "Invoice will be available after successful
/// payment" notice instead, per the payment-confirmed gating requirement.
class InvoiceDownloadButton extends StatefulWidget {
  final String orderId;
  const InvoiceDownloadButton({super.key, required this.orderId});

  @override
  State<InvoiceDownloadButton> createState() => _InvoiceDownloadButtonState();
}

class _InvoiceDownloadButtonState extends State<InvoiceDownloadButton> {
  final _paymentService = PaymentService();
  InvoiceMetadata? _metadata;
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final metadata = await _paymentService.getInvoiceMetadata(widget.orderId);
    if (!mounted) return;
    setState(() {
      _metadata = metadata;
      _loading = false;
    });
  }

  Future<void> _download() async {
    if (_metadata == null) return;
    setState(() { _downloading = true; _error = null; });
    try {
      final bytes = await _paymentService.downloadInvoiceBytes(orderId: widget.orderId);
      await InvoiceSaver.save(bytes, '${_metadata!.invoiceNumber}.pdf');
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() => _error = msg.startsWith('Exception: ') ? msg.substring(11) : msg);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _metadata == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _downloading ? null : _download,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kPrimaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _downloading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                      )
                    : const Icon(Icons.file_download_outlined, size: 18, color: _kPrimary),
                const SizedBox(width: 8),
                Text(
                  'Download Invoice (${_metadata!.invoiceNumber})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: const TextStyle(fontSize: 12, color: _kRed)),
        ],
      ],
    );
  }
}
