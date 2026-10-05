import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

/// Flat sharp-cornered Windows 8-style settings tile / list option
class SettingsTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor = AppColors.primary,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.border, width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primaryLight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                color: iconColor.withAlpha(25),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                trailing!,
              ] else ...[
                const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
