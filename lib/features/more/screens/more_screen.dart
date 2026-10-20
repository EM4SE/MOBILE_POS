import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/cashier_permissions_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_button.dart';
import '../../pos/controllers/pos_controller.dart';
import '../../../data/repositories/product_repository.dart';
import '../../products/controllers/product_controller.dart';

/// 3-Per-Row Square Grid Action Menu for Cashier & POS Operations with Permission Control
class MoreScreen extends StatefulWidget {
  final AuthenticationService authService;
  final PosController posController;
  final ProductRepository? productRepository;
  final ProductController? productController;
  final CashierPermissionsService? permissionsService;

  const MoreScreen({
    super.key,
    required this.authService,
    required this.posController,
    this.productRepository,
    this.productController,
    this.permissionsService,
  });

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Map<String, bool> _permissions = {};

  @override
  void initState() {
    super.initState();
    _loadCashierPermissions();
  }

  Future<void> _loadCashierPermissions() async {
    final user = widget.authService.currentUser.value;
    if (user == null || user.isAdmin || widget.permissionsService == null) {
      return;
    }
    final perms = await widget.permissionsService!.getPermissionsForCashier(user.username);
    if (mounted) {
      setState(() {
        _permissions = perms;
      });
    }
  }

  bool _isAllowed(String featureId) {
    final user = widget.authService.currentUser.value;
    if (user == null || user.isAdmin) return true;
    return _permissions[featureId] ?? true;
  }

