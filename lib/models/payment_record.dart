import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentRecord {
  const PaymentRecord({
    required this.paymentId,
    required this.userId,
    required this.matchId,
    required this.organiserId,
    required this.amount,
    required this.platformFee,
    required this.total,
    this.currency = 'GBP',
    required this.status,
    required this.paymentProvider,
    required this.mockPayment,
    required this.createdAt,
  });

  final String paymentId;
  final String userId;
  final String matchId;
  final String organiserId;
  final double amount;
  final double platformFee;
  final double total;
  final String currency;
  final String status;
  final String paymentProvider;
  final bool mockPayment;
  final DateTime createdAt;

  factory PaymentRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return PaymentRecord(
      paymentId: data['paymentId'] as String? ?? document.id,
      userId: data['userId'] as String? ?? '',
      matchId: data['matchId'] as String? ?? '',
      organiserId: data['organiserId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? 'GBP',
      status: data['status'] as String? ?? 'Pending',
      paymentProvider: data['paymentProvider'] as String? ?? 'mock',
      mockPayment: data['mockPayment'] as bool? ?? true,
      createdAt: _readDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'userId': userId,
      'matchId': matchId,
      'organiserId': organiserId,
      'amount': amount,
      'platformFee': platformFee,
      'total': total,
      'currency': currency,
      'status': status,
      'paymentProvider': paymentProvider,
      'mockPayment': mockPayment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
