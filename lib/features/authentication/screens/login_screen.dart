import 'package:flutter/material.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/pos_animated_loader.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/sync_log_repository.dart';
import '../../products/controllers/product_controller.dart';
import '../../settings/controllers/settings_controller.dart';
import '../../settings/widgets/log_export_dialog.dart';
import '../controllers/login_controller.dart';
import '../widgets/numeric_keypad.dart';

/// Fast, Touch-friendly POS Login screen with instant background pre-warming and rich loading overlay
class LoginScreen extends StatefulWidget {
  final LoginController controller;
  final ShiftService shiftService;
  final SettingsController? settingsController;
  final SettingsRepository? settingsRepository;
  final ProductRepository? productRepository;
  final ProductController? productController;
  final SyncLogRepository? syncLogRepository;

  const LoginScreen({
    super.key,
    required this.controller,
    required this.shiftService,
    this.settingsController,
    this.settingsRepository,
    this.productRepository,
    this.productController,
    this.syncLogRepository,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isProcessing = false;
  String _statusMessage = 'Signing in...';
  String? _statusSubtitle;

  @override
  void initState() {
    super.initState();
    // Preload active session in background so login to POS is instant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.shiftService.checkActiveSession();
      if (widget.settingsController != null && widget.settingsController!.settings.isEmpty) {
        widget.settingsController!.loadSettings();
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_isProcessing || widget.controller.pin.isEmpty) return;

    FeedbackHelper.vibrate();
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Authenticating PIN...';
      _statusSubtitle = null;
    });

    try {
      final user = await widget.controller.login();
      if (!mounted) return;

      if (user != null) {
        // Check if "Sync items when login into system" is enabled in settings
        bool syncItemsOnLogin = false;
        if (widget.settingsController != null) {
          if (widget.settingsController!.settings.isEmpty) {
            try {
              await widget.settingsController!.loadSettings();
            } catch (e) {
              debugPrint('Settings load notice: $e');
            }
          }
          syncItemsOnLogin = widget.settingsController!.syncItemsOnLogin;
        } else if (widget.settingsRepository != null) {
          final val = await widget.settingsRepository!.getSetting('sync_items_on_login');
          syncItemsOnLogin = val == 'true';
        }

        // If toggle is true, sync items when logging into the system
        if (syncItemsOnLogin && widget.productRepository != null) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Syncing Items Catalog...';
              _statusSubtitle = 'Connecting to ERP server...';
            });
          }

