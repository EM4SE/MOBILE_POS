import 'dart:convert';
import 'package:flutter/services.dart';
import '../../app/constants/app_constants.dart';
import '../../app/constants/database_constants.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/sale_model.dart';

class PrinterResult {
  final bool success;
  final String? message;

  String? get errorMessage => message;

  const PrinterResult(this.success, [this.message]);
}

/// Service interfacing with the NEXGO N5 Inbuilt Thermal Printer
class PrinterService {
  static const MethodChannel _channel = MethodChannel('com.onimta.mobile_pos/printer');

  /// Retrieve configured Store Name, Address, and Phone from POS settings database
  static Future<Map<String, String>> getStoreInfo() async {
    try {
      final dbService = DatabaseServiceImpl();
      final results = await dbService.query(DatabaseConstants.tableSettings);
      final map = <String, String>{};
      for (final row in results) {
        final key = row[DatabaseConstants.colKey] as String?;
        final val = row[DatabaseConstants.colValue] as String?;
        if (key != null && val != null) {
          map[key] = val;
        }
      }
      final name = (map['store_name']?.trim().isNotEmpty == true)
          ? map['store_name']!.trim()
          : (map['app_name']?.trim().isNotEmpty == true)
              ? map['app_name']!.trim()
              : AppConstants.appName;
      return {
        'appName': name,
        'storeName': name,
        'storeAddress': (map['store_address']?.trim().isNotEmpty == true)
            ? map['store_address']!.trim()
            : '',
        'storePhone': (map['store_phone']?.trim().isNotEmpty == true)
            ? map['store_phone']!.trim()
            : '',
      };
    } catch (_) {
      return {
        'appName': AppConstants.appName,
        'storeName': AppConstants.appName,
        'storeAddress': '',
        'storePhone': '',
      };
    }
  }

