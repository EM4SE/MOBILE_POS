import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../controllers/pos_controller.dart';

/// Item Return & Refund Modal (Without Credit)
class ReturnDialog extends StatefulWidget {
  final PosController controller;

  const ReturnDialog({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, PosController controller) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReturnDialog(controller: controller),
    );
  }

  @override
  State<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<ReturnDialog> {
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
      Navigator.of(context).pop();
      AppDialog.showSnackBar(
        context,
        'Return ${sale.invoiceNo} processed via $_selectedMethod (${CurrencyFormatter.formatWithSymbol(sale.grandTotal)})',
      );
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

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                    ),
                    child: const Icon(Icons.assignment_return, color: Color(0xFFE11D48), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROCESS ITEM RETURN',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Refund items from cart (No credit)',
                          style: TextStyle(fontSize: 11, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const Divider(height: 20),

              // Customer info if assigned
              if (customer != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Customer: ${customer.name}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Exchanged Items Box
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  color: const Color(0xFFFAFAFA),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productDescription,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${item.quantity.toInt()} x ${CurrencyFormatter.formatWithSymbol(item.unitPrice)}',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatWithSymbol(item.lineTotal),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Refund Total Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL REFUND AMOUNT:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF9F1239)),
                    ),
                    Text(
                      CurrencyFormatter.formatWithSymbol(totalAmount),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFE11D48)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Refund Method Selector (NO CREDIT)
              const Text(
                'SELECT REFUND PAYMENT METHOD:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
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
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE11D48) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFE11D48) : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textPrimary),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 10),

              // Return Reason Dropdown
              Row(
                children: [
                  const Text('Reason: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedReason,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
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
                  height: 36,
                  child: TextField(
                    controller: _customReasonController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Specify return reason...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXs)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXs)),
                      ),
                      onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                      child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXs)),
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
                        _isProcessing ? 'PROCESSING...' : 'REFUND & PRINT',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
