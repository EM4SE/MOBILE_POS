import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

enum AppButtonVariant { primary, secondary, success, danger, warning, outline, dark }

/// Reusable commercial POS action button with sharp corners and touch target optimization
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final double? width;
  final double? height;
  final bool isLoading;
  final double fontSize;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.width,
    this.height = AppDimensions.buttonHeight,
    this.isLoading = false,
    this.fontSize = 15.0,
  });

  Color _getBackgroundColor() {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.accent;
      case AppButtonVariant.success:
        return AppColors.success;
      case AppButtonVariant.danger:
        return AppColors.error;
      case AppButtonVariant.warning:
        return AppColors.warning;
      case AppButtonVariant.dark:
        return AppColors.headerBackground;
      case AppButtonVariant.outline:
        return Colors.transparent;
    }
  }

  Color _getTextColor() {
    if (variant == AppButtonVariant.outline) {
      return AppColors.primary;
    }
    return AppColors.textOnPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _getBackgroundColor();
    final fg = _getTextColor();

    final buttonChild = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: AppDimensions.sm),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: onPressed == null ? AppColors.border : bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          side: variant == AppButtonVariant.outline
              ? const BorderSide(color: AppColors.primary, width: AppDimensions.borderWidth)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
            child: buttonChild,
          ),
        ),
      ),
    );
  }
}
