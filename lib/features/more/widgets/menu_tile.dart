import 'package:flutter/material.dart';
import '../../../app/theme/app_dimensions.dart';

/// Flat, sharp-cornered rectangular tile inspired by Windows 8 Modern UI / Metro Design
class MenuTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color backgroundColor;
  final VoidCallback onTap;
  final String? badgeText;

  const MenuTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.backgroundColor,
    required this.onTap,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
