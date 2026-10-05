import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../core/widgets/pos_animated_loader.dart';
import '../../authentication/widgets/numeric_keypad.dart';

/// Screen to enter closing cash in hand and perform Shift End / Day End (blind closing)
class EndShiftScreen extends StatefulWidget {
  final ShiftService shiftService;
  final AuthenticationService authService;

  const EndShiftScreen({
    super.key,
    required this.shiftService,
    required this.authService,
  });

  @override
  State<EndShiftScreen> createState() => _EndShiftScreenState();
}

class _EndShiftScreenState extends State<EndShiftScreen> {
  bool _isSubmitting = false;
  String _inputBuffer = '';

  double get _actualCashInHand {
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

  Future<void> _handleConfirmEndShift() async {
    final user = widget.authService.currentUser.value;
    if (user == null) return;

    // Show Dialog asking whether to also perform Day End
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DAY END CONFIRMATION',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.textPrimary),
        ),
        content: const Text(
          'Do you also want to perform DAY END?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF475569),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop('SHIFT_ONLY'),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'NO, ONLY SHIFT END',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC3545),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop('DAY_AND_SHIFT'),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'YES, DAY END',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    final performDayEnd = choice == 'DAY_AND_SHIFT';

    setState(() => _isSubmitting = true);
    FeedbackHelper.playScanFeedback();

    try {
      await widget.shiftService.endShift(
        actualClosingCash: _actualCashInHand,
        user: user,
        performDayEnd: performDayEnd,
      );

      widget.authService.logout();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              performDayEnd
                  ? 'Shift and Business Day ended. Receipts printed.'
                  : 'Shift ended. Z-Report receipt printed.',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error closing shift: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFD97706); // Warm Amber
    final currentShift = widget.shiftService.activeShift.value;
    final currentDay = widget.shiftService.activeDay.value;
    final user = widget.authService.currentUser.value;
    final presets = [0, 1000, 2000, 5000, 10000, 20000, 50000];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SHIFT END'),
        backgroundColor: themeColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to More Menu',
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top Section: Info & Closing cash in hand input
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Simple Info Card
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
                                'Day #${currentDay?.dayNumber ?? 1} • Shift #${currentShift?.shiftNumber ?? 1}',
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

                        // Active Input: Closing Cash in Hand
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
                                  'CLOSING CASH IN HAND:',
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
                  absorbing: _isSubmitting,
                  child: Opacity(
                    opacity: _isSubmitting ? 0.6 : 1.0,
                    child: NumericKeypad(
                      buttonHeight: 56.0,
                      onDigitPressed: _onDigitPressed,
                      onBackspace: _onBackspace,
                      onClear: _onClear,
                      onSubmit: _handleConfirmEndShift,
                      submitLabel: 'END SHIFT',
                      submitIcon: Icons.stop_circle_outlined,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.65),
              child: const Center(
                child: PosAnimatedLoader(
                  title: 'Closing Shift & Printing Report...',
                  dotColor: themeColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
