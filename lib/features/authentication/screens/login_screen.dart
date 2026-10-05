import 'package:flutter/material.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/pos_animated_loader.dart';
import '../controllers/login_controller.dart';
import '../widgets/numeric_keypad.dart';

/// Fast, Touch-friendly POS Login screen with instant background pre-warming and rich loading overlay
class LoginScreen extends StatefulWidget {
  final LoginController controller;
  final ShiftService shiftService;

  const LoginScreen({
    super.key,
    required this.controller,
    required this.shiftService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isProcessing = false;
  String _statusMessage = 'Signing in...';

  @override
  void initState() {
    super.initState();
    // Preload active session in background so login to POS is instant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.shiftService.checkActiveSession();
    });
  }

  Future<void> _handleLogin() async {
    if (_isProcessing || widget.controller.pin.isEmpty) return;

    FeedbackHelper.vibrate();
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Authenticating PIN...';
    });

    try {
      final user = await widget.controller.login();
      if (!mounted) return;

      if (user != null) {
        setState(() {
          _statusMessage = 'Checking Shift & POS Workspace...';
        });

        await widget.shiftService.checkActiveSession();
        if (!mounted) return;

        if (!widget.shiftService.hasActiveDay) {
          // No active Day -> Route to Start Day & Shift
          Navigator.of(context).pushReplacementNamed(AppRoutes.startShift, arguments: true);
        } else if (!widget.shiftService.hasActiveShift) {
          // Active Day exists, but no active Shift -> Route to Start Shift
          Navigator.of(context).pushReplacementNamed(AppRoutes.startShift, arguments: false);
        } else {
          // Both active -> Route directly to POS
          Navigator.of(context).pushReplacementNamed(AppRoutes.pos);
        }
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Widget _buildPinDisplay() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pin = widget.controller.pin;
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
              color: widget.controller.errorMessage != null ? AppColors.error : AppColors.border,
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
              if (widget.controller.errorMessage != null) ...[
                const SizedBox(height: AppDimensions.xs),
                Text(
                  widget.controller.errorMessage!,
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

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: PosAnimatedLoader(
          title: _statusMessage,
          dotColor: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = ResponsiveHelper.isLandscape(context);
    final isLoading = _isProcessing || widget.controller.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
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
                            _buildPinDisplay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Section: Number Pad fitted to bottom and full screen width
                ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    return AbsorbPointer(
                      absorbing: isLoading,
                      child: Opacity(
                        opacity: isLoading ? 0.6 : 1.0,
                        child: NumericKeypad(
                          onDigitPressed: widget.controller.appendDigit,
                          onBackspace: widget.controller.backspace,
                          onClear: widget.controller.clearPin,
                          onSubmit: _handleLogin,
                          buttonHeight: isLandscape ? 58.0 : 64.0,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // High-grade animated loading screen overlay
          if (isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }
}
