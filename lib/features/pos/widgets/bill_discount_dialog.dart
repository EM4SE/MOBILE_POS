import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../authentication/widgets/numeric_keypad.dart';
import '../controllers/pos_controller.dart';

/// Interactive dialog for applying Percentage (%) or Fixed Amount (LKR) discounts to current bill
class BillDiscountDialog extends StatefulWidget {
  final PosController posController;

  const BillDiscountDialog({
    super.key,
    required this.posController,
  });

  static Future<void> show(BuildContext context, PosController posController) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BillDiscountDialog(posController: posController),
    );
  }

  @override
  State<BillDiscountDialog> createState() => _BillDiscountDialogState();
}

class _BillDiscountDialogState extends State<BillDiscountDialog> {
  bool _isPercentage = true;
  String _inputBuffer = '';

  @override
  void initState() {
    super.initState();
    // If there's an existing discount, initialize with current amount
    if (widget.posController.discountAmount > 0) {
      final subtotal = widget.posController.subtotal;
      if (subtotal > 0) {
        final existingPct = (widget.posController.discountAmount / subtotal) * 100.0;
        if (existingPct == existingPct.roundToDouble()) {
          _isPercentage = true;
          _inputBuffer = existingPct.toInt().toString();
        } else {
          _isPercentage = false;
          _inputBuffer = widget.posController.discountAmount.toStringAsFixed(0);
        }
      }
    }
  }

  double get _subtotal => widget.posController.subtotal;

  double get _enteredValue {
    if (_inputBuffer.isEmpty) return 0.0;
    return double.tryParse(_inputBuffer) ?? 0.0;
  }

  double get _calculatedDiscountAmount {
    if (_isPercentage) {
      final pct = _enteredValue.clamp(0.0, 100.0);
      return (_subtotal * (pct / 100.0)).clamp(0.0, _subtotal);
    } else {
      return _enteredValue.clamp(0.0, _subtotal);
    }
  }

  double get _calculatedGrandTotal {
    return (_subtotal - _calculatedDiscountAmount).clamp(0.0, double.infinity);
  }

  void _onDigitPressed(String digit) {
    FeedbackHelper.vibrate();
    if (_inputBuffer.length >= 7) return;

    setState(() {
      if (_inputBuffer == '0') {
        _inputBuffer = digit;
      } else {
        _inputBuffer += digit;
      }
    });
  }

  void _onBackspace() {
    FeedbackHelper.vibrate();
    if (_inputBuffer.isNotEmpty) {
      setState(() {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      });
    }
  }

  void _onClear() {
    FeedbackHelper.vibrate();
    setState(() {
      _inputBuffer = '';
    });
  }

  void _applyPreset(num value) {
    FeedbackHelper.vibrate();
    setState(() {
      _inputBuffer = value.toString();
    });
  }

  void _onApply() {
    FeedbackHelper.playScanFeedback();
    widget.posController.setDiscount(_calculatedDiscountAmount);
    Navigator.of(context).pop();
  }

  void _onRemoveDiscount() {
    FeedbackHelper.vibrate();
    widget.posController.setDiscount(0.0);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pctPresets = [5, 10, 15, 20, 25, 50];
    final amtPresets = [50, 100, 200, 500, 1000];

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFF7C3AED), // Purple
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.percent, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'APPLY BILL DISCOUNT',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subtotal & Calculations Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BILL SUBTOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                            Text(CurrencyFormatter.formatWithSymbol(_subtotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('DISCOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
                            Text('-${CurrencyFormatter.formatWithSymbol(_calculatedDiscountAmount)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.warning)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('NEW TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                            Text(CurrencyFormatter.formatWithSymbol(_calculatedGrandTotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Mode Selector Toggle: Percentage vs Fixed Amount
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            FeedbackHelper.vibrate();
                            setState(() {
                              _isPercentage = true;
                              _inputBuffer = '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isPercentage ? const Color(0xFF7C3AED) : AppColors.surfaceSecondary,
                              border: Border.all(color: _isPercentage ? const Color(0xFF7C3AED) : AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.percent, size: 16, color: _isPercentage ? Colors.white : AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'PERCENTAGE (%)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: _isPercentage ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            FeedbackHelper.vibrate();
                            setState(() {
                              _isPercentage = false;
                              _inputBuffer = '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isPercentage ? const Color(0xFF7C3AED) : AppColors.surfaceSecondary,
                              border: Border.all(color: !_isPercentage ? const Color(0xFF7C3AED) : AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, size: 16, color: !_isPercentage ? Colors.white : AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'FIXED AMOUNT (LKR)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: !_isPercentage ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Display typed value
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPercentage ? 'Discount Percentage:' : 'Discount Amount:',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        Text(
                          _isPercentage
                              ? (_inputBuffer.isEmpty ? '0 %' : '$_inputBuffer %')
                              : (_inputBuffer.isEmpty ? 'LKR 0.00' : 'LKR $_inputBuffer'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Preset Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: (_isPercentage ? pctPresets : amtPresets).map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _applyPreset(preset),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                _isPercentage ? '$preset%' : 'LKR $preset',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Number Pad Component
            NumericKeypad(
              buttonHeight: 44.0,
              onDigitPressed: _onDigitPressed,
              onBackspace: _onBackspace,
              onClear: _onClear,
              onSubmit: _onApply,
              submitLabel: 'APPLY',
              submitIcon: Icons.check,
            ),

            // Clear discount footer if already set
            if (widget.posController.discountAmount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('REMOVE DISCOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: _onRemoveDiscount,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
