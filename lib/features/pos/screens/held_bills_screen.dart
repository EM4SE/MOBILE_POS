import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../data/models/sale_model.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_button.dart';
import '../controllers/pos_controller.dart';

/// Compact Single-Row Held Bills Management Screen
class HeldBillsScreen extends StatelessWidget {
  final PosController posController;

  const HeldBillsScreen({
    super.key,
    required this.posController,
  });

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day/$month/$year  $hour:$minute $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _handleRecall(BuildContext context, Sale heldBill) async {
    FeedbackHelper.vibrate();

    // If current cart has items, prompt the user first
    if (posController.cartItems.isNotEmpty) {
      final action = await _showCartConflictDialog(
        context,
        title: 'RECALL BILL - CART NOT EMPTY',
        message: 'The active cart contains ${posController.totalItemCount} items.\nChoose to Hold or Void the current bill before recalling this bill.',
      );

      if (action == null) return;

      if (action == 'HOLD') {
        await posController.holdCurrentBill();
      } else if (action == 'VOID') {
        posController.clearCart();
      }
    }

    await posController.resumeHeldBill(heldBill);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recalled bill: ${heldBill.invoiceNo}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
      // Return back to POS screen
      Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/pos');
    }
  }

  Future<void> _handleDiscard(BuildContext context, Sale heldBill) async {
    FeedbackHelper.vibrate();
    final confirmed = await AppDialog.confirm(
      context,
      title: 'DISCARD HELD BILL',
      message: 'Are you sure you want to permanently discard held bill ${heldBill.invoiceNo}?',
      confirmLabel: 'DISCARD',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed) {
      await posController.deleteHeldBill(heldBill);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discarded held bill ${heldBill.invoiceNo}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<String?> _showCartConflictDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop('VOID'),
                  child: const Text('VOID CART', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop('HOLD'),
                  child: const Text('HOLD CART', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
            ],
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
        title: AnimatedBuilder(
          animation: posController,
          builder: (ctx, _) {
            final count = posController.heldBills.length;
            return Text('HELD BILLS ($count)');
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: posController,
          builder: (ctx, _) {
            final heldBills = posController.heldBills;

            if (heldBills.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pause_circle_outline,
                        size: 64,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        'NO HELD BILLS',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      const Text(
                        'Bills put on hold during POS billing will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: heldBills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (itemCtx, index) {
                final bill = heldBills[index];

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // 1. Left: Invoice No & Date/Time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bill.invoiceNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: AppColors.accent,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateTime(bill.createdAt),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 6),

                      // 2. Middle: Total Amount
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.formatWithSymbol(bill.grandTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: AppColors.success,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // 3. Right: Single Row Action Buttons (Discard & Recall)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 19),
                            tooltip: 'Discard',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            onPressed: () => _handleDiscard(context, bill),
                          ),
                          const SizedBox(width: 2),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D6EFD), // POS Blue
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(48, 30),
                            ),
                            onPressed: () => _handleRecall(context, bill),
                            child: const Text(
                              'RECALL',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
