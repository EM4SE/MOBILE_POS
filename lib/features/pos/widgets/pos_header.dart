import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/authentication_service.dart';
import '../controllers/pos_controller.dart';

/// Top bar header specialized for POS billing screen with session status and quick action buttons
class PosHeader extends StatelessWidget implements PreferredSizeWidget {
  final PosController controller;
  final AuthenticationService authService;
  final VoidCallback onMorePressed;
  final VoidCallback onQuickAddProduct;
  final VoidCallback onSelectCustomer;
  final VoidCallback onOpenHeldBills;

  const PosHeader({
    super.key,
    required this.controller,
    required this.authService,
    required this.onMorePressed,
    required this.onQuickAddProduct,
    required this.onSelectCustomer,
    required this.onOpenHeldBills,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppDimensions.headerHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.headerHeight,
      color: AppColors.headerBackground,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Row(
        children: [
          // MORE button on top left
          Material(
            color: AppColors.tileProducts,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            ),
            child: InkWell(
              onTap: onMorePressed,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_view, color: AppColors.textOnPrimary, size: 18),
                    SizedBox(width: 5),
                    Text(
                      'MORE',
                      style: TextStyle(
                        color: AppColors.textOnPrimary,
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

          const SizedBox(width: AppDimensions.sm),

          // Header Title
          const Expanded(
            child: Text(
              'POS BILLING',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textOnDark,
                letterSpacing: 0.8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Customer Selector Button
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final customer = controller.selectedCustomer;
              return InkWell(
                onTap: onSelectCustomer,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: customer != null ? AppColors.tileCustomers.withAlpha(60) : Colors.black26,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                    border: Border.all(
                      color: customer != null ? AppColors.tileCustomers : AppColors.borderDark,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 15,
                        color: customer != null ? AppColors.success : AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 90),
                        child: Text(
                          customer != null ? customer.name : 'Walk-in',
                          style: const TextStyle(
                            color: AppColors.textOnDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: AppDimensions.xs),

          // Held Bills Badge
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final heldCount = controller.heldBills.length;
              if (heldCount == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Material(
                  color: AppColors.warning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                  child: InkWell(
                    onTap: onOpenHeldBills,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pause, size: 14, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            '$heldCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: AppDimensions.xs),

          // User Badge
          ValueListenableBuilder(
            valueListenable: authService.currentUser,
            builder: (context, user, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle, size: 15, color: AppColors.textOnDark),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 70),
                      child: Text(
                        user?.displayName ?? 'Admin',
                        style: const TextStyle(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
