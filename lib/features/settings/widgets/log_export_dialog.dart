import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/log_excel_export_service.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../data/repositories/sync_log_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';

/// Shared UI workflow for exporting all login, logout, and POS action logs to an Excel (.xlsx) file.
class LogExportDialog {
  LogExportDialog._();

  static Future<void> runExport(
    BuildContext context,
    SyncLogRepository syncLogRepository, {
    String triggeredFrom = 'Master Management Access',
  }) async {
    FeedbackHelper.vibrate();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Generating Excel workbook (.xlsx) from POS logs...',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await LogExcelExportService.exportLogsToExcel(syncLogRepository);

      try {
        await syncLogRepository.logAction(
          actionType: 'USER_AUTH',
          title: 'Activity Logs Exported to Excel',
          details:
              'Source: $triggeredFrom | File: ${result.fileName} | Path: ${result.displayPath} | Rows: ${result.totalLogs}',
          status: 'SUCCESS',
        );
      } catch (_) {}

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog
      FeedbackHelper.playScanFeedback();

      await _showSuccessDialog(context, result);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppDialog.showSnackBar(
          context,
          'Failed to export logs to Excel: $e',
          isError: true,
        );
      }
    }
  }

  static Future<void> _showSuccessDialog(
    BuildContext context,
    LogExportResult result,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              ),
              child: const Icon(Icons.table_view_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'EXCEL LOG EXPORTED',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('File Name', result.fileName),
            const SizedBox(height: 6),
            _infoRow('Saved Location', result.displayPath),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Exported Records: ${result.totalLogs}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Login / Logout & Auth: ${result.authLogsCount}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  Text(
                    '• POS, Shift & Sync Actions: ${result.posLogsCount}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Share / Open',
            variant: AppButtonVariant.outline,
            icon: Icons.share_outlined,
            width: 135,
            onPressed: () async {
              final opened = await LogExcelExportService.shareOrOpenExport(result);
              if (!opened && ctx.mounted) {
                AppDialog.showSnackBar(
                  ctx,
                  'File saved at ${result.displayPath}',
                );
              }
            },
          ),
          AppButton(
            label: 'Done',
            variant: AppButtonVariant.primary,
            width: 90,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

