import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Clean, ultra-lightweight 3-dots animated loader with text.
/// Zero gradient effects, zero heavy shadows, perfectly smooth for 1GB RAM Android devices.
class PosAnimatedLoader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Color dotColor;
  final double dotSize;
  final bool isDark;
  final bool showCard;

  const PosAnimatedLoader({
    super.key,
    this.title = 'Loading...',
    this.subtitle,
    this.dotColor = AppColors.primary,
    this.dotSize = 10.0,
    this.isDark = false,
    this.showCard = true,
    // Kept for signature compatibility
    IconData? icon,
    Color? primaryColor,
    Color? accentColor,
    double? size,
    double? progress,
  });

  @override
  State<PosAnimatedLoader> createState() => _PosAnimatedLoaderState();
}

class _PosAnimatedLoaderState extends State<PosAnimatedLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    final start = index * 0.2;
    final end = start + 0.5;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        double scale = 0.5;
        double opacity = 0.35;

        if (val >= start && val <= end) {
          final t = (val - start) / (end - start);
          // Sine curve for smooth up and down bounce
          final curve = (t < 0.5) ? t * 2 : (1.0 - t) * 2;
          scale = 0.5 + (0.5 * curve);
          opacity = 0.35 + (0.65 * curve);
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          width: widget.dotSize,
          height: widget.dotSize,
          transform: Matrix4.diagonal3Values(scale, scale, 1.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.dotColor.withOpacity(opacity),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : AppColors.textPrimary;
    final subColor = widget.isDark ? Colors.white70 : AppColors.textSecondary;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 3 Animated Dots
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        ),

        const SizedBox(height: 14),

        // Text
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),

        if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: subColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (!widget.showCard) {
      return content;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 36),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF24303F) : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.isDark ? Colors.white24 : AppColors.border,
          width: 1.0,
        ),
      ),
      child: content,
    );
  }
}
