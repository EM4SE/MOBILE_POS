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

class ItemWiseSalesScreen extends StatefulWidget {
  final SalesRepository salesRepository;
  final AuthenticationService authService;

  const ItemWiseSalesScreen({
    super.key,
    required this.salesRepository,
    required this.authService,
  });

  @override
  State<ItemWiseSalesScreen> createState() => _ItemWiseSalesScreenState();
}

class _ItemWiseSalesScreenState extends State<ItemWiseSalesScreen> {
  String _selectedPeriod = 'Today'; // 'Today' or 'All Time'
  bool _isLoading = true;
  bool _isPrinting = false;
  List<ItemWiseSaleReportItem> _items = [];

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
      final results = await widget.salesRepository.getItemWiseSalesReport(dateFilter: dateFilter);
      if (!mounted) return;
      setState(() {
        _items = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialog.showSnackBar(context, 'Error loading report: $e', isError: true);
    }
  }

  double get _totalQuantity => _items.fold(0.0, (sum, i) => sum + i.quantity);
  double get _totalRevenue => _items.fold(0.0, (sum, i) => sum + i.totalAmount);

  Future<void> _handlePrint() async {
    if (_items.isEmpty) {
      AppDialog.showSnackBar(context, 'No sales records to print for this period.', isError: true);
      return;
    }

    FeedbackHelper.vibrate();
    setState(() => _isPrinting = true);

    try {
      final cashier = widget.authService.currentUser.value?.displayName ?? 'Admin';
      final payloadItems = _items.map((i) => i.toMap()).toList();

      final result = await PrinterService.printItemWiseSalesReport(
        title: '*** ITEM WISE SALES REPORT ***',
        period: _selectedPeriod,
        cashierName: cashier,
        totalQuantity: _totalQuantity,
        totalRevenue: _totalRevenue,
        items: payloadItems,
      );

      if (!mounted) return;
      setState(() => _isPrinting = false);

      if (result.success) {
        AppDialog.showSnackBar(context, 'Item Wise Sales Report printed successfully.');
      } else {
        AppDialog.showSnackBar(context, 'Print failed: ${result.errorMessage}', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      AppDialog.showSnackBar(context, 'Printer error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'ITEM WISE SALES REPORT',
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
                  : _items.isEmpty
                      ? const Center(
                          child: Text(
                            'No sales recorded for this period.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Summary Stats Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'TOTAL ITEMS SOLD',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                                        ),
                                        Text(
                                          CurrencyFormatter.formatQuantity(_totalQuantity),
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'TOTAL REVENUE',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                                        ),
                                        Text(
                                          CurrencyFormatter.formatWithSymbol(_totalRevenue),
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Items Header
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'PRODUCT ITEMS (${_items.length} UNIQUE)',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                                    ),
                                    const Text('QTY & REVENUE', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Items List
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                                  itemBuilder: (ctx, index) {
                                    final item = _items[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.description,
                                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Qty Sold: ${CurrencyFormatter.formatQuantity(item.quantity)}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.formatWithSymbol(item.totalAmount),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
                    backgroundColor: const Color(0xFF0891B2),
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
                    _isPrinting ? 'PRINTING REPORT...' : 'PRINT ITEM WISE REPORT',
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
