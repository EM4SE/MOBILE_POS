import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/cashier_permissions_service.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/sync_log_repository.dart';
import '../../authentication/widgets/numeric_keypad.dart';

/// Modal bottom sheet prompting a permitted cashier or Admin PIN via touch keypad
/// to authorize one-time access to a restricted POS feature.
class PinOverrideSheet extends StatefulWidget {
  final String featureId;
  final String featureName;
  final AuthenticationService authService;
  final CashierPermissionsService permissionsService;
  final String? currentCashierName;
  final SyncLogRepository? syncLogRepository;

  const PinOverrideSheet({
    super.key,
    required this.featureId,
    required this.featureName,
    required this.authService,
    required this.permissionsService,
    this.currentCashierName,
    this.syncLogRepository,
  });

  static Future<User?> show(
    BuildContext context, {
    required String featureId,
    required String featureName,
    required AuthenticationService authService,
    required CashierPermissionsService permissionsService,
    String? currentCashierName,
    SyncLogRepository? syncLogRepository,
  }) {
    return showModalBottomSheet<User?>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => PinOverrideSheet(
        featureId: featureId,
        featureName: featureName,
        authService: authService,
        permissionsService: permissionsService,
        currentCashierName: currentCashierName,
        syncLogRepository: syncLogRepository,
      ),
    );
  }

  @override
  State<PinOverrideSheet> createState() => _PinOverrideSheetState();
}

class _PinOverrideSheetState extends State<PinOverrideSheet> {
  String _pin = '';
  String? _errorMessage;
  bool _isVerifying = false;

  void _appendDigit(String digit) {
    if (_isVerifying || _pin.length >= 8) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
  }

  void _backspace() {
    if (_isVerifying || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  void _clearPin() {
    if (_isVerifying) return;
    if (_pin.isNotEmpty || _errorMessage != null) {
      setState(() {
        _pin = '';
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitPin() async {
    if (_isVerifying) return;

    if (_pin.isEmpty) {
      FeedbackHelper.vibrate();
      setState(() {
        _errorMessage = 'Please enter a permitted cashier PIN.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authorizer = await widget.permissionsService.authorizeFeatureWithPin(
        authService: widget.authService,
        pin: _pin,
        featureId: widget.featureId,
        featureName: widget.featureName,
      );

      if (!mounted) return;
      FeedbackHelper.playScanFeedback();
      Navigator.of(context).pop(authorizer);
    } on AppException catch (e) {
      FeedbackHelper.vibrate();
      try {
        await widget.syncLogRepository?.logAction(
          actionType: 'USER_AUTH',
          title: 'Override Denied: ${widget.featureName}',
          details: 'Requested by: ${widget.currentCashierName ?? "Unknown"}',
          status: 'FAILED',
          errorMessage: e.message,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _pin = '';
        _errorMessage = e.message;
      });
    } catch (_) {
      FeedbackHelper.vibrate();
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _pin = '';
        _errorMessage = 'Failed to verify cashier PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = ResponsiveHelper.isLandscape(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    final requester = (widget.currentCashierName != null && widget.currentCashierName!.trim().isNotEmpty)
        ? widget.currentCashierName!.trim()
        : 'Current cashier';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppColors.headerBackground,
              child: Row(
                children: [
                  const Icon(Icons.lock_person_outlined, color: Color(0xFFFBBF24), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'AUTHORIZATION REQUIRED',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          'One-Time Access: ${widget.featureName.toUpperCase()}',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                    tooltip: 'Cancel',
                    onPressed: _isVerifying ? null : () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            // Instruction & PIN Display Section (scrollable if small screen)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                      ),
                      child: Text(
                        '$requester does not have permission for "${widget.featureName}".\nEnter a permitted cashier or Admin PIN to unlock this process once.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Masked PIN Dots Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                        border: Border.all(
                          color: _errorMessage != null ? AppColors.error : AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 32,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Center(
                                  child: _isVerifying
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.5),
                                        )
                                      : _pin.isNotEmpty
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: List.generate(_pin.length, (_) {
                                                return Container(
                                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                                  width: 14,
                                                  height: 14,
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                );
                                              }),
                                            )
                                          : Text(
                                              'ENTER PERMITTED PIN',
                                              style: AppTextStyles.titleMedium.copyWith(
                                                color: AppColors.textLight,
                                                letterSpacing: 1.5,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                ),
                                if (_pin.isNotEmpty && !_isVerifying)
                                  Positioned(
                                    right: 0,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: _clearPin,
                                      child: const Text(
                                        'CLEAR',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Full-width Touch Numeric Keypad
            AbsorbPointer(
              absorbing: _isVerifying,
              child: Opacity(
                opacity: _isVerifying ? 0.6 : 1.0,
                child: NumericKeypad(
                  buttonHeight: isLandscape ? 46.0 : 58.0,
                  onDigitPressed: _appendDigit,
                  onBackspace: _backspace,
                  onClear: _clearPin,
                  onSubmit: _submitPin,
                  submitLabel: 'UNLOCK',
                  submitIcon: Icons.lock_open_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

