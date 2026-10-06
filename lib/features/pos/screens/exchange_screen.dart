import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';
import '../controllers/pos_controller.dart';

/// Clean, Responsive Full Dedicated Screen for Issuing Exchange Vouchers
class ExchangeScreen extends StatefulWidget {
  final PosController controller;

  const ExchangeScreen({
    super.key,
    required this.controller,
  });

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  bool _isProcessing = false;

  Future<void> _handleConfirm() async {
    FeedbackHelper.vibrate();
    setState(() => _isProcessing = true);

    try {
      final voucher = await widget.controller.processExchange();
      if (!mounted) return;
      AppDialog.showSnackBar(
        context,
        'Exchange voucher ${voucher.voucherCode} issued (${CurrencyFormatter.formatWithSymbol(voucher.totalAmount)})',
      );
      Navigator.of(context).popUntil((route) => route.settings.name == AppRoutes.pos || route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppDialog.showSnackBar(context, 'Exchange failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.controller.cartItems;
    final totalAmount = widget.controller.subtotal - widget.controller.discountAmount;
    final customer = widget.controller.selectedCustomer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'EXCHANGE VOUCHER',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content Area (Prevents any overflow on small screens)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer banner if assigned
                    if (customer != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Customer: ${customer.name}${customer.phone.isNotEmpty ? " (${customer.phone})" : ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Exchanged Items Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'EXCHANGED ITEMS (${widget.controller.totalItemCount} QTY)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${items.length} Line Items',
                            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Exchanged Items List Box
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                        color: AppColors.surface,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (ctx, index) {
                          final item = items[index];
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productDescription,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Qty: ${item.quantity.toInt()}  ×  ${CurrencyFormatter.formatWithSymbol(item.unitPrice)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatWithSymbol(item.lineTotal),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Total Exchange Value Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'TOTAL CREDIT AMOUNT:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF9A3412),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatWithSymbol(totalAmount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                        child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          elevation: 1,
                        ),
                        onPressed: _isProcessing ? null : _handleConfirm,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print, size: 18),
                        label: Text(
                          _isProcessing ? 'PRINTING...' : 'ISSUE & PRINT VOUCHER',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
