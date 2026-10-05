import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/sale_model.dart';
import '../../../shared/widgets/app_dialog.dart';

/// Clean, Responsive, Zero-Overflow Receipt & Transaction Complete Screen
class BillDetailScreen extends StatefulWidget {
  final Sale sale;

  const BillDetailScreen({
    super.key,
    required this.sale,
  });

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPrintReceipt();
    });
  }

  Future<void> _autoPrintReceipt() async {
    if (!mounted || _isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final result = await PrinterService.printReceipt(widget.sale);
      if (!mounted) return;
      if (result.success) {
        AppDialog.showTopAlert(context, 'Receipt printed automatically');
      } else {
        AppDialog.showSnackBar(context, result.message ?? 'Printer not ready or out of paper');
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  List<Map<String, dynamic>> _getPaymentBreakdown() {
    if (widget.sale.paymentMethod.startsWith('[')) {
      try {
        final List decoded = jsonDecode(widget.sale.paymentMethod);
        return decoded.map((m) {
          return {
            'method': (m['method'] ?? 'Payment').toString(),
            'amount': (m['amount'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();
      } catch (_) {}
    }
    return [
      {'method': widget.sale.paymentMethod, 'amount': widget.sale.paidAmount}
    ];
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                fontSize: isLarge ? 15 : 12.5,
                color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                fontSize: isLarge ? 16 : 12.5,
                color: valueColor ?? (isBold ? AppColors.success : AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TRANSACTION COMPLETED'),
        automaticallyImplyLeading: false,
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isPrinting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print),
            tooltip: 'Reprint Receipt',
            onPressed: _isPrinting ? null : _autoPrintReceipt,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Receipt Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Success Icon & Title
                      const Center(
                        child: Icon(Icons.check_circle, size: 48, color: AppColors.success),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'TAX INVOICE RECEIPT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const Divider(height: 18, thickness: 1, color: AppColors.border),

                      // Meta Info (Invoice #, Status, Customer, Cashier)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Inv: ${widget.sale.invoiceNo}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            color: AppColors.success.withOpacity(0.15),
                            child: Text(
                              widget.sale.status,
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Cust: ${widget.sale.customerName}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Cashier: ${widget.sale.cashierName}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),

                      const Divider(height: 18, thickness: 1, color: AppColors.border),

                      // Item Lines Header
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text('ITEM DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 10, thickness: 0.5, color: AppColors.border),

                      // Item Lines List
                      ...widget.sale.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  item.productDescription,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  CurrencyFormatter.formatQuantity(item.quantity),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  CurrencyFormatter.formatAmount(item.lineTotal),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(height: 18, thickness: 1, color: AppColors.border),

                      // Summary Section
                      _buildSummaryRow('Subtotal', CurrencyFormatter.formatWithSymbol(widget.sale.subtotal)),
                      if (widget.sale.discount > 0)
                        _buildSummaryRow('Discount', '-${CurrencyFormatter.formatWithSymbol(widget.sale.discount)}', valueColor: AppColors.warning),
                      if (widget.sale.tax > 0)
                        _buildSummaryRow('Tax', CurrencyFormatter.formatWithSymbol(widget.sale.tax)),
                      const SizedBox(height: 4),
                      _buildSummaryRow('GRAND TOTAL', CurrencyFormatter.formatWithSymbol(widget.sale.grandTotal), isBold: true, isLarge: true),
                      const Divider(height: 16, color: AppColors.border),
                      
                      // Payment Breakdown Lines (Card 3000, Cash 3500, etc.)
                      ..._getPaymentBreakdown().map((p) {
                        final method = p['method'] as String;
                        final amt = p['amount'] as double;
                        return _buildSummaryRow(method, CurrencyFormatter.formatWithSymbol(amt), isBold: false);
                      }),
                      
                      const Divider(height: 12, thickness: 0.5, color: AppColors.border),
                      _buildSummaryRow('Total Paid', CurrencyFormatter.formatWithSymbol(widget.sale.paidAmount), isBold: true),
                      _buildSummaryRow(
                        'Change Returned',
                        CurrencyFormatter.formatWithSymbol(widget.sale.changeAmount),
                        isBold: true,
                        valueColor: widget.sale.changeAmount > 0 ? AppColors.warning : AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Bottom Actions Bar - Full Width NEW SALE Button Only
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF151B22),
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  icon: const Icon(Icons.add_shopping_cart, size: 22),
                  label: const Text('NEW SALE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.pos,
                      (route) => false,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