  void _showAccessDeniedDialog(BuildContext context, String featureName) {
    FeedbackHelper.vibrate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('ACCESS RESTRICTED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'You do not have permission to access "$featureName".\n\nPlease contact an Admin cashier to enable access for your account in Settings > Cashier Permissions.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          AppButton(
            label: 'OK',
            variant: AppButtonVariant.primary,
            width: 90,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Logout Session',
      message: 'Are you sure you want to end your current session and return to PIN login?',
      confirmLabel: 'Logout',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed && context.mounted) {
      widget.authService.logout();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  // ---------------------------------------------------------------------------
  // Action: EXCHANGE (Dedicated Screen)
  // ---------------------------------------------------------------------------
  void _handleExchange(BuildContext context) {
    FeedbackHelper.vibrate();
    if (widget.posController.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items to cart before issuing exchange.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.exchange);
  }

  // ---------------------------------------------------------------------------
  // Action: RETURN (Dedicated Screen)
  // ---------------------------------------------------------------------------
  void _handleReturn(BuildContext context) {
    FeedbackHelper.vibrate();
    if (widget.posController.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items to cart to process a return.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.returnItem);
  }

  // ---------------------------------------------------------------------------
  // Action: DISCOUNT
  // ---------------------------------------------------------------------------
  Future<void> _handleDiscount(BuildContext context) async {
    FeedbackHelper.vibrate();
    if (widget.posController.cartItems.isEmpty) {
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
    if (widget.posController.cartItems.isNotEmpty) {
      final action = await _showCartConflictDialog(
        context,
        title: 'NEW BILL - CART HAS ITEMS',
        message: 'The current cart has items in progress.\nPlease choose to Hold or Void the bill before starting a new bill.',
      );

      if (action == 'HOLD') {
        final heldSale = await widget.posController.holdCurrentBill(printReceipt: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill held (${heldSale.invoiceNo}) & receipt printed. Ready for new bill.'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      } else if (action == 'VOID') {
        widget.posController.clearCart();
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
          backgroundColor: AppColors.primary,
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
    if (widget.posController.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is already empty.'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await AppDialog.confirm(
      context,
      title: 'Void Current Bill',
      message: 'Are you sure you want to void all ${widget.posController.cartItems.length} items from the current cart?',
      confirmLabel: 'Void Bill',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed && context.mounted) {
      widget.posController.clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill has been voided successfully.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<String?> _showCartConflictDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
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
  // Action: DOWNLOAD / SYNC ALL PRODUCTS FROM ERP
  // ---------------------------------------------------------------------------
  Future<void> _handleDownloadProducts(BuildContext context) async {
    FeedbackHelper.vibrate();

    if (widget.productRepository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product repository service is not initialized.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String currentStatus = 'Connecting to ERP server...';
    int itemCount = 0;
    bool isCompleted = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!isCompleted && errorMessage == null && itemCount == 0 && currentStatus == 'Connecting to ERP server...') {
            widget.productRepository!.syncProductsFromApi(
              onProgress: (count, status) {
                setDialogState(() {
                  itemCount = count;
                  currentStatus = status;
                });
              },
            ).then((totalCount) async {
              setDialogState(() {
                isCompleted = true;
                itemCount = totalCount;
                currentStatus = 'Successfully downloaded $totalCount products!';
              });
              await widget.productController?.loadProducts();
            }).catchError((err) {
              setDialogState(() {
                errorMessage = err.toString();
              });
            });
          }

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_outline
                      : (errorMessage != null ? Icons.error_outline : Icons.cloud_download_outlined),
                  color: isCompleted
                      ? AppColors.success
                      : (errorMessage != null ? AppColors.error : AppColors.primary),
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  isCompleted
                      ? 'DOWNLOAD COMPLETE'
                      : (errorMessage != null ? 'DOWNLOAD FAILED' : 'DOWNLOADING CATALOG'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCompleted && errorMessage == null) ...[
                  const LinearProgressIndicator(
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  errorMessage ?? currentStatus,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: errorMessage != null ? AppColors.error : AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                if (itemCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Stored in SQLite: $itemCount items',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                ],
              ],
            ),
            actions: [
              if (isCompleted || errorMessage != null)
                AppButton(
                  label: 'DONE',
                  variant: AppButtonVariant.primary,
                  width: 110,
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
            ],
          );
        },
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
    String? featureId,
    String? badgeText,
  }) {
    final bool allowed = featureId == null ? true : _isAllowed(featureId);
    final Color displayColor = allowed ? color : color.withOpacity(0.45);

    return Material(
      color: displayColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: allowed ? 2 : 0,
      child: InkWell(
        onTap: () {
          if (!allowed) {
            _showAccessDeniedDialog(context, label.replaceAll('\n', ' '));
          } else {
            FeedbackHelper.vibrate();
            onTap();
          }
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
            if (!allowed)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 10, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'LOCK',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (badgeText != null && allowed)
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
            animation: widget.posController,
            builder: (ctx, _) {
              final heldCount = widget.posController.heldBills.length;
              return GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
                children: [
                  // 1. NEW BILL
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.newBill,
                    label: 'NEW BILL',
                    icon: Icons.note_add_outlined,
                    color: const Color(0xFF0D6EFD), // POS Blue
                    onTap: () => _handleNewBill(context),
                  ),

                  // 2. VOID BILL
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.voidBill,
                    label: 'VOID BILL',
                    icon: Icons.delete_sweep_outlined,
                    color: const Color(0xFFDC3545), // Danger Red
                    onTap: () => _handleVoidBill(context),
                  ),

                  // 3. DISCOUNT (Percentage & Amount Discount)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.discount,
                    label: 'DISCOUNT',
                    icon: Icons.percent,
                    color: const Color(0xFF7C3AED), // Vibrant Purple
                    badgeText: widget.posController.discountAmount > 0
                        ? '-${CurrencyFormatter.formatWithSymbol(widget.posController.discountAmount)}'
                        : null,
                    onTap: () => _handleDiscount(context),
                  ),

                  // 4. EXCHANGE (Print Voucher with Barcode)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.exchange,
                    label: 'EXCHANGE',
                    icon: Icons.sync_alt,
                    color: const Color(0xFFEA580C), // Orange Amber
                    badgeText: widget.posController.cartItems.isNotEmpty ? '${widget.posController.totalItemCount}' : null,
                    onTap: () => _handleExchange(context),
                  ),

                  // 5. RETURN (Item Return & Refund Without Credit)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.returnItem,
                    label: 'RETURN',
                    icon: Icons.assignment_return,
                    color: const Color(0xFFE11D48), // Crimson Rose
                    badgeText: widget.posController.cartItems.isNotEmpty ? '${widget.posController.totalItemCount}' : null,
                    onTap: () => _handleReturn(context),
                  ),

                  // 6. HELD BILL (Dedicated Full Screen)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.heldBill,
                    label: 'HELD BILL',
                    icon: Icons.pause_circle_outline,
                    color: const Color(0xFFE67E22), // Amber Orange
                    badgeText: heldCount > 0 ? '$heldCount' : null,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.heldBills),
                  ),

                  // 7. PAID IN (Numeric Keypad Screen)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.paidIn,
                    label: 'PAID IN',
                    icon: Icons.arrow_downward,
                    color: const Color(0xFF198754), // Green
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.cashMovement, arguments: true),
                  ),

                  // 8. PAID OUTS (Numeric Keypad Screen)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.paidOut,
                    label: 'PAID OUTS',
                    icon: Icons.arrow_upward,
                    color: const Color(0xFFD97706), // Warm Amber
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.cashMovement, arguments: false),
                  ),

                  // 9. REPORTS (Item Wise, Total Sales, Z Reading, X Reading)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.reports,
                    label: 'REPORTS',
                    icon: Icons.analytics_outlined,
                    color: const Color(0xFF4F46E5), // Indigo
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.reports),
                  ),

                  // 10. CUSTOMERS
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.customers,
                    label: 'CUSTOMERS',
                    icon: Icons.people_outline,
                    color: const Color(0xFF0891B2), // Cyan/Teal
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.customers),
                  ),

                  // 11. PRODUCTS
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.products,
                    label: 'PRODUCTS',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF6366F1), // Indigo
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.products),
                  ),

                  // 12. DOWNLOAD PRODUCTS
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.downloadProducts,
                    label: 'DOWNLOAD\nPRODUCTS',
                    icon: Icons.cloud_download_outlined,
                    color: const Color(0xFF0284C7), // Sky Blue
                    onTap: () => _handleDownloadProducts(context),
                  ),

                  // 13. SETTINGS
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.settings,
                    label: 'SETTINGS',
                    icon: Icons.settings_outlined,
                    color: const Color(0xFF475569), // Slate
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),

                  // 14. SHIFT END (Cash Drawer Reconciliation & Day End)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.shiftEnd,
                    label: 'SHIFT END',
                    icon: Icons.schedule,
                    color: const Color(0xFFC026D3), // Magenta / Purple
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.endShift),
                  ),

                  // 15. POS BILLING / BACK (Always permitted)
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
