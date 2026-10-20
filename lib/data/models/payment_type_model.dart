import 'package:flutter/material.dart';

/// Represents a Payment Type / Method supported by the POS system.
class PaymentType {
  final int? idNo;
  final String cardNo;
  final String description;
  final double amount;

  const PaymentType({
    this.idNo,
    required this.cardNo,
    required this.description,
    this.amount = 0.0,
  });

  /// Default static Cash payment type ("cash keep as exist")
  static const PaymentType cashDefault = PaymentType(
    idNo: 0,
    cardNo: 'CASH',
    description: 'Cash',
    amount: 0.0,
  );

  /// Offline fallback list for common non-cash payment types
  static const List<PaymentType> fallbackApiTypes = [
    PaymentType(idNo: 7, cardNo: '001', description: 'Master Card'),
    PaymentType(idNo: 8, cardNo: '002', description: 'Visa Card'),
    PaymentType(idNo: 9, cardNo: '003', description: 'Amex'),
    PaymentType(idNo: 11, cardNo: '005', description: 'Credit'),
    PaymentType(idNo: 16, cardNo: '010', description: 'E Z Cash'),
    PaymentType(idNo: 17, cardNo: '011', description: 'M Cash'),
    PaymentType(idNo: 19, cardNo: '013', description: 'DEBIT CARD'),
    PaymentType(idNo: 21, cardNo: '029', description: 'Lanka Pay QR'),
    PaymentType(idNo: 24, cardNo: '102', description: 'HNB On Line'),
    PaymentType(idNo: 25, cardNo: '103', description: 'Sampath On Line'),
  ];

  /// Whether this method is physical Cash
  bool get isCash {
    final lower = description.toLowerCase().trim();
    return lower == 'cash';
  }

  /// Whether this method is Credit (requires assigned customer)
  bool get isCredit {
    final lower = description.toLowerCase().trim();
    return lower == 'credit' || lower.contains('credit');
  }

  /// Icon mapping based on description and payment category
  IconData get icon {
    final lower = description.toLowerCase().trim();
    if (isCash) {
      return Icons.payments_outlined;
    }
    if (lower.contains('visa') ||
        lower.contains('master') ||
        lower.contains('amex') ||
        lower.contains('card') ||
        lower.contains('debit')) {
      return Icons.credit_card_outlined;
    }
    if (isCredit) {
      return Icons.account_balance_wallet_outlined;
    }
    if (lower.contains('qr') || lower.contains('lanka pay')) {
      return Icons.qr_code_2_outlined;
    }
    if (lower.contains('ez') ||
        lower.contains('e z') ||
        lower.contains('m cash') ||
        lower.contains('mcash') ||
        lower.contains('mobile')) {
      return Icons.phone_android_outlined;
    }
    if (lower.contains('line') ||
        lower.contains('online') ||
        lower.contains('bank') ||
        lower.contains('hnb') ||
        lower.contains('sampath')) {
      return Icons.account_balance_outlined;
    }
    return Icons.payment_outlined;
  }

  /// Theme and brand color matching each payment method
  Color get color {
    final lower = description.toLowerCase().trim();
    if (isCash) {
      return const Color(0xFF15803D); // Cash Green
    }
    if (lower.contains('visa')) {
      return const Color(0xFF1D4ED8); // Visa Royal Blue
    }
    if (lower.contains('master')) {
      return const Color(0xFFEA580C); // Mastercard Warm Orange
    }
    if (lower.contains('amex')) {
      return const Color(0xFF0284C7); // Amex Cyan Blue
    }
    if (lower.contains('debit')) {
      return const Color(0xFF0F766E); // Debit Teal
    }
    if (isCredit) {
      return const Color(0xFF7C3AED); // Credit Purple
    }
    if (lower.contains('ez') || lower.contains('e z')) {
      return const Color(0xFFE11D48); // eZ Cash Rose/Crimson
    }
    if (lower.contains('m cash') || lower.contains('mcash')) {
      return const Color(0xFF2563EB); // mCash Electric Blue
    }
    if (lower.contains('lanka pay') || lower.contains('qr')) {
      return const Color(0xFFDC2626); // LankaPay Red
    }
    if (lower.contains('hnb')) {
      return const Color(0xFFD97706); // HNB Gold/Orange
    }
    if (lower.contains('sampath')) {
      return const Color(0xFFC2410C); // Sampath Bank Flame Orange
    }
    if (lower.contains('bank') || lower.contains('online') || lower.contains('line')) {
      return const Color(0xFF475569); // Slate Gray Blue
    }
    return const Color(0xFF0D9488); // Modern Teal
  }

  factory PaymentType.fromJson(Map<String, dynamic> json) {
    return PaymentType(
      idNo: (json['Id_No'] ?? json['id_No'] as num?)?.toInt(),
      cardNo: (json['Card_No'] ?? json['card_No'] ?? '').toString().trim(),
      description: (json['Description'] ?? json['description'] ?? '').toString().trim(),
      amount: ((json['Amount'] ?? json['amount'] as num?) ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'Id_No': idNo,
        'Card_No': cardNo,
        'Description': description,
        'Amount': amount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentType &&
          runtimeType == other.runtimeType &&
          description.toLowerCase() == other.description.toLowerCase();

  @override
  int get hashCode => description.toLowerCase().hashCode;
}
