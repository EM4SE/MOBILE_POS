import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_button.dart';
import '../../pos/controllers/pos_controller.dart';

/// 3-Per-Row Square Grid Action Menu for Cashier & POS Operations
class MoreScreen extends StatelessWidget {
  final AuthenticationService authService;
  final PosController posController;

  const MoreScreen({
    super.key,
    required this.authService,
    required this.posController,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Logout Session',
      message: 'Are you sure you want to end your current session and return to PIN login?',
      confirmLabel: 'Logout',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed && context.mounted) {
      authService.logout();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  // ---------------------------------------------------------------------------
  // Action: DISCOUNT
  // ---------------------------------------------------------------------------
  Future<void> _handleDiscount(BuildContext context) async {
    FeedbackHelper.vibrate();
    if (posController.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot apply discount to an empty bill.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).pushNamed(AppRoutes.discount);
  }

  // ---------------------------------------------------------------------------
  // Action: NEW BILL
  // ---------------------------------------------------------------------------
  Future<void> _handleNewBill(BuildContext context) async {
    FeedbackHelper.vibrate();
    if (posController.cartItems.isNotEmpty) {
      final action = await _showCartConflictDialog(
        context,
        title: 'NEW BILL - CART HAS ITEMS',
        message: 'The current cart has items in progress.\nPlease choose to Hold or Void the bill before starting a new bill.',
      );

      if (action == 'HOLD') {
        await posController.holdCurrentBill();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current bill held. Ready for new bill.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      } else if (action == 'VOID') {
        posController.clearCart();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current bill voided. Ready for new bill.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New bill is ready.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Action: VOID BILL
  // ---------------------------------------------------------------------------
  Future<void> _handleVoidBill(BuildContext context) async {
    FeedbackHelper.vibrate();
    if (posController.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active bill to void.'),
          backgroundColor: AppColors.info,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await AppDialog.confirm(
      context,
      title: 'VOID BILL',
      message: 'Are you sure you want to void and clear all ${posController.totalItemCount} items from the current bill?',
      confirmLabel: 'VOID BILL',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed && context.mounted) {
      posController.clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill voided successfully.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Dialog: Cart Conflict when Starting New Bill
  // ---------------------------------------------------------------------------
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
                  child: const Text('VOID BILL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
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
                  child: const Text('HOLD BILL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build Square Menu Button Tile (3 per row)
  // ---------------------------------------------------------------------------
  Widget _buildSquareTile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return Material(
      color: color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 2,
      child: InkWell(
        onTap: () {
          FeedbackHelper.vibrate();
          onTap();
        },
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, size: 28, color: Colors.white),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (badgeText != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MORE MENU'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to POS',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: AppColors.error),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
          const SizedBox(width: AppDimensions.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: AnimatedBuilder(
            animation: posController,
            builder: (ctx, _) {
              final heldCount = posController.heldBills.length;
              return GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
                children: [
                  // 1. NEW BILL
                  _buildSquareTile(
                    context: context,
                    label: 'NEW BILL',
                    icon: Icons.note_add_outlined,
                    color: const Color(0xFF0D6EFD), // POS Blue
                    onTap: () => _handleNewBill(context),
                  ),

                  // 2. VOID BILL
                  _buildSquareTile(
                    context: context,
                    label: 'VOID BILL',
                    icon: Icons.delete_sweep_outlined,
                    color: const Color(0xFFDC3545), // Danger Red
                    onTap: () => _handleVoidBill(context),
                  ),

                  // 3. DISCOUNT (Percentage & Amount Discount)
                  _buildSquareTile(
                    context: context,
                    label: 'DISCOUNT',
                    icon: Icons.percent,
                    color: const Color(0xFF7C3AED), // Vibrant Purple
                    badgeText: posController.discountAmount > 0
                        ? '-${CurrencyFormatter.formatWithSymbol(posController.discountAmount)}'
                        : null,
                    onTap: () => _handleDiscount(context),
                  ),

                  // 4. HELD BILL (Dedicated Full Screen)
                  _buildSquareTile(
                    context: context,
                    label: 'HELD BILL',
                    icon: Icons.pause_circle_outline,
                    color: const Color(0xFFE67E22), // Amber Orange
                    badgeText: heldCount > 0 ? '$heldCount' : null,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.heldBills),
                  ),

                  // 5. PAID IN (Numeric Keypad Screen)
                  _buildSquareTile(
                    context: context,
                    label: 'PAID IN',
                    icon: Icons.arrow_downward,
                    color: const Color(0xFF198754), // Green
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.cashMovement, arguments: true),
                  ),

                  // 6. PAID OUTS (Numeric Keypad Screen)
                  _buildSquareTile(
                    context: context,
                    label: 'PAID OUTS',
                    icon: Icons.arrow_upward,
                    color: const Color(0xFFD97706), // Warm Amber
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.cashMovement, arguments: false),
                  ),

                  // 7. CUSTOMERS
                  _buildSquareTile(
                    context: context,
                    label: 'CUSTOMERS',
                    icon: Icons.people_outline,
                    color: const Color(0xFF0891B2), // Cyan/Teal
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.customers),
                  ),

                  // 8. PRODUCTS
                  _buildSquareTile(
                    context: context,
                    label: 'PRODUCTS',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF6366F1), // Indigo
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.products),
                  ),

                  // 9. SETTINGS
                  _buildSquareTile(
                    context: context,
                    label: 'SETTINGS',
                    icon: Icons.settings_outlined,
                    color: const Color(0xFF475569), // Slate
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),

                  // 10. SHIFT END (Cash Drawer Reconciliation & Day End)
                  _buildSquareTile(
                    context: context,
                    label: 'SHIFT END',
                    icon: Icons.schedule,
                    color: const Color(0xFFC026D3), // Magenta / Purple
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.endShift),
                  ),

                  // 11. POS BILLING / BACK
                  _buildSquareTile(
                    context: context,
                    label: 'POS BILLING',
                    icon: Icons.point_of_sale,
                    color: const Color(0xFF0F766E), // Dark Teal
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
