import 'dart:convert';

class ParsedPaymentItem {
  final String method;
  final double amount;

  const ParsedPaymentItem({
    required this.method,
    required this.amount,
  });
}

class PaymentBreakdownHelper {
  /// Extracts all individual payment lines from a paymentMethod string and paid amount.
  /// Handles single strings ('Cash', 'Card', 'Credit') and JSON strings ('[{"method":"Cash","amount":1000}]').
  static List<ParsedPaymentItem> parse(String? rawPaymentMethod, double fallbackAmount) {
    if (rawPaymentMethod == null || rawPaymentMethod.trim().isEmpty) {
      return [ParsedPaymentItem(method: 'Cash', amount: fallbackAmount)];
    }

    final trimmed = rawPaymentMethod.trim();

    // Check if JSON array
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final List decoded = jsonDecode(trimmed);
        final list = <ParsedPaymentItem>[];
        for (final item in decoded) {
          if (item is Map) {
            final method = (item['method'] ?? 'Payment').toString();
            final amount = ((item['amount'] as num?) ?? 0.0).toDouble();
            list.add(ParsedPaymentItem(method: method, amount: amount));
          }
        }
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    // Single payment method
    return [ParsedPaymentItem(method: trimmed, amount: fallbackAmount)];
  }

  /// Categorizes a payment list into exact standard buckets (cash, card, qr, credit, other)
  static ({
    double cash,
    double card,
    double qr,
    double credit,
    double other,
  }) aggregate(List<ParsedPaymentItem> items) {
    double cash = 0.0;
    double card = 0.0;
    double qr = 0.0;
    double credit = 0.0;
    double other = 0.0;

    for (final p in items) {
      final m = p.method.toLowerCase();
      if (m.contains('cash')) {
        cash += p.amount;
      } else if (m.contains('card')) {
        card += p.amount;
      } else if (m.contains('credit')) {
        credit += p.amount;
      } else if (m.contains('qr') || m.contains('online') || m.contains('mobile')) {
        qr += p.amount;
      } else {
        other += p.amount;
      }
    }

    return (
      cash: cash,
      card: card,
      qr: qr,
      credit: credit,
      other: other,
    );
  }
}
