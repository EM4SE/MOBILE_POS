import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../data/models/reports_model.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';

class TotalSalesScreen extends StatefulWidget {
  final SalesRepository salesRepository;
  final AuthenticationService authService;

  const TotalSalesScreen({
    super.key,
    required this.salesRepository,
    required this.authService,
  });

  @override
  State<TotalSalesScreen> createState() => _TotalSalesScreenState();
}

class _TotalSalesScreenState extends State<TotalSalesScreen> {
  String _selectedPeriod = 'Today';
  bool _isLoading = true;
  bool _isPrinting = false;
  TotalSalesReportData? _data;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final dateFilter = _selectedPeriod == 'Today'
          ? DateTime.now().toIso8601String().substring(0, 10)
          : null;
      final result = await widget.salesRepository.getTotalSalesReport(dateFilter: dateFilter);
      if (!mounted) return;
      setState(() {
        _data = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialog.showSnackBar(context, 'Error loading total sales: $e', isError: true);
    }
  }

  Future<void> _handlePrint() async {
    if (_data == null || (_data!.totalInvoices == 0 && _data!.totalReturnsCount == 0)) {
      AppDialog.showSnackBar(context, 'No sales records to print for this period.', isError: true);
      return;
    }

    FeedbackHelper.vibrate();
    setState(() => _isPrinting = true);

    try {
      final cashier = widget.authService.currentUser.value?.displayName ?? 'Admin';
      final d = _data!;

      final result = await PrinterService.printTotalSalesReport(
        title: '*** TOTAL FINANCIAL SALES REPORT ***',
        period: _selectedPeriod,
        cashierName: cashier,
        totalInvoices: d.totalInvoices,
        grossSales: d.grossSales,
        discount: d.totalDiscount,
        tax: d.totalTax,
        netSales: d.netSales,
        returnsCount: d.totalReturnsCount,
        returnsAmount: d.totalReturnsAmount,
        totalNetRevenue: d.totalNetRevenue,
        cashSales: d.cashSales,
        cardSales: d.cardSales,
        qrSales: d.qrSales,
        creditSales: d.creditSales,
      );

      if (!mounted) return;
      setState(() => _isPrinting = false);

      if (result.success) {
        AppDialog.showSnackBar(context, 'Total Sales Report printed successfully.');
      } else {
        AppDialog.showSnackBar(context, 'Print failed: ${result.errorMessage}', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      AppDialog.showSnackBar(context, 'Printer error: $e', isError: true);
    }
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? (isBold ? AppColors.textPrimary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'TOTAL SALES REPORT',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Period Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  const Text(
                    'Period: ',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Today', label: Text('Today')),
                        ButtonSegment(value: 'All Time', label: Text('All Time')),
                      ],
                      selected: {_selectedPeriod},
                      onSelectionChanged: (set) {
                        FeedbackHelper.vibrate();
                        setState(() => _selectedPeriod = set.first);
                        _loadReport();
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : d == null
                      ? const Center(child: Text('No data'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Highlight Net Revenue Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'TOTAL NET REVENUE:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1E40AF),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.formatWithSymbol(d.totalNetRevenue),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0D6EFD),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // 2. Sales Summary Card
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SALES SUMMARY',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                                    ),
                                    const Divider(height: 12),
                                    _buildSummaryRow('Total Invoices Count', '${d.totalInvoices} bills'),
                                    _buildSummaryRow('Gross Sales', CurrencyFormatter.formatWithSymbol(d.grossSales)),
                                    if (d.totalDiscount > 0)
                                      _buildSummaryRow('Discounts Applied', '-${CurrencyFormatter.formatWithSymbol(d.totalDiscount)}', valueColor: AppColors.error),
                                    if (d.totalTax > 0)
                                      _buildSummaryRow('Tax', CurrencyFormatter.formatWithSymbol(d.totalTax)),
                                    _buildSummaryRow('Net Sales', CurrencyFormatter.formatWithSymbol(d.netSales), isBold: true),
                                    if (d.totalReturnsCount > 0) ...[
                                      const Divider(height: 10),
                                      _buildSummaryRow(
                                        'Returns & Refunds (${d.totalReturnsCount} bills)',
                                        '-${CurrencyFormatter.formatWithSymbol(d.totalReturnsAmount)}',
                                        isBold: true,
                                        valueColor: AppColors.error,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // 3. Payment & Tender Breakdown Card
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PAYMENTS & TENDER BREAKDOWN',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                                    ),
                                    const Divider(height: 12),
                                    _buildSummaryRow('Cash Sales', CurrencyFormatter.formatWithSymbol(d.cashSales)),
                                    _buildSummaryRow('Card Sales', CurrencyFormatter.formatWithSymbol(d.cardSales)),
                                    _buildSummaryRow('QR / Online Sales', CurrencyFormatter.formatWithSymbol(d.qrSales)),
                                    _buildSummaryRow('Credit Sales', CurrencyFormatter.formatWithSymbol(d.creditSales)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            // Fixed Bottom Print Action Bar
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EFD),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 1,
                  ),
                  onPressed: _isPrinting ? null : _handlePrint,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print, size: 20),
                  label: Text(
                    _isPrinting ? 'PRINTING REPORT...' : 'PRINT TOTAL SALES REPORT',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
