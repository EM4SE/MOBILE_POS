import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../data/datasources/local/shift_local_datasource.dart';
import '../../../data/models/business_day_model.dart';
import '../../../data/repositories/shift_repository.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';

class ZReadingScreen extends StatefulWidget {
  final ShiftRepository shiftRepository;
  final ShiftService shiftService;
  final AuthenticationService authService;

  const ZReadingScreen({
    super.key,
    required this.shiftRepository,
    required this.shiftService,
    required this.authService,
  });

  @override
  State<ZReadingScreen> createState() => _ZReadingScreenState();
}

class _ZReadingScreenState extends State<ZReadingScreen> {
  bool _isLoading = true;
  bool _isPrinting = false;
  BusinessDay? _day;
  ShiftSummaryStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadZReading();
  }

  Future<void> _loadZReading() async {
    setState(() => _isLoading = true);
    try {
      final day = await widget.shiftRepository.getActiveDay() ??
          await widget.shiftRepository.getLatestDay();

      if (day != null) {
        final stats = await widget.shiftRepository.getDayStats(day);
        if (!mounted) return;
        setState(() {
          _day = day;
          _stats = stats;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialog.showSnackBar(context, 'Error loading Z-Reading: $e', isError: true);
    }
  }

  Future<void> _handlePrint() async {
    if (_day == null || _stats == null) {
      AppDialog.showSnackBar(context, 'No business day data to print.', isError: true);
      return;
    }

    FeedbackHelper.vibrate();
    setState(() => _isPrinting = true);

    try {
      final user = widget.authService.currentUser.value;
      final d = _day!;
      final st = _stats!;

      final actualCash = d.closingBalance > 0 ? d.closingBalance : st.expectedCash;
      final cashDiff = actualCash - st.expectedCash;

      final result = await PrinterService.printShiftEventReceipt(
        title: '*** Z-READING (DAY END REPORT) ***',
        dayNumber: d.dayNumber,
        shiftNumber: 1,
        cashierName: user?.displayName ?? d.openedBy,
        isEndReport: true,
        openedAt: d.openedAt,
        openingBalance: d.openingBalance,
        totalInvoices: st.totalInvoices,
        grossSales: st.grossSales,
        discount: st.totalDiscount,
        tax: st.totalTax,
        netSales: st.totalNetRevenue,
        cashSales: st.cashSales,
        cardSales: st.cardSales,
        otherSales: st.otherSales,
        paidIn: st.paidIn,
        paidOut: st.paidOut,
        expectedCash: st.expectedCash,
        actualCash: actualCash,
        cashDiff: cashDiff,
      );

      if (!mounted) return;
      setState(() => _isPrinting = false);

      if (result.success) {
        AppDialog.showSnackBar(context, 'Z-Reading report printed successfully.');
      } else {
        AppDialog.showSnackBar(context, 'Print failed: ${result.errorMessage}', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      AppDialog.showSnackBar(context, 'Printer error: $e', isError: true);
    }
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 13.5 : 12,
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
    final d = _day;
    final st = _stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Z READING (DAY END)',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : d == null || st == null
                      ? const Center(
                          child: Text(
                            'No business day records found.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Day Header Info Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: const Color(0xFFDC3545).withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Business Day #${d.dayNumber} (${d.status})',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      'Cashier: ${d.openedBy}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Total Net Day Revenue Highlight
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'TOTAL NET DAY REVENUE:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF9F1239),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.formatWithSymbol(st.totalNetRevenue),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFDC3545),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Full Day Sales Summary Card
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
                                      'DAY SALES SUMMARY',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                                    ),
                                    const Divider(height: 12),
                                    _buildRow('Total Invoices Count', '${st.totalInvoices} bills'),
                                    _buildRow('Gross Sales', CurrencyFormatter.formatWithSymbol(st.grossSales)),
                                    if (st.totalDiscount > 0)
                                      _buildRow('Discounts', '-${CurrencyFormatter.formatWithSymbol(st.totalDiscount)}', valueColor: AppColors.error),
                                    _buildRow('Net Sales', CurrencyFormatter.formatWithSymbol(st.grandTotalSales), isBold: true),
                                    if (st.totalReturnsCount > 0) ...[
                                      _buildRow(
                                        'Returns & Refunds (${st.totalReturnsCount} bills)',
                                        '-${CurrencyFormatter.formatWithSymbol(st.totalReturnsAmount)}',
                                        isBold: true,
                                        valueColor: AppColors.error,
                                      ),
                                    ],
                                    const Divider(height: 10),
                                    _buildRow('Final Net Day Revenue', CurrencyFormatter.formatWithSymbol(st.totalNetRevenue), isBold: true),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Payment & Tender Breakdown Card
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
                                    _buildRow('Cash Sales', CurrencyFormatter.formatWithSymbol(st.cashSales)),
                                    _buildRow('Card Sales', CurrencyFormatter.formatWithSymbol(st.cardSales)),
                                    if (st.qrSales > 0)
                                      _buildRow('QR / Online Sales', CurrencyFormatter.formatWithSymbol(st.qrSales)),
                                    if (st.creditSales > 0)
                                      _buildRow('Credit Sales', CurrencyFormatter.formatWithSymbol(st.creditSales)),
                                    if (st.otherSales > 0)
                                      _buildRow('Other Payments', CurrencyFormatter.formatWithSymbol(st.otherSales)),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Day Drawer Reconciliation Card
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
                                      'DRAWER RECONCILIATION',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                                    ),
                                    const Divider(height: 12),
                                    _buildRow('Opening Float', CurrencyFormatter.formatWithSymbol(d.openingBalance)),
                                    _buildRow('+ Cash Sales', CurrencyFormatter.formatWithSymbol(st.cashSales)),
                                    if (st.paidIn > 0)
                                      _buildRow('+ Paid In (Float additions)', CurrencyFormatter.formatWithSymbol(st.paidIn)),
                                    if (st.paidOut > 0)
                                      _buildRow('- Paid Out (Expenses)', '-${CurrencyFormatter.formatWithSymbol(st.paidOut)}', valueColor: AppColors.error),
                                    if (st.cashRefunds > 0)
                                      _buildRow('- Cash Returns / Refunds', '-${CurrencyFormatter.formatWithSymbol(st.cashRefunds)}', valueColor: AppColors.error),
                                    const Divider(height: 10),
                                    _buildRow('Expected Closing Cash', CurrencyFormatter.formatWithSymbol(st.expectedCash), isBold: true),
                                    if (d.closingBalance > 0) ...[
                                      _buildRow('Actual Cash Counted', CurrencyFormatter.formatWithSymbol(d.closingBalance), isBold: true),
                                      _buildRow(
                                        'OVER / SHORT',
                                        CurrencyFormatter.formatWithSymbol(d.closingBalance - st.expectedCash),
                                        isBold: true,
                                        valueColor: (d.closingBalance - st.expectedCash) >= 0 ? AppColors.success : AppColors.error,
                                      ),
                                    ],
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
                    backgroundColor: const Color(0xFFDC3545),
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
                    _isPrinting ? 'PRINTING Z-READING...' : 'PRINT Z-READING (DAY END)',
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
