import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

/// Represents an audit/sync log entry for user actions and database ERP syncs
class SyncActivityLog {
  final int? id;
  final String actionType; // 'BILL_SYNC', 'PRODUCT_SYNC', 'USER_AUTH', 'SHIFT_EVENT'
  final String title;
  final String? details;
  final String status; // 'SUCCESS', 'FAILED', 'PENDING'
  final String? responseBody;
  final String? errorMessage;
  final String createdAt;

  const SyncActivityLog({
    this.id,
    required this.actionType,
    required this.title,
    this.details,
    required this.status,
    this.responseBody,
    this.errorMessage,
    required this.createdAt,
  });

  bool get isSuccess => status.toUpperCase() == 'SUCCESS';
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get isPending => status.toUpperCase() == 'PENDING';

  Color get statusColor {
    if (isSuccess) return AppColors.success;
    if (isFailed) return AppColors.error;
    return AppColors.warning;
  }

  IconData get icon {
    switch (actionType.toUpperCase()) {
      case 'BILL_SYNC':
        return Icons.receipt_long_outlined;
      case 'PRODUCT_SYNC':
        return Icons.cloud_download_outlined;
      case 'USER_AUTH':
        return Icons.person_outline;
      case 'SHIFT_EVENT':
        return Icons.schedule_outlined;
      case 'CASH_DRAWER':
        return Icons.point_of_sale_outlined;
      default:
        return Icons.sync;
    }
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'action_type': actionType,
      'title': title,
      'details': details,
      'status': status,
      'response_body': responseBody,
      'error_message': errorMessage,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory SyncActivityLog.fromMap(Map<String, dynamic> map) {
    return SyncActivityLog(
      id: map['id'] as int?,
      actionType: (map['action_type'] as String?) ?? 'GENERAL',
      title: (map['title'] as String?) ?? 'Activity Log',
      details: map['details'] as String?,
      status: (map['status'] as String?) ?? 'SUCCESS',
      responseBody: map['response_body'] as String?,
      errorMessage: map['error_message'] as String?,
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}
