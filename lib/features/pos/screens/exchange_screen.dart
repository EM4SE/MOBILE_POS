import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';
import '../controllers/pos_controller.dart';

/// Full Dedicated Screen for Issuing Exchange Vouchers with Barcode Printing
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
        'Exchange voucher ${voucher.voucherCode} issued successfully (${CurrencyFormatter.formatWithSymbol(voucher.totalAmount)})',
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
            // Top Highlights Banner
            Container(
              color: const Color(0xFFFFF7ED),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                    ),
                    child: const Icon(Icons.sync_alt, color: Color(0xFFEA580C), size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXCHANGE VOUCHER ISSUANCE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF9A3412),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Prints an Exchange Receipt with scannable barcode for future purchases',
                          style: TextStyle(fontSize: 11, color: Color(0xFFC2410C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFFDBA74)),

            // Customer banner if assigned
            if (customer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.surfaceSecondary,
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Customer: ${customer.name}${customer.phone.isNotEmpty ? " (${customer.phone})" : ""}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),

            // Exchanged Items Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EXCHANGED ITEMS (${widget.controller.totalItemCount} TOTAL QTY)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${items.length} Distinct Line Items',
                    style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            ),

            // Items List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productDescription,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Qty: ${item.quantity.toInt()}  ×  ${CurrencyFormatter.formatWithSymbol(item.unitPrice)}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatWithSymbol(item.lineTotal),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Summary Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7ED),
                border: Border(
                  top: BorderSide(color: Color(0xFFFDBA74), width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL VOUCHER CREDIT AMOUNT:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF9A3412)),
                      ),
                      Text(
                        CurrencyFormatter.formatWithSymbol(totalAmount),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, size: 16, color: Color(0xFFC2410C)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'The customer can redeem this voucher on any future bill by scanning its receipt barcode.',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF9A3412), height: 1.2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Fixed Bottom Action Buttons
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                        child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
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
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print, size: 20),
                        label: Text(
                          _isProcessing ? 'PRINTING VOUCHER...' : 'ISSUE & PRINT VOUCHER',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.5),
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
