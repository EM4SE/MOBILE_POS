import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../controllers/pos_controller.dart';

/// Clean Two-Tier POS Bottom Bar
/// Tier 1: Dedicated Details & Total Amount Bar (Items, Qty, Discounts, Total)
/// Tier 2: Action Bar (MORE, CUSTOMER, PAY NOW only)
class PosSummary extends StatelessWidget {
  final PosController controller;
  final VoidCallback onMorePressed;
  final VoidCallback onSelectCustomer;
  final VoidCallback onCheckout;

  const PosSummary({
    super.key,
    required this.controller,
    required this.onMorePressed,
    required this.onSelectCustomer,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final uniqueItems = controller.uniqueItemCount;
        final totalQty = controller.totalItemCount;
        final grandTotal = controller.grandTotal;
        final discount = controller.discountAmount;
        final isCartEmpty = controller.isCartEmpty;
        final customer = controller.selectedCustomer;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // -------------------------------------------------------------
              // TIER 1: Dedicated Details & Total Amount Calculation Bar
              // -------------------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9), // High contrast slate background
                  border: Border(
                    top: BorderSide(color: AppColors.borderDark, width: 1.2),
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Item count, total quantity & discount info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Items: $uniqueItems',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 12,
                                color: AppColors.borderDark,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Qty: $totalQty',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (discount > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Discount: -${CurrencyFormatter.formatWithSymbol(discount)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Right side: Prominent Grand Total Display
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'TOTAL: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatWithSymbol(grandTotal),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // -------------------------------------------------------------
              // TIER 2: Bottom Action Bar (MORE, CUSTOMER, PAY NOW only)
              // -------------------------------------------------------------
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: AppColors.surface,
                child: Row(
                  children: [
                    // 1. MORE Button
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tileProducts,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                          ),
                          onPressed: onMorePressed,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.grid_view, size: 18),
                              SizedBox(width: 5),
                              Text(
                                'MORE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // 2. CUSTOMER Button
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: customer != null ? const Color(0xFF107C41) : const Color(0xFF2C3E50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                          ),
                          onPressed: onSelectCustomer,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person, size: 18),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  customer != null ? customer.name : 'Customer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // 3. PAY NOW Button
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            disabledBackgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                          ),
                          onPressed: isCartEmpty ? null : onCheckout,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payments_outlined, size: 20),
                              SizedBox(width: 5),
                              Text(
                                'PAY NOW',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
