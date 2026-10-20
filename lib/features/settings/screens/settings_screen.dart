import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_tile.dart';

import '../../../data/repositories/product_repository.dart';
import '../../../core/services/api_service.dart';

/// Settings screen featuring flat Windows 8-style configuration tiles
class SettingsScreen extends StatefulWidget {
  final SettingsController controller;
  final AuthenticationService authService;
  final ProductRepository? productRepository;

  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authService,
    this.productRepository,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadSettings();
    });
  }

  void _showApiSettingsDialog() {
    final urlCtrl = TextEditingController(text: widget.controller.apiBaseUrl);
    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.dns_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('API & ERP Server URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configure the backend ERP API base URL. Stored procedures, product downloads, and server synchronization connect to this host.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppDimensions.md),
                AppTextField(
                  controller: urlCtrl,
                  label: 'Base API URL (http://ip:port)',
                  hintText: ApiService.defaultBaseUrl,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Default: ',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                    const Expanded(
                      child: Text(
                        ApiService.defaultBaseUrl,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          urlCtrl.text = ApiService.defaultBaseUrl;
                          testResult = null;
                          testSuccess = null;
                        });
                      },
                      child: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (testResult != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (testSuccess == true ? AppColors.success : AppColors.error).withOpacity(0.12),
                      border: Border.all(
                        color: testSuccess == true ? AppColors.success : AppColors.error,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          testSuccess == true ? Icons.check_circle : Icons.error_outline,
                          size: 16,
                          color: testSuccess == true ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            testResult!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: testSuccess == true ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Center(
                  child: isTesting
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Testing connection...', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        )
                      : OutlinedButton.icon(
                          icon: const Icon(Icons.wifi_tethering, size: 16),
                          label: const Text('Test Connection', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final target = urlCtrl.text.trim();
                            if (target.isEmpty) {
                              setDialogState(() {
                                testResult = 'Please enter a valid URL';
                                testSuccess = false;
                              });
                              return;
                            }
                            setDialogState(() {
                              isTesting = true;
                              testResult = null;
                            });
                            final ok = await ApiService().testConnection(testUrl: target);
                            setDialogState(() {
                              isTesting = false;
                              testSuccess = ok;
                              testResult = ok
                                  ? 'Connection successful! Server reached.'
                                  : 'Cannot reach server at this URL.';
                            });
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outline,
              width: 90,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            AppButton(
              label: 'Save & Apply',
              variant: AppButtonVariant.primary,
              width: 120,
              onPressed: () async {
                final targetUrl = urlCtrl.text.trim();
                final toSave = targetUrl.isEmpty ? ApiService.defaultBaseUrl : targetUrl;
                await widget.controller.updateSetting('api_base_url', toSave);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  AppDialog.showSnackBar(
                    context,
                    toSave == ApiService.defaultBaseUrl
                        ? 'Base API URL reset to default'
                        : 'Base API URL updated: $toSave',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStoreSettingsDialog() {
    final nameCtrl = TextEditingController(text: widget.controller.storeName);
    final addrCtrl = TextEditingController(text: widget.controller.storeAddress);
    final phoneCtrl = TextEditingController(text: widget.controller.storePhone);
    final currCtrl = TextEditingController(text: widget.controller.currencySymbol);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Store & Application Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: nameCtrl, label: 'Store Name'),
              const SizedBox(height: AppDimensions.md),
              AppTextField(controller: addrCtrl, label: 'Store Address'),
              const SizedBox(height: AppDimensions.md),
              AppTextField(controller: phoneCtrl, label: 'Store Phone'),
              const SizedBox(height: AppDimensions.md),
              AppTextField(controller: currCtrl, label: 'Currency Symbol (e.g. Rs. / \$)'),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.outline,
            width: 100,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppButton(
            label: 'Save Changes',
            variant: AppButtonVariant.primary,
            width: 130,
            onPressed: () async {
              await widget.controller.updateSettings({
                'store_name': nameCtrl.text,
                'store_address': addrCtrl.text,
                'store_phone': phoneCtrl.text,
                'currency_symbol': currCtrl.text,
              });
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              if (mounted) {
                AppDialog.showSnackBar(context, 'Store settings updated successfully');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPrinterSettingsDialog() {
    String printerType = widget.controller.printerType;
    final ipCtrl = TextEditingController(text: widget.controller.printerIp);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModalState) => AlertDialog(
          title: const Text('Printer Configuration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Printer Model / Protocol:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppDimensions.sm),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: printerType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Thermal 80mm', child: Text('Thermal Receipt 80mm (ESC/POS)')),
                    DropdownMenuItem(value: 'Thermal 58mm', child: Text('Thermal Receipt 58mm (ESC/POS)')),
                    DropdownMenuItem(value: 'Bluetooth POS', child: Text('Bluetooth Mobile Printer')),
                    DropdownMenuItem(value: 'Network LAN', child: Text('Network LAN / Ethernet Printer')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => printerType = val);
                  },
                ),
                const SizedBox(height: AppDimensions.md),
                AppTextField(
                  controller: ipCtrl,
                  label: 'Printer IP / Port Address',
                  hintText: '192.168.1.100:9100',
                ),
                const SizedBox(height: AppDimensions.md),
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Test Print Slip'),
                    onPressed: () {
                      AppDialog.showSnackBar(context, 'Test slip queued to $printerType at ${ipCtrl.text}');
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outline,
              width: 100,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            AppButton(
              label: 'Save Printer',
              variant: AppButtonVariant.primary,
              width: 130,
              onPressed: () async {
                await widget.controller.updateSettings({
                  'printer_type': printerType,
                  'printer_ip': ipCtrl.text,
                });
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  AppDialog.showSnackBar(context, 'Printer settings saved');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceSelectionDialog() {
    String selected = widget.controller.selectedDevice;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.devices, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Select POS Device / SDK', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose your active Android POS terminal model to use its integrated thermal printer SDK:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  // Option 0: DBL Z93 Smart POS (80mm)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected == 'DBL_Z93' ? AppColors.primary : AppColors.border,
                        width: selected == 'DBL_Z93' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: selected == 'DBL_Z93' ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    ),
                    child: RadioListTile<String>(
                      value: 'DBL_Z93',
                      groupValue: selected,
                      dense: true,
                      title: const Text('DBL Z93 Smart POS (80mm)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('DBL / ZCS Z93 Handheld with Inbuilt 80mm Thermal Printer (576 dots)', style: TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selected = val);
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Option 1: DBL Z92 Smart POS
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected == 'DBL_Z92' ? AppColors.primary : AppColors.border,
                        width: selected == 'DBL_Z92' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: selected == 'DBL_Z92' ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    ),
                    child: RadioListTile<String>(
                      value: 'DBL_Z92',
                      groupValue: selected,
                      dense: true,
                      title: const Text('DBL Z92 Smart POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('DBL / ZCS Z92 Handheld with Inbuilt 58mm Thermal Printer SDK', style: TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selected = val);
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Option 2: NEXGO N5
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected == 'NEXGO_N5' ? AppColors.primary : AppColors.border,
                        width: selected == 'NEXGO_N5' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: selected == 'NEXGO_N5' ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    ),
                    child: RadioListTile<String>(
                      value: 'NEXGO_N5',
                      groupValue: selected,
                      dense: true,
                      title: const Text('NEXGO N5 Smart POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('Nexgo Handheld POS with Built-in 58mm Thermal Printer SDK', style: TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selected = val);
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Option 3: W-POS 3
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected == 'WPOS_3' ? AppColors.primary : AppColors.border,
                        width: selected == 'WPOS_3' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: selected == 'WPOS_3' ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    ),
                    child: RadioListTile<String>(
                      value: 'WPOS_3',
                      groupValue: selected,
                      dense: true,
                      title: const Text('W-POS 3 Terminal (Wiseasy)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('Wiseasy / WangPOS W-POS 3 Handheld with Inbuilt 58mm Printer SDK', style: TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selected = val);
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Option 3: Auto Detect
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected == 'AUTO' ? AppColors.primary : AppColors.border,
                        width: selected == 'AUTO' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: selected == 'AUTO' ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    ),
                    child: RadioListTile<String>(
                      value: 'AUTO',
                      groupValue: selected,
                      dense: true,
                      title: const Text('Auto-Detect Hardware', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('Automatically detects active printer service on startup', style: TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selected = val);
                      },
                    ),
                  ),

                  const SizedBox(height: AppDimensions.md),

                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Test Cash Movement Receipt'),
                      onPressed: () async {
                        await PrinterService.setSelectedDevice(selected);
                        final res = await PrinterService.printCashMovementReceipt(
                          isPaidIn: true,
                          amount: 100.0,
                          reason: 'Device Printer Test',
                        );
                        if (mounted) {
                          AppDialog.showSnackBar(
                            context,
                            res.success
                                ? 'Test print sent successfully to $selected'
                                : 'Test print returned: ${res.message ?? "Offline / Paper Out"}',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outline,
              width: 100,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            AppButton(
              label: 'Apply & Save',
              variant: AppButtonVariant.primary,
              width: 130,
              onPressed: () async {
                await widget.controller.updateSetting('selected_device', selected);
                await PrinterService.setSelectedDevice(selected);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  final name = selected == 'DBL_Z93'
                      ? 'DBL Z93 Smart POS (80mm)'
                      : (selected == 'DBL_Z92'
                          ? 'DBL Z92 Smart POS'
                          : (selected == 'WPOS_3'
                              ? 'W-POS 3 (Wiseasy)'
                              : (selected == 'NEXGO_N5' ? 'NEXGO N5' : 'Auto Detect')));
                  AppDialog.showSnackBar(context, 'POS Hardware set to $name');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDatabaseSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Database & Storage Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Engine: SQLite 3 with Local-First Offline Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Database File: pos_database.db'),
              const SizedBox(height: 4),
              const Text('Encryption & Integrity: Active'),
              const SizedBox(height: 4),
              const Text('Automatic local transactions & indexing enabled.'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Server Product Catalog:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Center(
                child: _isSyncing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Syncing from server...', style: TextStyle(fontSize: 13)),
                        ],
                      )
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.sync, size: 18),
                        label: const Text('Sync Products Catalog Now'),
                        onPressed: widget.productRepository == null
                            ? null
                            : () async {
                                setDialogState(() => _isSyncing = true);
                                setState(() => _isSyncing = true);
                                final count = await widget.productRepository!.syncProductsFromApi();
                                setDialogState(() => _isSyncing = false);
                                setState(() => _isSyncing = false);
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                if (mounted) {
                                  AppDialog.showSnackBar(context, 'Successfully synced $count products into SQLite');
                                }
                              },
                      ),
              ),
            ],
          ),
          actions: [
            AppButton(
              label: 'Close',
              variant: AppButtonVariant.primary,
              width: 100,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _showPosPreferencesDialog() {
    final taxCtrl = TextEditingController(text: widget.controller.taxRate);
    final prefixCtrl = TextEditingController(text: widget.controller.invoicePrefix);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('POS Billing Preferences'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: taxCtrl,
                label: 'Default Tax Rate % (e.g. 0.0 or 0.08 for 8%)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                controller: prefixCtrl,
                label: 'Invoice Number Prefix',
                hintText: 'INV-',
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.outline,
            width: 100,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppButton(
            label: 'Save',
            variant: AppButtonVariant.primary,
            width: 100,
            onPressed: () async {
              await widget.controller.updateSettings({
                'tax_rate': taxCtrl.text,
                'invoice_prefix': prefixCtrl.text,
              });
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              if (mounted) {
                AppDialog.showSnackBar(context, 'POS preferences updated');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.point_of_sale, color: AppColors.primary),
            SizedBox(width: 8),
            Text('About ONIMTA POS'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ONIMTA Commercial POS System', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Version 1.0.0 • Production Build', style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 12),
            Text('Architecture:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Clean Architecture & Repository Pattern'),
            Text('• Multi-Device POS Hardware & Thermal Printer SDKs'),
            Text('  (Supports NEXGO N5 and W-POS 3 / Wiseasy terminals)'),
            Text('• SOLID OOP Design & Reusable Components'),
            Text('• Local-First SQLite Database Engine'),
            Text('• Optimized for Handheld and Landscape Terminals'),
            Text('• Android 5.0+ (API 21+) Full Compatibility'),
          ],
        ),
        actions: [
          AppButton(
            label: 'OK',
            variant: AppButtonVariant.primary,
            width: 100,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to log out of this terminal session?',
      confirmLabel: 'Logout',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed && mounted) {
      widget.authService.logout();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final deviceLabel = widget.controller.selectedDeviceDisplayName;
        final currentApiUrl = widget.controller.apiBaseUrl;
        final isCustomApi = widget.controller.isCustomApiBaseUrl;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const AppHeader(
            title: 'System Settings',
            showBackButton: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TERMINAL CONFIGURATION',
                    style: AppTextStyles.displaySmall.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: AppDimensions.md),

                  // API Server Base URL Tile
                  SettingsTile(
                    title: 'API & ERP Server URL',
                    description: 'Active: $currentApiUrl ${isCustomApi ? '(Custom)' : '(Default)'}',
                    icon: Icons.dns_outlined,
                    iconColor: const Color(0xFF0284C7),
                    onTap: _showApiSettingsDialog,
                  ),

                  if (widget.authService.currentUser.value?.isAdmin == true) ...[
                    const SizedBox(height: AppDimensions.sm),
                    SettingsTile(
                      title: 'Cashier Permission Settings',
                      description: 'Manage More menu feature permissions for cashiers',
                      icon: Icons.admin_panel_settings_outlined,
                      iconColor: const Color(0xFFD97706),
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.cashierPermissions),
                    ),
                  ],

                  const SizedBox(height: AppDimensions.sm),

                  // Device Hardware Selection Tile
                  SettingsTile(
                    title: 'POS Hardware & Printer SDK',
                    description: 'Active Device: $deviceLabel (Tap to switch DBL Z92 / NEXGO N5 / W-POS 3)',
                    icon: Icons.point_of_sale,
                    iconColor: const Color(0xFF0D9488),
                    onTap: _showDeviceSelectionDialog,
                  ),

                  const SizedBox(height: AppDimensions.sm),

                  // Store / Branding Settings Tile
                  SettingsTile(
                    title: 'Application Settings',
                    description: 'Store branding, address, currency symbol, contact info',
                    icon: Icons.storefront,
                    iconColor: AppColors.tileProducts,
                    onTap: _showStoreSettingsDialog,
                  ),

                  const SizedBox(height: AppDimensions.sm),

                  SettingsTile(
                    title: 'External Printer Settings',
                    description: 'External ESC/POS 80mm/58mm network LAN and Bluetooth printers',
                    icon: Icons.print,
                    iconColor: AppColors.tileCustomers,
                    onTap: _showPrinterSettingsDialog,
                  ),

                  const SizedBox(height: AppDimensions.sm),

                  SettingsTile(
                    title: 'Database Settings',
                    description: 'Local SQLite offline storage, tables status, and backups',
                    icon: Icons.storage,
                    iconColor: AppColors.tilePos,
                    onTap: _showDatabaseSettingsDialog,
                  ),

                  const SizedBox(height: AppDimensions.sm),

                  SettingsTile(
                    title: 'Activity & ERP Sync Logs',
                    description: 'View POS bill transmissions, ERP API syncs, user actions, and retry failed syncs',
                    icon: Icons.history_edu_outlined,
                    iconColor: const Color(0xFF6366F1),
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.syncLogs),
                  ),

                  const SizedBox(height: AppDimensions.sm),

                  SettingsTile(
                    title: 'POS Settings',
                    description: 'Tax calculation rates, invoice sequence prefix, checkout options',
                    icon: Icons.calculate_outlined,
                    iconColor: AppColors.tileSettings,
                    onTap: _showPosPreferencesDialog,
                  ),

                  const SizedBox(height: AppDimensions.sm),

                  SettingsTile(
                    title: 'About System',
                    description: 'Software version, architecture specs, and hardware compatibility',
                    icon: Icons.info_outline,
                    iconColor: AppColors.primaryDark,
                    onTap: _showAboutDialog,
                  ),

                  const SizedBox(height: AppDimensions.sm),

                  SettingsTile(
                    title: 'Logout Terminal',
                    description: 'End current user session and return to PIN keypad',
                    icon: Icons.power_settings_new,
                    iconColor: AppColors.error,
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
