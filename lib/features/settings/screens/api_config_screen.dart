import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/app_text_field.dart';

class ApiConfigScreen extends StatefulWidget {
  final AuthenticationService authService;
  final SettingsRepository settingsRepository;
  final bool isInitialSetup;
  final String? initialErrorMessage;

  const ApiConfigScreen({
    super.key,
    required this.authService,
    required this.settingsRepository,
    this.isInitialSetup = false,
    this.initialErrorMessage,
  });

  @override
  State<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends State<ApiConfigScreen> {
  late final TextEditingController _urlController;
  bool _isTesting = false;
  bool _isSaving = false;
  bool? _testSuccess;
  String? _testMessage;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService.baseUrl);
    if (widget.initialErrorMessage != null) {
      _syncError = widget.initialErrorMessage;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleTestConnection() async {
    final targetUrl = _urlController.text.trim();
    if (targetUrl.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage = 'Please enter a valid server URL.';
      });
      return;
    }

    FeedbackHelper.vibrate();
    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testMessage = null;
      _syncError = null;
    });

    try {
      final ok = await ApiService().testConnection(testUrl: targetUrl);
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = ok;
        _testMessage = ok
            ? 'Connection successful! Server reached.'
            : 'Cannot reach server at this URL. Please verify IP & port.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testMessage = 'Connection error: $e';
      });
    }
  }

  Future<void> _handleSaveAndConnect() async {
    final targetUrl = _urlController.text.trim();
    final toSave = targetUrl.isEmpty ? ApiService.defaultBaseUrl : targetUrl;

    FeedbackHelper.vibrate();
    setState(() {
      _isSaving = true;
      _syncError = null;
    });

    try {
      // 1. Update in-memory API base URL
      ApiService.setBaseUrl(toSave);

      // 2. Persist in local SQLite settings table
      await widget.settingsRepository.updateSetting('api_base_url', toSave);

      // 3. Call iid 8 to sync cashiers
      final cashiers = await widget.authService.syncCashiersFromApi(baseUrl: toSave);

      if (!mounted) return;
      setState(() => _isSaving = false);

      AppDialog.showSnackBar(
        context,
        'Connected successfully! Synced ${cashiers.length} cashiers.',
      );

      if (widget.isInitialSetup) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _syncError = 'Failed to sync cashiers from $toSave:\n$e';
      });
    }
  }

  void _handleContinueOffline() {
    FeedbackHelper.vibrate();
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'ERP Server Configuration',
        showBackButton: !widget.isInitialSetup,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice banner if initial setup due to failure
              if (widget.isInitialSetup) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    border: Border.all(color: const Color(0xFFF87171), width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SERVER CONNECTION REQUIRED',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Could not load cashiers from ERP (Iid 8). Please configure the server URL below.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // URL Input Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ERP SERVER BASE URL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _urlController.text = ApiService.defaultBaseUrl;
                              _testSuccess = null;
                              _testMessage = null;
                              _syncError = null;
                            });
                          },
                          child: const Text('Reset Default', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _urlController,
                      label: 'Base API URL',
                      hintText: 'http://194.233.76.58:9696',
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Expected endpoint: <Base URL>/api/Master/CommonExecute',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Test Result Display
              if (_testMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: (_testSuccess == true ? AppColors.success : AppColors.error).withOpacity(0.12),
                    border: Border.all(
                      color: _testSuccess == true ? AppColors.success : AppColors.error,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true ? Icons.check_circle : Icons.error_outline,
                        color: _testSuccess == true ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _testSuccess == true ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Sync Error Display
              if (_syncError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    border: Border.all(color: AppColors.error),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _syncError!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Action Buttons
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                icon: _isTesting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: Text(
                  _isTesting ? 'Testing Server Connection...' : 'Test Server Connection',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _isTesting || _isSaving ? null : _handleTestConnection,
              ),

              const SizedBox(height: 10),

              AppButton(
                label: _isSaving ? 'Connecting & Syncing Cashiers...' : 'Save & Sync Cashiers',
                variant: AppButtonVariant.primary,
                isLoading: _isSaving,
                onPressed: _isTesting || _isSaving ? null : _handleSaveAndConnect,
              ),

              if (widget.isInitialSetup) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  icon: const Icon(Icons.offline_bolt_outlined, size: 18),
                  label: const Text(
                    'Work Offline With Cached Cashiers',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: _isSaving ? null : _handleContinueOffline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
