class WalletTransactionModel {
  final String id;
  final String type;       // 'credit' | 'debit'
  final double amount;
  final String description;
  final String status;     // 'pending' | 'completed' | 'failed'
  final String? razorpayPaymentId;
  final String? referenceOrderId;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    this.razorpayPaymentId,
    this.referenceOrderId,
    required this.createdAt,
  });

  bool get isCredit  => type == 'credit';
  bool get isDebit   => type == 'debit';
  bool get isSuccess => status == 'completed';
  bool get isFailed  => status == 'failed';

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'credit',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      razorpayPaymentId: json['razorpayPaymentId']?.toString(),
      referenceOrderId: json['referenceOrderId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
