import 'dart:convert';
import 'package:flutter/services.dart';
import '../../app/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/sale_model.dart';

class PrinterResult {
  final bool success;
  final String? message;

  const PrinterResult(this.success, [this.message]);
}

/// Service interfacing with the NEXGO N5 Inbuilt Thermal Printer
class PrinterService {
  static const MethodChannel _channel = MethodChannel('com.onimta.mobile_pos/printer');

  static Future<bool> isPrinterAvailable() async {
    try {
      final bool available = await _channel.invokeMethod('isPrinterAvailable');
      return available;
    } catch (_) {
      return false;
    }
  }

  static Future<PrinterResult> printReceipt(Sale sale) async {
    try {
      // Decode payments
      final List<Map<String, String>> paymentsList = [];
      if (sale.paymentMethod.startsWith('[')) {
        try {
          final List decoded = jsonDecode(sale.paymentMethod);
          for (final m in decoded) {
            final name = (m['method'] ?? 'Payment').toString();
            final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
            paymentsList.add({
              'method': name,
              'amount': CurrencyFormatter.formatWithSymbol(amt),
            });
          }
        } catch (_) {}
      }

      if (paymentsList.isEmpty) {
        paymentsList.add({
          'method': sale.paymentMethod,
          'amount': CurrencyFormatter.formatWithSymbol(sale.paidAmount),
        });
      }

      // Build Items payload
      final itemsPayload = sale.items.map((item) {
        return {
          'description': item.productDescription,
          'qty': CurrencyFormatter.formatQuantity(item.quantity),
          'price': CurrencyFormatter.formatWithSymbol(item.unitPrice),
          'total': CurrencyFormatter.formatWithSymbol(item.lineTotal),
        };
      }).toList();

      final receiptData = {
        'appName': AppConstants.appName,
        'invoiceNo': sale.invoiceNo,
        'customerName': sale.customerName,
        'cashierName': sale.cashierName,
        'dateTime': sale.createdAt ?? DateTime.now().toLocal().toString().substring(0, 19),
        'items': itemsPayload,
        'subtotal': CurrencyFormatter.formatWithSymbol(sale.subtotal),
        'discount': sale.discount > 0 ? CurrencyFormatter.formatWithSymbol(sale.discount) : '',
        'tax': sale.tax > 0 ? CurrencyFormatter.formatWithSymbol(sale.tax) : '',
        'grandTotal': CurrencyFormatter.formatWithSymbol(sale.grandTotal),
        'payments': paymentsList,
        'paidAmount': CurrencyFormatter.formatWithSymbol(sale.paidAmount),
        'changeAmount': sale.changeAmount > 0 ? CurrencyFormatter.formatWithSymbol(sale.changeAmount) : '',
      };

      final bool result = await _channel.invokeMethod('printReceipt', receiptData);
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }

  static Future<PrinterResult> printCashMovementReceipt({
    required bool isPaidIn,
    required double amount,
    required String reason,
    String? cashierName,
    String? dateTime,
  }) async {
    try {
      final payload = {
        'appName': AppConstants.appName,
        'type': isPaidIn ? 'PAID IN (CASH ENTRY)' : 'PAID OUT (CASH EXPENSE)',
        'amount': CurrencyFormatter.formatWithSymbol(amount),
        'reason': reason,
        'cashier': cashierName ?? 'Admin',
        'dateTime': dateTime ?? DateTime.now().toLocal().toString().substring(0, 19),
      };

      final bool result = await _channel.invokeMethod('printCashMovement', payload);
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }
}