          try {
            final count = await widget.productRepository!.syncProductsFromApi(
              onProgress: (count, status) {
                if (mounted) {
                  setState(() {
                    _statusSubtitle = status;
                  });
                }
              },
            ).timeout(const Duration(seconds: 30));

            debugPrint('Login: Synced $count products from ERP');
            if (widget.productController != null) {
              await widget.productController!.loadProducts(refresh: true);
            }
          } catch (e) {
            debugPrint('Login product sync notice: $e');
            // Gracefully proceed so offline terminal operation is not blocked
          }
        }

        if (!mounted) return;

        setState(() {
          _statusMessage = 'Opening Workspace...';
          _statusSubtitle = null;
        });

        try {
          await widget.shiftService
              .checkActiveSession()
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('Shift check notice: $e');
        }

        if (!mounted) return;

        if (!widget.shiftService.hasActiveDay) {
          // No active Day -> Route to Start Day & Shift
          Navigator.of(context).pushReplacementNamed(AppRoutes.startShift, arguments: true);
        } else if (!widget.shiftService.hasActiveShift) {
          // Active Day exists, but no active Shift -> Route to Start Shift
          Navigator.of(context).pushReplacementNamed(AppRoutes.startShift, arguments: false);
        } else {
          // Both active -> Route directly to POS
          Navigator.of(context).pushReplacementNamed(AppRoutes.pos);
        }
      } else {
        setState(() {
          _isProcessing = false;
          _statusSubtitle = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusSubtitle = null;
        });
      }
    }
  }

  Widget _buildPinDisplay() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pin = widget.controller.pin;
        final hasPin = pin.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            border: Border.all(
              color: widget.controller.errorMessage != null ? AppColors.error : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Masked dots or placeholder
              SizedBox(
                height: 36,
                child: Center(
                  child: hasPin
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pin.length, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        )
                      : Text(
                          'ENTER YOUR PIN',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textLight,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              // Error feedback
              if (widget.controller.errorMessage != null) ...[
                const SizedBox(height: AppDimensions.xs),
                Text(
                  widget.controller.errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: PosAnimatedLoader(
          title: _statusMessage,
          subtitle: _statusSubtitle,
          dotColor: AppColors.primary,
        ),
      ),
    );
  }

  /// Show master management access menu when onimta1+ password is confirmed
  void _showMasterAccessMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (bCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.xs),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    const Text(
                      'Master Management Access',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select management module to open:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  ),
                  tileColor: AppColors.surfaceSecondary,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.settings_outlined, color: Color(0xFF0284C7)),
                  ),
                  title: const Text('POS Terminal Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Store info, Hardware & Printer SDK, Starting Shift ID, Preferences'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(bCtx).pop();
                    Navigator.of(context).pushNamed(AppRoutes.settings).then((_) {
                      if (mounted && widget.settingsController != null) {
                        widget.settingsController!.loadSettings();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  ),
                  tileColor: AppColors.surfaceSecondary,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.manage_accounts_outlined, color: Color(0xFFD97706)),
                  ),
                  title: const Text('Cashier Management & Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Configure cashier accounts and feature access permissions'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(bCtx).pop();
                    Navigator.of(context).pushNamed(AppRoutes.cashierPermissions);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  ),
                  tileColor: AppColors.surfaceSecondary,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_view_outlined, color: AppColors.success),
                  ),
                  title: const Text('Download Activity Logs (Excel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Export all login, logout & POS action logs to .xlsx'),
                  trailing: const Icon(Icons.download_rounded, size: 20, color: AppColors.success),
                  onTap: widget.syncLogRepository == null
                      ? null
                      : () {
                          Navigator.of(bCtx).pop();
                          LogExportDialog.runExport(
                            context,
                            widget.syncLogRepository!,
                            triggeredFrom: 'Master Management Access',
                          );
                        },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Prompt master password to allow accessing Settings Panel & Cashier Management directly without logging in
  void _promptSettingsPassword() {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void submit() {
              final entered = passwordController.text;
              if (entered == 'onimta1+') {
                try {
                  widget.syncLogRepository?.logAction(
                    actionType: 'USER_AUTH',
                    title: 'Master Management Access Unlocked',
                    details: 'Master password verified from Login Screen',
                    status: 'SUCCESS',
                  );
                } catch (_) {}
                Navigator.of(dialogContext).pop();
                _showMasterAccessMenu();
              } else {
                FeedbackHelper.vibrate();
                try {
                  widget.syncLogRepository?.logAction(
                    actionType: 'USER_AUTH',
                    title: 'Master Management Access Failed',
                    details: 'Incorrect master password entered on Login Screen',
                    status: 'FAILED',
                    errorMessage: 'Incorrect password',
                  );
                } catch (_) {}
                setDialogState(() {
                  errorText = 'Incorrect password. Access denied.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.xs),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  const Text(
                    'Master Access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter master password to access POS settings & Cashier Management:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Master Password',
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscure = !obscure;
                          });
                        },
                      ),
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: AppDimensions.sm,
                      ),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                  ),
                  onPressed: submit,
                  child: const Text('UNLOCK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = ResponsiveHelper.isLandscape(context);
    final isLoading = _isProcessing || widget.controller.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: true,
            child: Column(
              children: [
                // Top Section: App Branding & PIN Display
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.lg,
                        vertical: AppDimensions.sm,
                      ),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isLandscape ? 480.0 : 400.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // App Title Header
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppDimensions.sm),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                    ),
                                    child: const Icon(
                                      Icons.point_of_sale_rounded,
                                      size: 40,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: AppDimensions.xs),
                                  Text(
                                    AppConstants.appName,
                                    style: AppTextStyles.displaySmall.copyWith(
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                      fontSize: 24,
                                    ),
                                  ),
                                  Text(
                                    AppConstants.appTagline,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppDimensions.sm),

                            // PIN Display Card
                            _buildPinDisplay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Section: Number Pad fitted to bottom and full screen width
                ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    return AbsorbPointer(
                      absorbing: isLoading,
                      child: Opacity(
                        opacity: isLoading ? 0.6 : 1.0,
                        child: NumericKeypad(
                          onDigitPressed: widget.controller.appendDigit,
                          onBackspace: widget.controller.backspace,
                          onClear: widget.controller.clearPin,
                          onSubmit: _handleLogin,
                          buttonHeight: isLandscape ? 58.0 : 64.0,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Direct Settings Panel Access Icon (Protected by master password)
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                iconSize: 24,
                color: AppColors.textSecondary.withOpacity(0.8),
                tooltip: 'Settings',
                splashRadius: 20,
                onPressed: isLoading ? null : _promptSettingsPassword,
              ),
            ),
          ),

          // High-grade animated loading screen overlay
          if (isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }
}
