import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../data/models/sync_activity_log_model.dart';
import '../../../data/repositories/bill_sync_repository.dart';
import '../../../data/repositories/sync_log_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';

class SyncLogsScreen extends StatefulWidget {
  final SyncLogRepository syncLogRepository;
  final BillSyncRepository? billSyncRepository;

  const SyncLogsScreen({
    super.key,
    required this.syncLogRepository,
    this.billSyncRepository,
  });

  @override
  State<SyncLogsScreen> createState() => _SyncLogsScreenState();
}

class _SyncLogsScreenState extends State<SyncLogsScreen> {
  List<SyncActivityLog> _logs = [];
  Map<String, int> _stats = {
    'total': 0,
    'success': 0,
    'failed': 0,
    'pending': 0,
  };

  bool _isLoading = true;
  bool _isSyncingPending = false;
  String _selectedActionFilter = 'ALL';
  String _selectedStatusFilter = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _actionFilters = [
    {'label': 'All Actions', 'value': 'ALL'},
    {'label': 'POS Bills', 'value': 'BILL_SYNC'},
    {'label': 'Product Sync', 'value': 'PRODUCT_SYNC'},
    {'label': 'User & Shift', 'value': 'USER_AUTH'},
  ];

  final List<Map<String, String>> _statusFilters = [
    {'label': 'All Statuses', 'value': 'ALL'},
    {'label': 'Success', 'value': 'SUCCESS'},
    {'label': 'Failed', 'value': 'FAILED'},
    {'label': 'Pending', 'value': 'PENDING'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await widget.syncLogRepository.getLogs(
        actionType: _selectedActionFilter,
        status: _selectedStatusFilter,
        limit: 200,
      );
      final stats = await widget.syncLogRepository.getLogStats();

      if (mounted) {
        setState(() {
          _logs = logs;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialog.showSnackBar(context, 'Failed to load logs: $e', isError: true);
      }
    }
  }

  Future<void> _syncPendingBills() async {
    if (widget.billSyncRepository == null) {
      AppDialog.showSnackBar(context, 'Bill sync repository not available', isError: true);
      return;
    }

    setState(() => _isSyncingPending = true);
    try {
      final result = await widget.billSyncRepository!.syncPendingSales();
      final total = result['total'] ?? 0;
      final synced = result['synced'] ?? 0;
      final failed = result['failed'] ?? 0;

      if (mounted) {
        if (total == 0) {
          AppDialog.showSnackBar(context, 'All bills are already synced to ERP server!');
        } else {
          AppDialog.showSnackBar(
            context,
            'Sync Complete: $synced synced successfully, $failed failed out of $total bills.',
            isError: failed > 0,
          );
        }
        await _loadLogs();
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showSnackBar(context, 'Sync error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingPending = false);
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Clear Activity Logs',
      message: 'Are you sure you want to delete all activity and sync log records? This cannot be undone.',
      confirmLabel: 'Clear All',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed == true && mounted) {
      await widget.syncLogRepository.clearAllLogs();
      if (mounted) {
        AppDialog.showSnackBar(context, 'All sync and activity logs cleared');
        _loadLogs();
      }
    }
  }

  void _showLogDetail(SyncActivityLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: log.statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(log.icon, color: log.statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          log.createdAt.replaceFirst('T', ' ').split('.').first,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: log.statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: log.statusColor, width: 1),
                    ),
                    child: Text(
                      log.status,
                      style: TextStyle(
                        color: log.statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),

            // Content Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Action Type', log.actionType),
                          const SizedBox(height: 6),
                          _buildDetailRow('Timestamp', log.createdAt),
                          if (log.details != null && log.details!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow('Summary', log.details!),
                          ],
                        ],
                      ),
                    ),

                    if (log.errorMessage != null && log.errorMessage!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'ERROR MESSAGE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.error,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withOpacity(0.4)),
                        ),
                        child: SelectableText(
                          log.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],

                    if (log.responseBody != null && log.responseBody!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SERVER RESPONSE / PAYLOAD',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Copy', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: log.responseBody!));
                              AppDialog.showSnackBar(context, 'Copied response to clipboard');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          log.responseBody!,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  if (log.actionType == 'BILL_SYNC' && (log.isFailed || log.isPending)) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        icon: const Icon(Icons.sync, size: 18, color: Colors.white),
                        label: const Text('Retry Pending Bills', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _syncPendingBills();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  List<SyncActivityLog> get _filteredLogs {
    if (_searchQuery.trim().isEmpty) return _logs;
    final q = _searchQuery.trim().toLowerCase();
    return _logs.where((l) {
      final matchTitle = l.title.toLowerCase().contains(q);
      final matchDetails = l.details?.toLowerCase().contains(q) ?? false;
      final matchResponse = l.responseBody?.toLowerCase().contains(q) ?? false;
      final matchError = l.errorMessage?.toLowerCase().contains(q) ?? false;
      return matchTitle || matchDetails || matchResponse || matchError;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Activity & ERP Sync Logs',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Logs',
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Logs',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Dashboard Summary Cards
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard('Total Logs', '${_stats['total'] ?? 0}', Icons.history, AppColors.primary),
                      const SizedBox(width: 8),
                      _buildStatCard('Synced ERP', '${_stats['success'] ?? 0}', Icons.check_circle_outline, AppColors.success),
                      const SizedBox(width: 8),
                      _buildStatCard('Failed', '${_stats['failed'] ?? 0}', Icons.error_outline, AppColors.error),
                      const SizedBox(width: 8),
                      _buildStatCard('Pending', '${_stats['pending'] ?? 0}', Icons.hourglass_top, AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Sync Pending Now Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSyncingPending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 20),
                      label: Text(
                        _isSyncingPending ? 'Syncing Pending Bills to ERP...' : 'SYNC ALL PENDING BILLS TO ERP NOW',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: _isSyncingPending ? null : _syncPendingBills,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Search Bar & Filter Chips
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Colors.white,
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by invoice number, product or log text...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  // Action Filter Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _actionFilters.map((f) {
                        final isSelected = _selectedActionFilter == f['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f['label']!),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedActionFilter = f['value']!);
                                _loadLogs();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusFilters.map((s) {
                        final isSelected = _selectedStatusFilter == s['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s['label']!),
                            selected: isSelected,
                            selectedColor: s['value'] == 'SUCCESS'
                                ? AppColors.success
                                : (s['value'] == 'FAILED'
                                    ? AppColors.error
                                    : (s['value'] == 'PENDING'
                                        ? AppColors.warning
                                        : AppColors.primaryDark)),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade800,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedStatusFilter = s['value']!);
                                _loadLogs();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Logs List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty ? 'No logs match "$_searchQuery"' : 'No activity logs found',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Actions such as ERP bill syncs and downloads will appear here.',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppDimensions.md),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = filtered[index];
                            return _buildLogCard(log);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(SyncActivityLog log) {
    final formattedTime = log.createdAt.replaceFirst('T', ' ').split('.').first;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showLogDetail(log),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: log.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(log.icon, color: log.statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            log.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: log.statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            log.status,
                            style: TextStyle(
                              color: log.statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (log.details != null && log.details!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.details!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
