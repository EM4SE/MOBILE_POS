import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';
import '../controllers/pos_controller.dart';

/// Clean, Responsive Full Dedicated Screen for Item Returns & Refunds (No Credit)
class ReturnScreen extends StatefulWidget {
  final PosController controller;

  const ReturnScreen({
    super.key,
    required this.controller,
  });

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  String _selectedMethod = 'Cash';
  String _selectedReason = 'Customer Return';
  final TextEditingController _customReasonController = TextEditingController();
  bool _isProcessing = false;

  // Refund Payment Methods (WITHOUT Credit)
  final List<Map<String, dynamic>> _refundMethods = const [
    {'name': 'Cash', 'icon': Icons.payments_outlined, 'color': Color(0xFF107C41)},
    {'name': 'Card', 'icon': Icons.credit_card, 'color': Color(0xFF0078D4)},
    {'name': 'Bank Transfer', 'icon': Icons.account_balance_outlined, 'color': Color(0xFF5B5FC7)},
    {'name': 'QR / Mobile', 'icon': Icons.qr_code, 'color': Color(0xFFD83B01)},
  ];

  final List<String> _reasons = [
    'Customer Return',
    'Defective Item',
    'Wrong Item Purchased',
    'Exchange Difference',
    'Other Reason',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    FeedbackHelper.vibrate();
    setState(() => _isProcessing = true);

    final reason = _selectedReason == 'Other Reason' && _customReasonController.text.trim().isNotEmpty
        ? _customReasonController.text.trim()
        : _selectedReason;

    try {
      final sale = await widget.controller.processReturn(
        paymentMethod: _selectedMethod,
        reason: reason,
      );
      if (!mounted) return;
      AppDialog.showSnackBar(
        context,
        'Return ${sale.invoiceNo} completed via $_selectedMethod (${CurrencyFormatter.formatWithSymbol(sale.grandTotal)})',
      );
      Navigator.of(context).popUntil((route) => route.settings.name == AppRoutes.pos || route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppDialog.showSnackBar(context, 'Return failed: $e', isError: true);
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
        title: 'ITEM RETURN & REFUND',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content Area (Prevents any overflow on small POS screens)
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

                    // Returned Items Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RETURNED ITEMS (${widget.controller.totalItemCount} QTY)',
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

                    // Returned Items List Box
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

                    const SizedBox(height: 10),

                    // Refund Payment Method Selector
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REFUND PAYMENT METHOD (NO CREDIT):',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: _refundMethods.map((m) {
                              final name = m['name'] as String;
                              final icon = m['icon'] as IconData;
                              final isSelected = _selectedMethod == name;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: InkWell(
                                    onTap: () {
                                      FeedbackHelper.vibrate();
                                      setState(() => _selectedMethod = name);
                                    },
                                    child: Container(
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFE11D48) : AppColors.surfaceSecondary,
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFFE11D48) : AppColors.border,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            icon,
                                            size: 16,
                                            color: isSelected ? Colors.white : AppColors.textPrimary,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),

                          // Return Reason Dropdown
                          Row(
                            children: [
                              const Text('Reason: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedReason,
                                      isExpanded: true,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedReason = val);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_selectedReason == 'Other Reason') ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 34,
                              child: TextField(
                                controller: _customReasonController,
                                style: const TextStyle(fontSize: 11.5),
                                decoration: InputDecoration(
                                  hintText: 'Specify return reason details...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Total Refund Amount Banner
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
                              'TOTAL REFUND PAYABLE:',
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
                            CurrencyFormatter.formatWithSymbol(totalAmount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE11D48),
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
                          backgroundColor: const Color(0xFFE11D48),
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
                          _isProcessing ? 'PROCESSING...' : 'REFUND & PRINT RECEIPT',
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