  static Future<bool> isPrinterAvailable() async {
    try {
      final bool available = await _channel.invokeMethod('isPrinterAvailable');
      return available;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setSelectedDevice(String device) async {
    try {
      final bool success = await _channel.invokeMethod('setSelectedDevice', {'device': device});
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setPrinterFont(String font) async {
    try {
      final bool success = await _channel.invokeMethod('setPrinterFont', {'font': font});
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<PrinterResult> printFontTest(String font) async {
    try {
      final bool result = await _channel.invokeMethod('printFontTest', {'font': font});
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }

  static Future<PrinterResult> printReceipt(
    Sale sale, {
    String? storeName,
    String? storeAddress,
    String? storePhone,
  }) async {
    try {
      if (storeName == null || storeAddress == null || storePhone == null) {
        final storeInfo = await getStoreInfo();
        storeName ??= storeInfo['storeName'];
        storeAddress ??= storeInfo['storeAddress'];
        storePhone ??= storeInfo['storePhone'];
      }

      // Decode payments
      final List<Map<String, String>> paymentsList = [];
      if (sale.paymentMethod.startsWith('[')) {
        try {
          final List decoded = jsonDecode(sale.paymentMethod);
          for (final m in decoded) {
            final name = (m['method'] ?? 'PAYMENT').toString().toUpperCase();
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
          'method': sale.paymentMethod.toUpperCase(),
          'amount': CurrencyFormatter.formatWithSymbol(sale.paidAmount),
        });
      }

      // Build Items payload (item names capitalized)
      final itemsPayload = sale.items.map((item) {
        return {
          'description': item.productDescription.toUpperCase(),
          'qty': CurrencyFormatter.formatQuantity(item.quantity),
          'price': CurrencyFormatter.formatAmount(item.unitPrice),
          'discount': item.discount > 0 ? CurrencyFormatter.formatWithSymbol(item.discount) : '',
          'total': CurrencyFormatter.formatAmount(item.lineTotal),
        };
      }).toList();

      final exchangeCredit = (sale.subtotal - sale.discount + sale.tax - sale.grandTotal).clamp(0.0, double.infinity);
      final resolvedName = storeName ?? AppConstants.appName;
      final receiptData = {
        'appName': resolvedName,
        'storeName': resolvedName,
        'storeAddress': storeAddress ?? '',
        'storePhone': storePhone ?? '',
        'invoiceNo': sale.invoiceNo.toUpperCase(),
        'customerName': sale.customerName.toUpperCase(),
        'cashierName': sale.cashierName.toUpperCase(),
        'dateTime': sale.createdAt ?? DateTime.now().toLocal().toString().substring(0, 19),
        'items': itemsPayload,
        'subtotal': CurrencyFormatter.formatWithSymbol(sale.subtotal),
        'discount': sale.discount > 0 ? CurrencyFormatter.formatWithSymbol(sale.discount) : '',
        'exchangeCredit': exchangeCredit > 0.01 ? CurrencyFormatter.formatWithSymbol(exchangeCredit) : '',
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
      final storeInfo = await getStoreInfo();
      final payload = {
        'appName': storeInfo['appName'] ?? AppConstants.appName,
        'storeName': storeInfo['storeName'] ?? AppConstants.appName,
        'storeAddress': storeInfo['storeAddress'] ?? '',
        'storePhone': storeInfo['storePhone'] ?? '',
        'type': isPaidIn ? 'PAID IN (CASH ENTRY)' : 'PAID OUT (CASH EXPENSE)',
        'amount': CurrencyFormatter.formatWithSymbol(amount),
        'reason': reason.toUpperCase(),
        'cashier': (cashierName ?? 'Admin').toUpperCase(),
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

  static Future<PrinterResult> printShiftEventReceipt({
    required String title,
    required int dayNumber,
    required int shiftNumber,
    required String cashierName,
    required bool isEndReport,
    double openingBalance = 0.0,
    String? openedAt,
    String? dateTime,
    // End report data
    int totalInvoices = 0,
    double grossSales = 0.0,
    double discount = 0.0,
    double tax = 0.0,
    double netSales = 0.0,
    double cashSales = 0.0,
    double nonCashSales = 0.0,
    Map<String, double>? nonCashBreakdown,
    double cardSales = 0.0,
    double otherSales = 0.0,
    double paidIn = 0.0,
    double paidOut = 0.0,
    double expectedCash = 0.0,
    double actualCash = 0.0,
    double cashDiff = 0.0,
  }) async {
    try {
      final storeInfo = await getStoreInfo();
      final payload = {
        'appName': storeInfo['appName'] ?? AppConstants.appName,
        'storeName': storeInfo['storeName'] ?? AppConstants.appName,
        'storeAddress': storeInfo['storeAddress'] ?? '',
        'storePhone': storeInfo['storePhone'] ?? '',
        'title': title.toUpperCase(),
        'dayNumber': '#$dayNumber',
        'shiftNumber': '#$shiftNumber',
        'shiftNo': '#$shiftNumber',
        'cashier': cashierName.toUpperCase(),
        'isEndReport': isEndReport,
        'openingBalance': CurrencyFormatter.formatWithSymbol(openingBalance),
        'openingCash': CurrencyFormatter.formatWithSymbol(openingBalance),
        'openedAt': openedAt ?? '',
        'startTime': openedAt ?? '',
        'dateTime': dateTime ?? DateTime.now().toLocal().toString().substring(0, 19),
        'totalInvoices': '$totalInvoices',
        'grossSales': CurrencyFormatter.formatWithSymbol(grossSales),
        'discount': CurrencyFormatter.formatWithSymbol(discount),
        'tax': CurrencyFormatter.formatWithSymbol(tax),
        'netSales': CurrencyFormatter.formatWithSymbol(netSales),
        'cashSales': CurrencyFormatter.formatWithSymbol(cashSales),
        'nonCashSales': CurrencyFormatter.formatWithSymbol(nonCashSales),
        'nonCashBreakdown': nonCashBreakdown?.map((key, val) => MapEntry(key.toUpperCase(), CurrencyFormatter.formatWithSymbol(val))) ?? {},
        'cardSales': CurrencyFormatter.formatWithSymbol(cardSales),
        'otherSales': CurrencyFormatter.formatWithSymbol(otherSales),
        'paidIn': CurrencyFormatter.formatWithSymbol(paidIn),
        'paidOut': CurrencyFormatter.formatWithSymbol(paidOut),
        'expectedCash': CurrencyFormatter.formatWithSymbol(expectedCash),
        'actualCash': CurrencyFormatter.formatWithSymbol(actualCash),
        'cashDiff': (cashDiff > 0 ? '+' : '') + CurrencyFormatter.formatWithSymbol(cashDiff),
        'difference': (cashDiff > 0 ? '+' : '') + CurrencyFormatter.formatWithSymbol(cashDiff),
      };

      final bool result = await _channel.invokeMethod('printShiftReport', payload);
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }

  /// Print Exchange Receipt Voucher with Barcode
  static Future<PrinterResult> printExchangeReceipt({
    required String voucherCode,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? customerName,
    String? cashierName,
    String? dateTime,
  }) async {
    try {
      final storeInfo = await getStoreInfo();
      final itemsPayload = items.map((item) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
        final total = (item['lineTotal'] as num?)?.toDouble() ?? (qty * price);
        return {
          'description': (item['description'] ?? item['productDescription'] ?? 'Item').toString().toUpperCase(),
          'qty': CurrencyFormatter.formatQuantity(qty),
          'price': CurrencyFormatter.formatAmount(price),
          'total': CurrencyFormatter.formatAmount(total),
        };
      }).toList();

      final payload = {
        'appName': storeInfo['appName'] ?? AppConstants.appName,
        'storeName': storeInfo['storeName'] ?? AppConstants.appName,
        'storeAddress': storeInfo['storeAddress'] ?? '',
        'storePhone': storeInfo['storePhone'] ?? '',
        'voucherCode': voucherCode.toUpperCase(),
        'totalAmount': CurrencyFormatter.formatWithSymbol(totalAmount),
        'customerName': (customerName ?? 'Walk-in Customer').toUpperCase(),
        'cashierName': (cashierName ?? 'Admin').toUpperCase(),
        'dateTime': dateTime ?? DateTime.now().toLocal().toString().substring(0, 19),
        'items': itemsPayload,
      };

      final bool result = await _channel.invokeMethod('printExchangeReceipt', payload);
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }

  /// Print Return & Refund Receipt
  static Future<PrinterResult> printReturnReceipt({
    required String returnNo,
    required double refundAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? reason,
    String? customerName,
    String? cashierName,
    String? dateTime,
  }) async {
    try {
      final storeInfo = await getStoreInfo();
      final itemsPayload = items.map((item) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
        final total = (item['lineTotal'] as num?)?.toDouble() ?? (qty * price);
        return {
          'description': (item['description'] ?? item['productDescription'] ?? 'Item').toString().toUpperCase(),
          'qty': CurrencyFormatter.formatQuantity(qty),
          'price': CurrencyFormatter.formatAmount(price),
          'total': CurrencyFormatter.formatAmount(total),
        };
      }).toList();

      final payload = {
        'appName': storeInfo['appName'] ?? AppConstants.appName,
        'storeName': storeInfo['storeName'] ?? AppConstants.appName,
        'storeAddress': storeInfo['storeAddress'] ?? '',
        'storePhone': storeInfo['storePhone'] ?? '',
        'returnNo': returnNo.toUpperCase(),
        'refundAmount': CurrencyFormatter.formatWithSymbol(refundAmount),
        'paymentMethod': paymentMethod.toUpperCase(),
        'reason': (reason ?? 'Customer Return').toUpperCase(),
        'customerName': (customerName ?? 'Walk-in Customer').toUpperCase(),
        'cashierName': (cashierName ?? 'Admin').toUpperCase(),
        'dateTime': dateTime ?? DateTime.now().toLocal().toString().substring(0, 19),
        'items': itemsPayload,
      };

      final bool result = await _channel.invokeMethod('printReturnReceipt', payload);
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }

  /// Print Item Wise Sales Report
  static Future<PrinterResult> printItemWiseSalesReport({
    required String title,
    required String period,
    required String cashierName,
    required double totalQuantity,
    required double totalRevenue,
    required List<Map<String, dynamic>> items,
    String? dateTime,
  }) async {
    try {
      final storeInfo = await getStoreInfo();
      final itemsPayload = items.map((item) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final total = (item['totalAmount'] as num?)?.toDouble() ?? 0.0;
        return {
          'description': (item['description'] ?? 'Item').toString().toUpperCase(),
          'qty': CurrencyFormatter.formatQuantity(qty),
          'total': CurrencyFormatter.formatWithSymbol(total),
        };
      }).toList();

      final payload = {
        'appName': storeInfo['appName'] ?? AppConstants.appName,
        'storeName': storeInfo['storeName'] ?? AppConstants.appName,
        'storeAddress': storeInfo['storeAddress'] ?? '',
        'storePhone': storeInfo['storePhone'] ?? '',
        'title': title.toUpperCase(),
        'period': period.toUpperCase(),
        'cashierName': cashierName.toUpperCase(),
        'dateTime': dateTime ?? DateTime.now().toLocal().toString().substring(0, 19),
        'totalQuantity': CurrencyFormatter.formatQuantity(totalQuantity),
        'totalRevenue': CurrencyFormatter.formatWithSymbol(totalRevenue),
        'items': itemsPayload,
      };

      final bool result = await _channel.invokeMethod('printItemWiseSalesReport', payload);
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }

  /// Print Total Financial Sales Report
  static Future<PrinterResult> printTotalSalesReport({
    required String title,
    required String period,
    required String cashierName,
    required int totalInvoices,
    required double grossSales,
    required double discount,
    required double tax,
    required double netSales,
    required int returnsCount,
    required double returnsAmount,
    required double totalNetRevenue,
    required double cashSales,
    double nonCashSales = 0.0,
    Map<String, double>? nonCashBreakdown,
    required double cardSales,
    required double qrSales,
    required double creditSales,
    String? dateTime,
  }) async {
    try {
      final storeInfo = await getStoreInfo();
      final payload = {
        'appName': storeInfo['appName'] ?? AppConstants.appName,
        'storeName': storeInfo['storeName'] ?? AppConstants.appName,
        'storeAddress': storeInfo['storeAddress'] ?? '',
        'storePhone': storeInfo['storePhone'] ?? '',
        'title': title.toUpperCase(),
        'period': period.toUpperCase(),
        'cashierName': cashierName.toUpperCase(),
        'dateTime': dateTime ?? DateTime.now().toLocal().toString().substring(0, 19),
        'totalInvoices': '$totalInvoices',
        'grossSales': CurrencyFormatter.formatWithSymbol(grossSales),
        'discount': CurrencyFormatter.formatWithSymbol(discount),
        'tax': CurrencyFormatter.formatWithSymbol(tax),
        'netSales': CurrencyFormatter.formatWithSymbol(netSales),
        'returnsCount': '$returnsCount',
        'returnsAmount': CurrencyFormatter.formatWithSymbol(returnsAmount),
        'totalNetRevenue': CurrencyFormatter.formatWithSymbol(totalNetRevenue),
        'cashSales': CurrencyFormatter.formatWithSymbol(cashSales),
        'nonCashSales': CurrencyFormatter.formatWithSymbol(nonCashSales),
        'nonCashBreakdown': nonCashBreakdown?.map((key, val) => MapEntry(key.toUpperCase(), CurrencyFormatter.formatWithSymbol(val))) ?? {},
        'cardSales': CurrencyFormatter.formatWithSymbol(cardSales),
        'qrSales': CurrencyFormatter.formatWithSymbol(qrSales),
        'creditSales': CurrencyFormatter.formatWithSymbol(creditSales),
      };

      final bool result = await _channel.invokeMethod('printTotalSalesReport', payload);
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }

  /// Print Held Bill Receipt with Barcode (without item list)
  static Future<PrinterResult> printHoldReceipt({
    required String holdNo,
    required double totalAmount,
    required int totalItemsCount,
    required double totalQuantity,
    String? customerName,
    String? cashierName,
    String? dateTime,
  }) async {
    try {
      final storeInfo = await getStoreInfo();
      final payload = {
        'appName': storeInfo['appName'] ?? AppConstants.appName,
        'storeName': storeInfo['storeName'] ?? AppConstants.appName,
        'storeAddress': storeInfo['storeAddress'] ?? '',
        'storePhone': storeInfo['storePhone'] ?? '',
        'holdNo': holdNo.toUpperCase(),
        'totalAmount': CurrencyFormatter.formatWithSymbol(totalAmount),
        'totalItems': '$totalItemsCount LINES (${CurrencyFormatter.formatQuantity(totalQuantity)} ITEMS)',
        'customerName': (customerName ?? 'Walk-in Customer').toUpperCase(),
        'cashierName': (cashierName ?? 'Admin').toUpperCase(),
        'dateTime': dateTime ?? DateTime.now().toLocal().toString().substring(0, 19),
      };

      final bool result = await _channel.invokeMethod('printHoldReceipt', payload);
      return PrinterResult(result);
    } on PlatformException catch (e) {
      return PrinterResult(false, e.message ?? e.details?.toString() ?? 'Printer error');
    } catch (e) {
      return PrinterResult(false, e.toString());
    }
  }
}

