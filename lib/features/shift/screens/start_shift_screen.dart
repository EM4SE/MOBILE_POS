import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../authentication/widgets/numeric_keypad.dart';

/// Screen displayed after Login if a Day or Shift is not active
class StartShiftScreen extends StatefulWidget {
  final ShiftService shiftService;
  final AuthenticationService authService;
  final bool isDayStart;

  const StartShiftScreen({
    super.key,
    required this.shiftService,
    required this.authService,
    required this.isDayStart,
  });

  @override
  State<StartShiftScreen> createState() => _StartShiftScreenState();
}

class _StartShiftScreenState extends State<StartShiftScreen> {
  String _inputBuffer = '';
  bool _isLoading = false;

  double get _enteredOpeningBalance {
    if (_inputBuffer.isEmpty) return 0.0;
    return double.tryParse(_inputBuffer) ?? 0.0;
  }

  void _onDigitPressed(String digit) {
    FeedbackHelper.vibrate();
    if (_inputBuffer.length >= 8) return;
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

  void _applyPreset(int amount) {
    FeedbackHelper.vibrate();
    setState(() {
      _inputBuffer = amount.toString();
    });
  }

  Future<void> _handleSubmit() async {
    final user = widget.authService.currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged in user session found.'), backgroundColor: AppColors.error),
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    setState(() => _isLoading = true);
    FeedbackHelper.playScanFeedback();

    try {
      if (widget.isDayStart) {
        await widget.shiftService.startDayAndShift(
          openingBalance: _enteredOpeningBalance,
          user: user,
        );
      } else {
        await widget.shiftService.startShift(
          openingBalance: _enteredOpeningBalance,
          user: user,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isDayStart
                  ? 'Business Day & Shift 1 started with Float ${CurrencyFormatter.formatWithSymbol(_enteredOpeningBalance)}'
                  : 'Shift started with Float ${CurrencyFormatter.formatWithSymbol(_enteredOpeningBalance)}',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushReplacementNamed(AppRoutes.pos);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting shift: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF0F766E); // Deep Teal
    final presets = [0, 1000, 2000, 5000, 10000, 20000];
    final user = widget.authService.currentUser.value;

    final titleText = widget.isDayStart ? 'START BUSINESS DAY & SHIFT' : 'START CASHIER SHIFT';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isDayStart ? 'START DAY & SHIFT' : 'START SHIFT'),
        backgroundColor: themeColor,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () {
              widget.authService.logout();
              Navigator.of(context).pushReplacementNamed(AppRoutes.login);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Info & Opening Balance Display
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Simple Header Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: themeColor.withOpacity(0.4), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            titleText,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          Text(
                            'User: ${user?.displayName ?? "Admin"}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Active Input Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: themeColor, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'OPENING FLOAT:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _inputBuffer.isEmpty ? 'LKR 0.00' : 'LKR $_inputBuffer',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: themeColor,
                              ),
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
                        children: presets.map((preset) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => _applyPreset(preset),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  preset == 0 ? 'LKR 0' : 'LKR $preset',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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

            // Bottom Section: Hardware-friendly Keypad
            AbsorbPointer(
              absorbing: _isLoading,
              child: Opacity(
                opacity: _isLoading ? 0.6 : 1.0,
                child: NumericKeypad(
                  buttonHeight: 56.0,
                  onDigitPressed: _onDigitPressed,
                  onBackspace: _onBackspace,
                  onClear: _onClear,
                  onSubmit: _handleSubmit,
                  submitLabel: 'START',
                  submitIcon: Icons.play_arrow_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
