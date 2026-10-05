import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';
import '../../authentication/widgets/numeric_keypad.dart';
import '../controllers/pos_controller.dart';

/// Single Payment Split Entry
class PaymentEntry {
  final String method;
  final double amount;

  const PaymentEntry({
    required this.method,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'method': method,
        'amount': amount,
      };
}

/// Advanced Touch POS Payment Screen with Multi-Payment, Square Method Tiles, Text Box & In-Keypad Complete Flow
class PaymentScreen extends StatefulWidget {
  final PosController controller;

  const PaymentScreen({
    super.key,
    required this.controller,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = AppConstants.defaultPaymentMethod;
  String _tenderInput = '';
  final List<PaymentEntry> _paymentEntries = [];
  bool _isFirstInput = true;
  bool _isProcessing = false;

  double get _totalDue => widget.controller.grandTotal;

  double get _currentEnteredAmount {
    if (_tenderInput.isEmpty) return 0.0;
    return CurrencyFormatter.parseDouble(_tenderInput);
  }

  double get _paidInList => _paymentEntries.fold(0.0, (prev, e) => prev + e.amount);

  double get _remainingDue {
    final rem = _totalDue - _paidInList;
    return rem.clamp(0.0, double.infinity);
  }

  // Combined total if currently entered amount is included
  double get _totalCombinedAmount => _paidInList + _currentEnteredAmount;

  // Has the full bill amount been satisfied?
  bool get _isAmountFullyCovered => _totalCombinedAmount >= _totalDue;

  @override
  void initState() {
    super.initState();
    // Default tender input to full remaining due
    _tenderInput = _totalDue.toStringAsFixed(0);
    _isFirstInput = true;
  }

  void _selectMethod(String methodValue) {
    FeedbackHelper.vibrate();
    setState(() {
      _selectedMethod = methodValue;
      final rem = _remainingDue;
      _tenderInput = rem > 0 ? rem.toStringAsFixed(0) : '0';
      _isFirstInput = true;
    });
  }

  void _appendDigit(String digit) {
    FeedbackHelper.vibrate();
    
    if (_isFirstInput) {
      _isFirstInput = false;
      String nextVal = digit;
      
      // Prevent non-cash methods from exceeding remaining due
      if (_selectedMethod != 'Cash') {
        final parsed = CurrencyFormatter.parseDouble(nextVal);
        if (parsed > _remainingDue) {
          nextVal = _remainingDue.toStringAsFixed(0);
          AppDialog.showSnackBar(
            context,
            '$_selectedMethod payment cannot exceed remaining balance (${CurrencyFormatter.formatWithSymbol(_remainingDue)})',
            isError: true,
          );
        }
      }
      
      setState(() {
        _tenderInput = nextVal;
      });
      return;
    }

    if (_tenderInput.length >= 8) return;
    
    String nextVal = _tenderInput == '0' ? digit : _tenderInput + digit;
    
    // Prevent non-cash methods from exceeding remaining due
    if (_selectedMethod != 'Cash') {
      final parsed = CurrencyFormatter.parseDouble(nextVal);
      if (parsed > _remainingDue) {
        AppDialog.showSnackBar(
          context,
          '$_selectedMethod payment cannot exceed remaining balance (${CurrencyFormatter.formatWithSymbol(_remainingDue)})',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _tenderInput = nextVal;
    });
  }

  void _backspace() {
    FeedbackHelper.vibrate();
    if (_tenderInput.isNotEmpty) {
      setState(() {
        _tenderInput = _tenderInput.substring(0, _tenderInput.length - 1);
        if (_tenderInput.isEmpty) {
          _tenderInput = '0';
          _isFirstInput = true;
        }
      });
    }
  }

  void _clearTender() {
    FeedbackHelper.vibrate();
    setState(() {
      _tenderInput = '0';
      _isFirstInput = true;
    });
  }

  void _setExactAmount() {
    FeedbackHelper.vibrate();
    setState(() {
      _tenderInput = _remainingDue.toStringAsFixed(0);
      _isFirstInput = true;
    });
  }

  void _addCashShortcut(double amount) {
    if (_selectedMethod != 'Cash') return;
    FeedbackHelper.vibrate();
    setState(() {
      final current = _currentEnteredAmount;
      final next = current + amount;
      _tenderInput = next.toStringAsFixed(0);
      _isFirstInput = false;
    });
  }

  void _removePaymentEntry(int index) {
    FeedbackHelper.vibrate();
    setState(() {
      _paymentEntries.removeAt(index);
      final rem = _remainingDue;
      _tenderInput = rem.toStringAsFixed(0);
      _isFirstInput = true;
    });
  }

  // Action when user taps in-keypad action button
  void _handleKeypadAction() {
    if (_isProcessing) return;
    if (_isAmountFullyCovered) {
      // Complete transaction
      _completeTransaction();
    } else {
      // Add current payment line and prepare for next payment method
      _addCurrentPaymentLine();
    }
  }

  void _addCurrentPaymentLine() {
    final amount = _currentEnteredAmount;
    if (amount <= 0) {
      AppDialog.showSnackBar(context, 'Please enter a valid payment amount', isError: true);
      return;
    }

    // Double check non-cash overpayment
    if (_selectedMethod != 'Cash' && amount > _remainingDue) {
      AppDialog.showSnackBar(
        context,
        '$_selectedMethod payment cannot exceed remaining balance (${CurrencyFormatter.formatWithSymbol(_remainingDue)})',
        isError: true,
      );
      return;
    }

    FeedbackHelper.playScanFeedback();

    setState(() {
      _paymentEntries.add(PaymentEntry(method: _selectedMethod, amount: amount));
      final rem = _remainingDue;
      _tenderInput = rem > 0 ? rem.toStringAsFixed(0) : '0';
      _isFirstInput = true;
    });
  }

  Future<void> _completeTransaction() async {
    if (_totalCombinedAmount < _totalDue) {
      AppDialog.showSnackBar(context, 'Total payment is less than amount due', isError: true);
      return;
    }

    // Check if non-cash overpayment happened
    if (_selectedMethod != 'Cash' && _currentEnteredAmount > _remainingDue) {
      AppDialog.showSnackBar(
        context,
        '$_selectedMethod payment cannot exceed remaining balance (${CurrencyFormatter.formatWithSymbol(_remainingDue)})',
        isError: true,
      );
      return;
    }

    setState(() => _isProcessing = true);
    FeedbackHelper.playScanFeedback();

    try {
      final List<Map<String, dynamic>> breakdown = [];
      double totalPaid = 0.0;

      // Collect previously added entries
      for (final e in _paymentEntries) {
        breakdown.add(e.toMap());
        totalPaid += e.amount;
      }

      // Add the final active entered amount if remaining
      if (_currentEnteredAmount > 0) {
        breakdown.add({'method': _selectedMethod, 'amount': _currentEnteredAmount});
        totalPaid += _currentEnteredAmount;
      }

      final change = (totalPaid - _totalDue).clamp(0.0, double.infinity);

      // Save payment method as single name or JSON array
      final paymentMethodString = breakdown.length > 1
          ? jsonEncode(breakdown)
          : (breakdown.isNotEmpty ? breakdown.first['method'] as String : _selectedMethod);

      final sale = await widget.controller.processPayment(
        paidAmount: totalPaid,
        paymentMethod: paymentMethodString,
      );

      setState(() => _isProcessing = false);

      if (!mounted) return;

      // If change is due, show popup before transitioning to receipt
      if (change > 0) {
        await _showChangeDuePopup(context, change);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.billDetail,
          arguments: sale,
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        AppDialog.showSnackBar(context, 'Transaction failed: $e', isError: true);
      }
    }
  }

  Future<void> _showChangeDuePopup(BuildContext context, double changeAmount) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2631),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Row(
          children: [
            Icon(Icons.currency_exchange, color: AppColors.warning, size: 28),
            SizedBox(width: 10),
            Text(
              'CHANGE DUE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.warning,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'RETURN CHANGE TO CUSTOMER',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: AppColors.warning, width: 2),
              ),
              child: Text(
                CurrencyFormatter.formatWithSymbol(changeAmount),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'DONE / VIEW RECEIPT',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSquareButton({
    required String label,
    required IconData icon,
    required String methodValue,
  }) {
    final isSelected = _selectedMethod == methodValue;

    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: isSelected ? AppColors.accent : AppColors.border,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      elevation: isSelected ? 2 : 0,
      child: InkWell(
        onTap: () => _selectMethod(methodValue),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleteReady = _isAmountFullyCovered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'PAYMENT & CHECKOUT',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // 1. FIXED TOP AREA: Amount Due, Method Grid, & Text Box
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // High-Contrast Amount Due Card
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2631),
                      border: Border.all(color: AppColors.accent, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AMOUNT DUE',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white70,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  'Total Payable',
                                  style: TextStyle(fontSize: 10, color: Colors.white38),
                                ),
                              ],
                            ),
                            Text(
                              CurrencyFormatter.formatWithSymbol(_totalDue),
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        if (_paymentEntries.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Paid: ${CurrencyFormatter.formatWithSymbol(_paidInList)}',
                                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              Text(
                                _remainingDue > 0
                                    ? 'Remaining: ${CurrencyFormatter.formatWithSymbol(_remainingDue)}'
                                    : 'FULL AMOUNT COVERED',
                                style: TextStyle(
                                  color: _remainingDue > 0 ? AppColors.warning : AppColors.success,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 5),

                  // 2. Square Payment Method Buttons
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                    childAspectRatio: 1.35,
                    children: [
                      _buildMethodSquareButton(
                        label: 'CASH',
                        icon: Icons.payments_outlined,
                        methodValue: 'Cash',
                      ),
                      _buildMethodSquareButton(
                        label: 'CARD',
                        icon: Icons.credit_card_outlined,
                        methodValue: 'Card',
                      ),
                      _buildMethodSquareButton(
                        label: 'QR / ONLINE',
                        icon: Icons.qr_code_2_outlined,
                        methodValue: 'QR',
                      ),
                      _buildMethodSquareButton(
                        label: 'CREDIT',
                        icon: Icons.account_balance_wallet_outlined,
                        methodValue: 'Credit',
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // 3. Text Box For Typing Amounts With Clear Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(
                        color: isCompleteReady ? AppColors.success : AppColors.accent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_selectedMethod PAY AMOUNT:',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatWithSymbol(_currentEnteredAmount),
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: isCompleteReady ? AppColors.success : AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 35,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error, width: 1.2),
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                onPressed: _clearTender,
                                child: const Text(
                                  'CLEAR',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            SizedBox(
                              height: 35,
                              width: 35,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  side: const BorderSide(color: AppColors.border, width: 1.2),
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: _backspace,
                                child: const Icon(Icons.backspace_outlined, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // 2. SCROLLABLE MIDDLE AREA: Presets & Multi-Payment Breakdown
            // -----------------------------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Presets Quick Bar
                    if (_selectedMethod == 'Cash')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                              onPressed: _setExactAmount,
                              child: const Text('Exact', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                              onPressed: () => _addCashShortcut(500),
                              child: const Text('+500', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                              onPressed: () => _addCashShortcut(1000),
                              child: const Text('+1000', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                              onPressed: () => _addCashShortcut(5000),
                              child: const Text('+5000', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                minimumSize: const Size(0, 28),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                              icon: const Icon(Icons.check, size: 14),
                              onPressed: _setExactAmount,
                              label: Text(
                                'Fill Full Remaining (${CurrencyFormatter.formatWithSymbol(_remainingDue)})',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // Multi-payment added entries list
                    if (_paymentEntries.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PAYMENTS ADDED TO THIS BILL:',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 3),
                            ..._paymentEntries.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          color: AppColors.primary,
                                          child: Text(
                                            item.method,
                                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          CurrencyFormatter.formatWithSymbol(item.amount),
                                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.error, size: 16),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                      onPressed: () => _removePaymentEntry(idx),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // -----------------------------------------------------------------
            // 3. FIXED BOTTOM NUMERIC KEYPAD
            // -----------------------------------------------------------------
            NumericKeypad(
              buttonHeight: 48,
              onDigitPressed: _appendDigit,
              onBackspace: _backspace,
              onClear: _clearTender,
              onSubmit: _handleKeypadAction,
              submitLabel: isCompleteReady ? 'COMPLETE' : 'ADD',
              submitIcon: isCompleteReady ? null : Icons.add_circle_outline,
              submitBackgroundColor: isCompleteReady ? AppColors.success : AppColors.primary,
              submitPressedColor: isCompleteReady ? const Color(0xFF0F5132) : const Color(0xFF003855),
            ),
          ],
        ),
      ),
    );
  }
}
