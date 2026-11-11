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
import '../../../data/models/user_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/sync_log_repository.dart';
import '../../pos/controllers/pos_controller.dart';
import '../../products/controllers/product_controller.dart';
import '../widgets/pin_override_sheet.dart';

/// 3-Per-Row Square Grid Action Menu for Cashier & POS Operations with Permission Control
class MoreScreen extends StatefulWidget {
  final AuthenticationService authService;
  final PosController posController;
  final ProductRepository? productRepository;
  final ProductController? productController;
  final CashierPermissionsService? permissionsService;
  final SyncLogRepository? syncLogRepository;

  const MoreScreen({
    super.key,
    required this.authService,
    required this.posController,
    this.productRepository,
    this.productController,
    this.permissionsService,
    this.syncLogRepository,
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

  Future<void> _handleRestrictedTileTap(
    BuildContext context, {
    required String featureId,
    required String featureName,
    required void Function(User? authorizedBy) onAuthorized,
  }) async {
    FeedbackHelper.vibrate();
    if (_isAllowed(featureId)) {
      onAuthorized(null);
      return;
    }

    if (widget.permissionsService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permission service unavailable to verify "$featureName".'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final currentUser = widget.authService.currentUser.value;
    final authorizer = await PinOverrideSheet.show(
      context,
      featureId: featureId,
      featureName: featureName,
      authService: widget.authService,
      permissionsService: widget.permissionsService!,
      currentCashierName: currentUser?.displayName,
      syncLogRepository: widget.syncLogRepository,
    );

    if (authorizer == null || !context.mounted) return;

    try {
      await widget.syncLogRepository?.logAction(
        actionType: 'USER_AUTH',
        title: 'One-Time Override: $featureName',
        details:
            'Cashier: ${currentUser?.displayName ?? "Unknown"} | Authorized by: ${authorizer.displayName} (${authorizer.username})',
        status: 'SUCCESS',
      );
    } catch (_) {}

    if (!context.mounted) return;
    onAuthorized(authorizer);
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
      widget.authService.logout(reason: 'More Menu Logout');
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  // ---------------------------------------------------------------------------
  // Action: EXCHANGE (Dedicated Screen)
  // ---------------------------------------------------------------------------
  void _handleExchange(BuildContext context, {User? authorizedBy}) {
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
    Navigator.of(context).pushNamed(AppRoutes.exchange, arguments: authorizedBy);
  }

  // ---------------------------------------------------------------------------
  // Action: RETURN (Dedicated Screen)
  // ---------------------------------------------------------------------------
  void _handleReturn(BuildContext context, {User? authorizedBy}) {
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
    Navigator.of(context).pushNamed(AppRoutes.returnItem, arguments: authorizedBy);
  }

  // ---------------------------------------------------------------------------
  // Action: DISCOUNT
  // ---------------------------------------------------------------------------
  Future<void> _handleDiscount(BuildContext context, {User? authorizedBy}) async {
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

    Navigator.of(context).pushNamed(AppRoutes.discount, arguments: authorizedBy);
  }

  // ---------------------------------------------------------------------------
  // Action: NEW BILL
  // ---------------------------------------------------------------------------
  Future<void> _handleNewBill(BuildContext context, {User? overrideCashier}) async {
    FeedbackHelper.vibrate();
    if (widget.posController.cartItems.isNotEmpty) {
      final action = await _showCartConflictDialog(
        context,
        title: 'NEW BILL - CART HAS ITEMS',
        message: 'The current cart has items in progress.\nPlease choose to Hold or Void the bill before starting a new bill.',
      );

      if (action == 'HOLD') {
        final heldSale = await widget.posController.holdCurrentBill(
          printReceipt: true,
          overrideCashier: overrideCashier,
        );
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
        widget.posController.clearCart(
          logVoid: true,
          overrideCashier: overrideCashier,
          reason: 'Bill Voided via New Bill',
        );
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
      try {
        await widget.syncLogRepository?.logAction(
          actionType: 'POS_ACTION',
          title: 'New Bill Started',
          details:
              'Cashier: ${(overrideCashier ?? widget.authService.currentUser.value)?.displayName ?? "Admin"}',
          status: 'SUCCESS',
        );
      } catch (_) {}
      if (!context.mounted) return;
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
  Future<void> _handleVoidBill(BuildContext context, {User? overrideCashier}) async {
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

    final itemCount = widget.posController.cartItems.length;
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Void Current Bill',
      message: 'Are you sure you want to void all $itemCount items from the current cart?',
      confirmLabel: 'Void Bill',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed && context.mounted) {
      widget.posController.clearCart(
        logVoid: true,
        overrideCashier: overrideCashier,
        reason: 'Bill Voided ($itemCount items)',
      );
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
  Future<void> _handleDownloadProducts(BuildContext context, {User? overrideCashier}) async {
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
              if (overrideCashier != null) {
                try {
                  await widget.syncLogRepository?.logAction(
                    actionType: 'USER_AUTH',
                    title: 'Product Download Authorized ($totalCount items)',
                    details: 'Authorized by: ${overrideCashier.displayName} (${overrideCashier.username})',
                    status: 'SUCCESS',
                  );
                } catch (_) {}
              }
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
    required void Function(User? authorizedBy) onTap,
    String? featureId,
    String? badgeText,
  }) {
    final bool allowed = featureId == null ? true : _isAllowed(featureId);
    final Color displayColor = allowed ? color : color.withOpacity(0.45);
    final String cleanLabel = label.replaceAll('\n', ' ');

    return Material(
      color: displayColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: allowed ? 2 : 0,
      child: InkWell(
        onTap: () {
          if (featureId != null && !allowed) {
            _handleRestrictedTileTap(
              context,
              featureId: featureId,
              featureName: cleanLabel,
              onAuthorized: onTap,
            );
          } else {
            FeedbackHelper.vibrate();
            onTap(null);
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
                    onTap: (auth) => _handleNewBill(context, overrideCashier: auth),
                  ),

                  // 2. VOID BILL
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.voidBill,
                    label: 'VOID BILL',
                    icon: Icons.delete_sweep_outlined,
                    color: const Color(0xFFDC3545), // Danger Red
                    onTap: (auth) => _handleVoidBill(context, overrideCashier: auth),
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
                    onTap: (auth) => _handleDiscount(context, authorizedBy: auth),
                  ),

                  // 4. EXCHANGE (Print Voucher with Barcode)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.exchange,
                    label: 'EXCHANGE',
                    icon: Icons.sync_alt,
                    color: const Color(0xFFEA580C), // Orange Amber
                    badgeText: widget.posController.cartItems.isNotEmpty ? '${widget.posController.totalItemCount}' : null,
                    onTap: (auth) => _handleExchange(context, authorizedBy: auth),
                  ),

                  // 5. RETURN (Item Return & Refund Without Credit)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.returnItem,
                    label: 'RETURN',
                    icon: Icons.assignment_return,
                    color: const Color(0xFFE11D48), // Crimson Rose
                    badgeText: widget.posController.cartItems.isNotEmpty ? '${widget.posController.totalItemCount}' : null,
                    onTap: (auth) => _handleReturn(context, authorizedBy: auth),
                  ),

                  // 6. HELD BILL (Dedicated Full Screen)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.heldBill,
                    label: 'HELD BILL',
                    icon: Icons.pause_circle_outline,
                    color: const Color(0xFFE67E22), // Amber Orange
                    badgeText: heldCount > 0 ? '$heldCount' : null,
                    onTap: (auth) => Navigator.of(context).pushNamed(AppRoutes.heldBills, arguments: auth),
                  ),

                  // 7. PAID IN (Numeric Keypad Screen)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.paidIn,
                    label: 'PAID IN',
                    icon: Icons.arrow_downward,
                    color: const Color(0xFF198754), // Green
                    onTap: (auth) => Navigator.of(context).pushNamed(
                      AppRoutes.cashMovement,
                      arguments: {'isPaidIn': true, 'authorizedBy': auth},
                    ),
                  ),

                  // 8. PAID OUTS (Numeric Keypad Screen)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.paidOut,
                    label: 'PAID OUTS',
                    icon: Icons.arrow_upward,
                    color: const Color(0xFFD97706), // Warm Amber
                    onTap: (auth) => Navigator.of(context).pushNamed(
                      AppRoutes.cashMovement,
                      arguments: {'isPaidIn': false, 'authorizedBy': auth},
                    ),
                  ),

                  // 9. REPORTS (Item Wise, Total Sales, Z Reading, X Reading)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.reports,
                    label: 'REPORTS',
                    icon: Icons.analytics_outlined,
                    color: const Color(0xFF4F46E5), // Indigo
                    onTap: (auth) => Navigator.of(context).pushNamed(AppRoutes.reports, arguments: auth),
                  ),

                  // 10. CUSTOMERS
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.customers,
                    label: 'CUSTOMERS',
                    icon: Icons.people_outline,
                    color: const Color(0xFF0891B2), // Cyan/Teal
                    onTap: (auth) => Navigator.of(context).pushNamed(
                      AppRoutes.customers,
                      arguments: {'authorizedBy': auth},
                    ),
                  ),

                  // 11. PRODUCTS
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.products,
                    label: 'PRODUCTS',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF6366F1), // Indigo
                    onTap: (auth) => Navigator.of(context).pushNamed(
                      AppRoutes.products,
                      arguments: {'authorizedBy': auth},
                    ),
                  ),

                  // 12. DOWNLOAD PRODUCTS
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.downloadProducts,
                    label: 'DOWNLOAD\nPRODUCTS',
                    icon: Icons.cloud_download_outlined,
                    color: const Color(0xFF0284C7), // Sky Blue
                    onTap: (auth) => _handleDownloadProducts(context, overrideCashier: auth),
                  ),

