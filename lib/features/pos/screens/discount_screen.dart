import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../authentication/widgets/numeric_keypad.dart';
import '../controllers/pos_controller.dart';

/// Full-screen Bill Discount Configuration (Percentage & Fixed Amount)
class DiscountScreen extends StatefulWidget {
  final PosController posController;

  const DiscountScreen({
    super.key,
    required this.posController,
  });

  @override
  State<DiscountScreen> createState() => _DiscountScreenState();
}

class _DiscountScreenState extends State<DiscountScreen> {
  bool _isPercentage = true;
  String _inputBuffer = '';

  @override
  void initState() {
    super.initState();
    // Preload existing discount
    final currentDiscount = widget.posController.discountAmount;
    final subtotal = widget.posController.subtotal;

    if (currentDiscount > 0 && subtotal > 0) {
      final existingPct = (currentDiscount / subtotal) * 100.0;
      if (existingPct == existingPct.roundToDouble()) {
        _isPercentage = true;
        _inputBuffer = existingPct.toInt().toString();
      } else {
        _isPercentage = false;
        _inputBuffer = currentDiscount.toStringAsFixed(0);
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _calculatedDiscountAmount > 0
              ? 'Discount of ${CurrencyFormatter.formatWithSymbol(_calculatedDiscountAmount)} applied.'
              : 'Discount removed.',
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onRemoveDiscount() {
    FeedbackHelper.vibrate();
    widget.posController.setDiscount(0.0);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Discount cleared from bill.'),
        backgroundColor: AppColors.info,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF7C3AED); // Modern Purple
    final pctPresets = [5, 10, 15, 20, 25, 50];
    final amtPresets = [50, 100, 200, 500, 1000, 2000];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BILL DISCOUNT'),
        backgroundColor: themeColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          if (widget.posController.discountAmount > 0)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('REMOVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _onRemoveDiscount,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Live Calculations & Mode Selector
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Subtotal vs Discount vs New Total Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: themeColor.withOpacity(0.5), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BILL SUBTOTAL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(CurrencyFormatter.formatWithSymbol(_subtotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('DISCOUNT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.warning)),
                              const SizedBox(height: 2),
                              Text('-${CurrencyFormatter.formatWithSymbol(_calculatedDiscountAmount)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.warning)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('NEW TOTAL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success)),
                              const SizedBox(height: 2),
                              Text(CurrencyFormatter.formatWithSymbol(_calculatedGrandTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.success)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Mode Selector Buttons
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
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isPercentage ? themeColor : AppColors.surface,
                                border: Border.all(color: _isPercentage ? themeColor : AppColors.border, width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.percent, size: 18, color: _isPercentage ? Colors.white : AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PERCENTAGE (%)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      color: _isPercentage ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              FeedbackHelper.vibrate();
                              setState(() {
                                _isPercentage = false;
                                _inputBuffer = '';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isPercentage ? themeColor : AppColors.surface,
                                border: Border.all(color: !_isPercentage ? themeColor : AppColors.border, width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.payments_outlined, size: 18, color: !_isPercentage ? Colors.white : AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'FIXED AMOUNT (LKR)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
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

                    const SizedBox(height: 12),

                    // Active Input Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: themeColor, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isPercentage ? 'ENTER PERCENTAGE:' : 'ENTER AMOUNT:',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 0.5),
                          ),
                          Text(
                            _isPercentage
                                ? (_inputBuffer.isEmpty ? '0 %' : '$_inputBuffer %')
                                : (_inputBuffer.isEmpty ? 'LKR 0.00' : 'LKR $_inputBuffer'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _inputBuffer.isNotEmpty ? themeColor : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Quick Presets Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: (_isPercentage ? pctPresets : amtPresets).map((preset) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _applyPreset(preset),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  _isPercentage ? '$preset%' : 'LKR $preset',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
            ),

            // Bottom Section: Hardware-friendly Numeric Keypad
            NumericKeypad(
              buttonHeight: 56.0,
              onDigitPressed: _onDigitPressed,
              onBackspace: _onBackspace,
              onClear: _onClear,
              onSubmit: _onApply,
              submitLabel: 'APPLY DISCOUNT',
              submitIcon: Icons.check_circle_outline,
            ),
          ],
        ),
      ),
    );
  }
}
