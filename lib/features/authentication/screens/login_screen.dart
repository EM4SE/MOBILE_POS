import 'package:flutter/material.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../controllers/login_controller.dart';
import '../widgets/numeric_keypad.dart';

/// Touch-friendly POS Login screen with pure numeric keypad and zero soft-keyboard popup
class LoginScreen extends StatelessWidget {
  final LoginController controller;
  final ShiftService shiftService;

  const LoginScreen({
    super.key,
    required this.controller,
    required this.shiftService,
  });

  Future<void> _handleLogin(BuildContext context) async {
    final user = await controller.login();
    if (user != null && context.mounted) {
      await shiftService.checkActiveSession();
      if (!context.mounted) return;

      if (!shiftService.hasActiveDay) {
        // No active Day -> Route to Start Day & Shift
        Navigator.of(context).pushReplacementNamed(AppRoutes.startShift, arguments: true);
      } else if (!shiftService.hasActiveShift) {
        // Active Day exists, but no active Shift -> Route to Start Shift
        Navigator.of(context).pushReplacementNamed(AppRoutes.startShift, arguments: false);
      } else {
        // Both active -> Route directly to POS
        Navigator.of(context).pushReplacementNamed(AppRoutes.pos);
      }
    }
  }

  Widget _buildPinDisplay(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pin = controller.pin;
        final hasPin = pin.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            border: Border.all(
              color: controller.errorMessage != null ? AppColors.error : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Masked dots or placeholder
              SizedBox(
                height: 36,
                child: Center(
                  child: hasPin
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pin.length, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        )
                      : Text(
                          'ENTER YOUR PIN',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textLight,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              // Error feedback
              if (controller.errorMessage != null) ...[
                const SizedBox(height: AppDimensions.xs),
                Text(
                  controller.errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = ResponsiveHelper.isLandscape(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Top Section: App Branding & PIN Display
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                    vertical: AppDimensions.sm,
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isLandscape ? 480.0 : 400.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Title Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppDimensions.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                                child: const Icon(
                                  Icons.point_of_sale_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.xs),
                              Text(
                                AppConstants.appName,
                                style: AppTextStyles.displaySmall.copyWith(
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark,
                                  fontSize: 24,
                                ),
                              ),
                              Text(
                                AppConstants.appTagline,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimensions.sm),

                        // PIN Display Card
                        _buildPinDisplay(context),

                        const SizedBox(height: AppDimensions.xs),

                        // Default PIN Quick Hint
                        const Text(
                          'Default PINs: Admin (1234) • Cashier (0000)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Section: Number Pad fitted to bottom and full screen width
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return AbsorbPointer(
                  absorbing: controller.isLoading,
                  child: Opacity(
                    opacity: controller.isLoading ? 0.6 : 1.0,
                    child: NumericKeypad(
                      onDigitPressed: controller.appendDigit,
                      onBackspace: controller.backspace,
                      onClear: controller.clearPin,
                      onSubmit: () => _handleLogin(context),
                      buttonHeight: isLandscape ? 58.0 : 64.0,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