                  // 13. SETTINGS
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.settings,
                    label: 'SETTINGS',
                    icon: Icons.settings_outlined,
                    color: const Color(0xFF475569), // Slate
                    onTap: (auth) => Navigator.of(context)
                        .pushNamed(AppRoutes.settings, arguments: auth)
                        .then((_) => _loadCashierPermissions()),
                  ),

                  // 14. SHIFT END (Cash Drawer Reconciliation & Day End)
                  _buildSquareTile(
                    context: context,
                    featureId: PosFeature.shiftEnd,
                    label: 'SHIFT END',
                    icon: Icons.schedule,
                    color: const Color(0xFFC026D3), // Magenta / Purple
                    onTap: (auth) => Navigator.of(context).pushNamed(AppRoutes.endShift, arguments: auth),
                  ),

                  // 15. POS BILLING / BACK (Always permitted)
                  _buildSquareTile(
                    context: context,
                    label: 'POS BILLING',
                    icon: Icons.point_of_sale,
                    color: const Color(0xFF0F766E), // Dark Teal
                    onTap: (_) => Navigator.of(context).pop(),
                  ),

                  // 16. LOGOUT (Always permitted)
                  _buildSquareTile(
                    context: context,
                    label: 'LOGOUT',
                    icon: Icons.power_settings_new,
                    color: AppColors.tileLogout,
                    onTap: (_) => _handleLogout(context),
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
