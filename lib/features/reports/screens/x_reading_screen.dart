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
import '../../../data/models/shift_model.dart';
import '../../../data/repositories/shift_repository.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';

class XReadingScreen extends StatefulWidget {
  final ShiftRepository shiftRepository;
  final ShiftService shiftService;
  final AuthenticationService authService;

  const XReadingScreen({
    super.key,
    required this.shiftRepository,
    required this.shiftService,
    required this.authService,
  });

  @override
  State<XReadingScreen> createState() => _XReadingScreenState();
}

class _XReadingScreenState extends State<XReadingScreen> {
  bool _isLoading = true;
  bool _isPrinting = false;
  Shift? _shift;
  BusinessDay? _day;
  ShiftSummaryStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadXReading();
  }

  Future<void> _loadXReading() async {
    setState(() => _isLoading = true);
    try {
      final shift = await widget.shiftRepository.getActiveShift() ??
          await widget.shiftRepository.getLatestShift();
      final day = await widget.shiftRepository.getActiveDay() ??
          await widget.shiftRepository.getLatestDay();

      if (shift != null) {
        final stats = await widget.shiftRepository.getShiftStats(shift);
        if (!mounted) return;
        setState(() {
          _shift = shift;
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
      AppDialog.showSnackBar(context, 'Error loading X-Reading: $e', isError: true);
    }
  }

  Future<void> _handlePrint() async {
    if (_shift == null || _stats == null) {
      AppDialog.showSnackBar(context, 'No active shift data to print.', isError: true);
      return;
    }

    FeedbackHelper.vibrate();
    setState(() => _isPrinting = true);

    try {
      final user = widget.authService.currentUser.value;
      final s = _shift!;
      final st = _stats!;

      final result = await PrinterService.printShiftEventReceipt(
        title: '*** X-READING (MID-SHIFT) ***',
        dayNumber: _day?.dayNumber ?? 1,
        shiftNumber: s.shiftNumber,
        cashierName: user?.displayName ?? s.cashierName,
        isEndReport: true,
        openedAt: s.openedAt,
        openingBalance: s.openingBalance,
        totalInvoices: st.totalInvoices,
        grossSales: st.grossSales,
        discount: st.totalDiscount,
        tax: st.totalTax,
        netSales: st.grandTotalSales,
        cashSales: st.cashSales,
        cardSales: st.cardSales,
        otherSales: st.otherSales,
        paidIn: st.paidIn,
        paidOut: st.paidOut,
        expectedCash: st.expectedCash,
        actualCash: st.expectedCash,
        cashDiff: 0.0,
      );

      if (!mounted) return;
      setState(() => _isPrinting = false);

      if (result.success) {
        AppDialog.showSnackBar(context, 'X-Reading report printed successfully.');
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
    final s = _shift;
    final st = _stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'X READING (MID-SHIFT)',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : s == null || st == null
                      ? const Center(
                          child: Text(
                            'No shift session available.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Shift Header Info Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: const Color(0xFFD97706).withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Day #${_day?.dayNumber ?? 1} • Shift #${s.shiftNumber} (${s.status})',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      'Cashier: ${s.cashierName}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Expected Drawer Balance Highlight
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'EXPECTED CASH IN DRAWER:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF92400E),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.formatWithSymbol(st.expectedCash),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Sales Summary Card
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
                                      'CURRENT SHIFT SALES SUMMARY',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                                    ),
                                    const Divider(height: 12),
                                    _buildRow('Invoices Count', '${st.totalInvoices} bills'),
                                    _buildRow('Gross Sales', CurrencyFormatter.formatWithSymbol(st.grossSales)),
                                    if (st.totalDiscount > 0)
                                      _buildRow('Discounts', '-${CurrencyFormatter.formatWithSymbol(st.totalDiscount)}', valueColor: AppColors.error),
                                    _buildRow('Net Sales', CurrencyFormatter.formatWithSymbol(st.grandTotalSales), isBold: true),
                                    if (st.totalReturnsCount > 0)
                                      _buildRow(
                                        'Returns & Refunds (${st.totalReturnsCount} bills)',
                                        '-${CurrencyFormatter.formatWithSymbol(st.totalReturnsAmount)}',
                                        isBold: true,
                                        valueColor: AppColors.error,
                                      ),
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
                                      'PAYMENTS BREAKDOWN',
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

                              // Cash Drawer Movement Card
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
                                      'CASH DRAWER AUDIT',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                                    ),
                                    const Divider(height: 12),
                                    _buildRow('Opening Float', CurrencyFormatter.formatWithSymbol(s.openingBalance)),
                                    _buildRow('+ Cash Sales', CurrencyFormatter.formatWithSymbol(st.cashSales)),
                                    _buildRow('+ Paid In (Cash Entry)', CurrencyFormatter.formatWithSymbol(st.paidIn)),
                                    _buildRow('- Paid Out (Cash Expense)', '-${CurrencyFormatter.formatWithSymbol(st.paidOut)}', valueColor: st.paidOut > 0 ? AppColors.error : null),
                                    if (st.cashRefunds > 0)
                                      _buildRow('- Cash Returns / Refunds', '-${CurrencyFormatter.formatWithSymbol(st.cashRefunds)}', valueColor: AppColors.error),
                                    const Divider(height: 10),
                                    _buildRow('Expected Cash in Hand', CurrencyFormatter.formatWithSymbol(st.expectedCash), isBold: true),
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
                    backgroundColor: const Color(0xFFD97706),
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
                    _isPrinting ? 'PRINTING X-READING...' : 'PRINT X-READING SLIP',
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
