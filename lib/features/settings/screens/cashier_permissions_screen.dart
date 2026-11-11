import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/cashier_permissions_service.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';

class CashierPermissionsScreen extends StatefulWidget {
  final AuthenticationService authService;
  final UserRepository userRepository;
  final CashierPermissionsService permissionsService;

  const CashierPermissionsScreen({
    super.key,
    required this.authService,
    required this.userRepository,
    required this.permissionsService,
  });

  @override
  State<CashierPermissionsScreen> createState() => _CashierPermissionsScreenState();
}

class _CashierPermissionsScreenState extends State<CashierPermissionsScreen> {
  bool _isLoadingUsers = true;
  bool _isSaving = false;
  List<User> _cashiers = [];
  User? _selectedCashier;
  Map<String, bool> _currentPermissions = {};

  @override
  void initState() {
    super.initState();
    _loadCashiers();
  }

  Future<void> _loadCashiers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final list = await widget.userRepository.getAllUsers();
      if (!mounted) return;
      setState(() {
        _cashiers = list;
        _isLoadingUsers = false;
        // Default select the first non-admin cashier if available, or first user
        if (list.isNotEmpty) {
          _selectedCashier = list.firstWhere(
            (u) => !u.isAdmin,
            orElse: () => list.first,
          );
        }
      });
      if (_selectedCashier != null) {
        await _loadPermissionsForSelected();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingUsers = false);
      AppDialog.showSnackBar(context, 'Error loading cashiers: $e');
    }
  }

  Future<void> _syncCashiers() async {
    FeedbackHelper.vibrate();
    setState(() => _isLoadingUsers = true);
    try {
      final synced = await widget.authService.syncCashiersFromApi();
      if (!mounted) return;
      AppDialog.showSnackBar(
        context,
        'Synced ${synced.length} cashiers from ERP successfully',
      );
      await _loadCashiers();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingUsers = false);
      AppDialog.showSnackBar(context, 'Sync failed: $e');
    }
  }

  Future<void> _loadPermissionsForSelected() async {
    if (_selectedCashier == null) return;
    final perms = await widget.permissionsService.getPermissionsForCashier(_selectedCashier!.username);
    if (!mounted) return;
    setState(() {
      _currentPermissions = perms;
    });
  }

  void _grantAll() {
    FeedbackHelper.vibrate();
    setState(() {
      for (final f in PosFeature.allFeatures) {
        _currentPermissions[f.id] = true;
      }
    });
  }

  void _revokeAll() {
    FeedbackHelper.vibrate();
    setState(() {
      for (final f in PosFeature.allFeatures) {
        _currentPermissions[f.id] = false;
      }
    });
  }

  Future<void> _savePermissions() async {
    if (_selectedCashier == null) return;
    FeedbackHelper.vibrate();
    setState(() => _isSaving = true);

    try {
      await widget.permissionsService.savePermissionsForCashier(
        _selectedCashier!.username,
        _currentPermissions,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppDialog.showSnackBar(
        context,
        'Permissions saved successfully for ${_selectedCashier!.displayName}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppDialog.showSnackBar(context, 'Failed to save permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Cashier Management',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppColors.textOnDark),
            tooltip: 'Sync Cashiers from ERP',
            onPressed: _syncCashiers,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingUsers
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading cashiers...', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            : _cashiers.isEmpty
                ? const Center(
                    child: Text(
                      'No cashiers found. Please sync cashiers from API first.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: [
                      // Header card with Cashier Selector
                      _buildCashierSelectorCard(),

                      // Permissions List or Admin notice
                      Expanded(
                        child: _selectedCashier == null
                            ? const SizedBox.shrink()
                            : _selectedCashier!.isAdmin
                                ? _buildAdminNotice()
                                : _buildPermissionsList(),
                      ),

                      // Bottom Save Button bar (only for non-admin)
                      if (_selectedCashier != null && !_selectedCashier!.isAdmin)
                        _buildBottomActionBar(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildCashierSelectorCard() {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text(
                'SELECT CASHIER TO CONFIGURE',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<User>(
                value: _selectedCashier,
                isExpanded: true,
                items: _cashiers.map((user) {
                  return DropdownMenuItem<User>(
                    value: user,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: user.isAdmin
                              ? const Color(0xFFD97706).withOpacity(0.18)
                              : AppColors.primary.withOpacity(0.18),
                          child: Icon(
                            user.isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
                            size: 16,
                            color: user.isAdmin ? const Color(0xFFD97706) : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            user.displayName.isNotEmpty ? user.displayName : user.username,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: user.isAdmin
                                ? const Color(0xFFD97706).withOpacity(0.15)
                                : AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            user.isAdmin ? 'ADMIN' : 'CASHIER',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: user.isAdmin ? const Color(0xFFD97706) : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (User? newUser) {
                  if (newUser != null && newUser != _selectedCashier) {
                    setState(() {
                      _selectedCashier = newUser;
                    });
                    _loadPermissionsForSelected();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD97706).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, size: 52, color: Color(0xFFD97706)),
              const SizedBox(height: 14),
              const Text(
                'Administrator Cashier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedCashier!.displayName} is an Administrator.\nAdministrators automatically retain full, unrestricted access to all POS features, reports, settings, and functions in the More menu.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionsList() {
    return Column(
      children: [
        // Quick tools bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'More Menu Access Permissions (${_currentPermissions.values.where((v) => v).length}/${PosFeature.allFeatures.length} Enabled)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Grant All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _grantAll,
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppColors.error),
                label: const Text('Revoke All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
                onPressed: _revokeAll,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List of all 14 features
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: PosFeature.allFeatures.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final feature = PosFeature.allFeatures[index];
              final isAllowed = _currentPermissions[feature.id] ?? true;

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isAllowed ? AppColors.border : AppColors.error.withOpacity(0.3),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  secondary: CircleAvatar(
                    radius: 18,
                    backgroundColor: isAllowed
                        ? AppColors.primary.withOpacity(0.12)
                        : Colors.grey.withOpacity(0.18),
                    child: Icon(
                      feature.icon,
                      size: 20,
                      color: isAllowed ? AppColors.primary : Colors.grey,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        feature.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isAllowed ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isAllowed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 11, color: AppColors.error),
                              SizedBox(width: 2),
                              Text(
                                'LOCKED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    feature.description,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  value: isAllowed,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    FeedbackHelper.vibrate();
                    setState(() {
                      _currentPermissions[feature.id] = val;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Configuring: ${_selectedCashier!.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Text(
                  'Changes take effect immediately in More menu.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          AppButton(
            label: _isSaving ? 'Saving...' : 'Save Permissions',
            variant: AppButtonVariant.primary,
            icon: Icons.save_outlined,
            width: 170,
            isLoading: _isSaving,
            onPressed: _savePermissions,
          ),
        ],
      ),
    );
  }
}
