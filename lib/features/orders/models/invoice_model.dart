/// Lightweight invoice metadata — just enough to decide whether to show
/// "Download Invoice" and what filename/number to display. The full PDF is
/// fetched separately as a byte stream when the user taps download.
class InvoiceMetadata {
  final String invoiceNumber;
  final DateTime generatedAt;
  final double payableTotal;

  InvoiceMetadata({
    required this.invoiceNumber,
    required this.generatedAt,
    required this.payableTotal,
  });

  factory InvoiceMetadata.fromJson(Map<String, dynamic> json) {
    return InvoiceMetadata(
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
      payableTotal: (json['payableTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
