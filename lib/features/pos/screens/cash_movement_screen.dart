import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../authentication/widgets/numeric_keypad.dart';

/// Full-screen Cash In / Cash Out Screen with Hardware-friendly Numeric Keypad
class CashMovementScreen extends StatefulWidget {
  final bool isPaidIn;

  const CashMovementScreen({
    super.key,
    required this.isPaidIn,
  });

  @override
  State<CashMovementScreen> createState() => _CashMovementScreenState();
}

class _CashMovementScreenState extends State<CashMovementScreen> {
  String _amountBuffer = '';
  String _selectedReason = '';

  List<String> get _reasonSuggestions => widget.isPaidIn
      ? ['Opening Float', 'Add Cash', 'Change Fund', 'Owner Capital', 'Cash Inflow']
      : ['Vendor Payment', 'Petty Cash', 'Staff Expense', 'Transport / Fuel', 'Shop Supplies', 'Utilities'];

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasonSuggestions.first;
  }

  double get _currentAmount {
    if (_amountBuffer.isEmpty) return 0.0;
    return double.tryParse(_amountBuffer) ?? 0.0;
  }

  void _onDigitPressed(String digit) {
    FeedbackHelper.vibrate();
    if (_amountBuffer.length >= 8) return; // Prevent excessive amount overflow

    setState(() {
      if (_amountBuffer == '0') {
        _amountBuffer = digit;
      } else {
        _amountBuffer += digit;
      }
    });
  }

  void _onBackspace() {
    FeedbackHelper.vibrate();
    if (_amountBuffer.isNotEmpty) {
      setState(() {
        _amountBuffer = _amountBuffer.substring(0, _amountBuffer.length - 1);
      });
    }
  }

  void _onClear() {
    FeedbackHelper.vibrate();
    setState(() {
      _amountBuffer = '';
    });
  }

  Future<void> _onSubmit() async {
    final amount = _currentAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0.00'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    FeedbackHelper.playScanFeedback();

    // Auto-print Paid In / Paid Out receipt
    PrinterService.printCashMovementReceipt(
      isPaidIn: widget.isPaidIn,
      amount: amount,
      reason: _selectedReason,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.isPaidIn ? 'PAID IN' : 'PAID OUT'} of ${CurrencyFormatter.formatWithSymbol(amount)} ($_selectedReason) recorded & printed.',
        ),
        backgroundColor: widget.isPaidIn ? AppColors.success : AppColors.warning,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isPaidIn ? const Color(0xFF198754) : const Color(0xFFD97706);
    final titleText = widget.isPaidIn ? 'PAID IN (CASH ENTRY)' : 'PAID OUTS (CASH EXPENSE)';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: themeColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Amount Display & Reason Selector
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount Display Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: themeColor.withOpacity(0.6), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.isPaidIn ? 'ENTER CASH IN AMOUNT' : 'ENTER CASH OUT AMOUNT',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.formatWithSymbol(_currentAmount),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: _currentAmount > 0 ? themeColor : Colors.white54,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Reason / Remarks Label
                    const Text(
                      'SELECT REASON / REMARK:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Reason Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _reasonSuggestions.map((reason) {
                        final isSelected = _selectedReason == reason;
                        return InkWell(
                          onTap: () {
                            FeedbackHelper.vibrate();
                            setState(() {
                              _selectedReason = reason;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? themeColor : AppColors.surface,
                              border: Border.all(
                                color: isSelected ? themeColor : AppColors.border,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section: Hardware-friendly Numeric Keypad
            NumericKeypad(
              buttonHeight: 60.0,
              onDigitPressed: _onDigitPressed,
              onBackspace: _onBackspace,
              onClear: _onClear,
              onSubmit: _onSubmit,
              submitLabel: 'SAVE',
              submitIcon: Icons.check,
            ),
          ],
        ),
      ),
    );
  }
}
