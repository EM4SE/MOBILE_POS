import 'dart:convert';

class ParsedPaymentItem {
  final String method;
  final double amount;
  final String? cardRef;

  const ParsedPaymentItem({
    required this.method,
    required this.amount,
    this.cardRef,
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
            final cardRef = (item['cardRef'] ?? item['reference'] ?? '').toString();
            list.add(ParsedPaymentItem(
              method: method,
              amount: amount,
              cardRef: cardRef.isNotEmpty ? cardRef : null,
            ));
          }
        }
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    // Single payment method
    return [ParsedPaymentItem(method: trimmed, amount: fallbackAmount)];
  }

  /// Determines whether a given payment method is Cash
  static bool isCash(String method) {
    final m = method.toLowerCase().trim();
    final isMobileCash = m.contains('e z') || m.contains('ez') || m.contains('m cash') || m.contains('mcash');
    return (m == 'cash' || m == 'cash sale' || m.startsWith('cash')) && !isMobileCash;
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
      final m = p.method.toLowerCase().trim();
      final isMobileCash = m.contains('e z') || m.contains('ez') || m.contains('m cash') || m.contains('mcash');

      if ((m == 'cash' || m.contains('cash')) && !isMobileCash) {
        cash += p.amount;
      } else if (m.contains('card') ||
          m.contains('master') ||
          m.contains('visa') ||
          m.contains('amex') ||
          m.contains('debit')) {
        card += p.amount;
      } else if (m.contains('credit')) {
        credit += p.amount;
      } else if (m.contains('qr') ||
          m.contains('online') ||
          m.contains('line') ||
          m.contains('transfer') ||
          m.contains('mobile') ||
          m.contains('lanka pay') ||
          isMobileCash) {
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

  /// Aggregates sales into Cash, Total Non-Cash, and individual non-cash paytype breakdown
  static ({
    double cash,
    double nonCash,
    Map<String, double> nonCashBreakdown,
    double card,
    double qr,
    double credit,
    double other,
  }) aggregateWithBreakdown(List<ParsedPaymentItem> items, {double change = 0.0}) {
    double cash = 0.0;
    double nonCash = 0.0;
    final Map<String, double> nonCashBreakdown = {};
    double card = 0.0;
    double qr = 0.0;
    double credit = 0.0;
    double other = 0.0;

    for (final p in items) {
      final rawName = p.method.trim();
      if (isCash(rawName)) {
        cash += p.amount;
      } else {
        nonCash += p.amount;
        final key = rawName.toUpperCase();
        nonCashBreakdown[key] = (nonCashBreakdown[key] ?? 0.0) + p.amount;

        final m = rawName.toLowerCase();
        if (m.contains('card') ||
            m.contains('master') ||
            m.contains('visa') ||
            m.contains('amex') ||
            m.contains('debit')) {
          card += p.amount;
        } else if (m.contains('credit')) {
          credit += p.amount;
        } else if (m.contains('qr') ||
            m.contains('online') ||
            m.contains('line') ||
            m.contains('transfer') ||
            m.contains('mobile') ||
            m.contains('lanka pay')) {
          qr += p.amount;
        } else {
          other += p.amount;
        }
      }
    }

    if (change > 0) {
      cash = (cash - change).clamp(0.0, double.infinity);
    }

    return (
      cash: cash,
      nonCash: nonCash,
      nonCashBreakdown: nonCashBreakdown,
      card: card,
      qr: qr,
      credit: credit,
      other: other,
    );
  }
}
