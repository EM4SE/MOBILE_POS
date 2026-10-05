import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

/// Seamless full-width touch keypad with guaranteed instant visual touch highlight
class NumericKeypad extends StatelessWidget {
  final void Function(String digit) onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback? onClear;
  final VoidCallback onSubmit;
  final String submitLabel;
  final IconData? submitIcon;
  final Color? submitBackgroundColor;
  final Color? submitPressedColor;
  final double buttonHeight;

  const NumericKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    this.onClear,
    required this.onSubmit,
    this.submitLabel = '',
    this.submitIcon,
    this.submitBackgroundColor,
    this.submitPressedColor,
    this.buttonHeight = 68.0,
  });

  Widget _buildNumberKey(String number) {
    return _KeypadButton(
      height: buttonHeight,
      backgroundColor: AppColors.surface,
      pressedColor: const Color(0xFFB8DCF5), // High-visibility tactile blue highlight
      onTap: () => onDigitPressed(number),
      child: Text(
        number,
        style: AppTextStyles.keypadNumber.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderDark, width: 1.0),
        ),
      ),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: const TableBorder(
          horizontalInside: BorderSide(color: AppColors.border, width: 0.75),
          verticalInside: BorderSide(color: AppColors.border, width: 0.75),
        ),
        children: [
          // Row 1: 1, 2, 3
          TableRow(
            children: [
              _buildNumberKey('1'),
              _buildNumberKey('2'),
              _buildNumberKey('3'),
            ],
          ),
          // Row 2: 4, 5, 6
          TableRow(
            children: [
              _buildNumberKey('4'),
              _buildNumberKey('5'),
              _buildNumberKey('6'),
            ],
          ),
          // Row 3: 7, 8, 9
          TableRow(
            children: [
              _buildNumberKey('7'),
              _buildNumberKey('8'),
              _buildNumberKey('9'),
            ],
          ),
          // Row 4: Backspace (⌫), 0, Submit (✓ / Enter)
          TableRow(
            children: [
              _KeypadButton(
                height: buttonHeight,
                backgroundColor: AppColors.surfaceSecondary,
                pressedColor: const Color(0xFFFCA5A5), // Vivid soft red highlight
                onTap: onBackspace,
                onLongPress: onClear ?? onBackspace,
                child: const Icon(
                  Icons.backspace_outlined,
                  size: 26,
                  color: AppColors.error,
                ),
              ),
              _buildNumberKey('0'),
              _KeypadButton(
                height: buttonHeight,
                backgroundColor: submitBackgroundColor ?? AppColors.primary,
                pressedColor: submitPressedColor ?? const Color(0xFF003855), // Darker highlight
                onTap: onSubmit,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (submitIcon != null || submitLabel.isEmpty) ...[
                      Icon(submitIcon ?? Icons.check, size: 24, color: Colors.white),
                      if (submitLabel.isNotEmpty) const SizedBox(width: AppDimensions.xs),
                    ],
                    if (submitLabel.isNotEmpty)
                      Text(
                        submitLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual keypad button with guaranteed instant visual touch highlight
class _KeypadButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color backgroundColor;
  final Color pressedColor;
  final double height;

  const _KeypadButton({
    required this.child,
    required this.onTap,
    this.onLongPress,
    required this.backgroundColor,
    required this.pressedColor,
    required this.height,
  });

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    widget.onTap();
    // Keep highlight visible for 120ms so even fast taps flash clearly
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _isPressed = false);
    });
  }

  void _handleTapCancel() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _isPressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 40),
        height: widget.height,
        color: _isPressed ? widget.pressedColor : widget.backgroundColor,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
