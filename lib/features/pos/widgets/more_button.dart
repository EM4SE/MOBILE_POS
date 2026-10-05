import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';

/// Large flat MORE action button at the bottom of the POS screen
class MoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const MoreButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDark,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.apps, color: AppColors.textOnDark, size: 22),
              SizedBox(width: AppDimensions.sm),
              Text(
                'MORE',
                style: TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
