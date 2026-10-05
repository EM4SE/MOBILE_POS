import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/customer_model.dart';

/// Reusable table/card row for customer directory
class CustomerListItem extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSelectForPos;

  const CustomerListItem({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    this.onSelectForPos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          // Customer Avatar Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tileCustomers.withAlpha(25),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            ),
            child: const Icon(Icons.person, color: AppColors.tileCustomers, size: 22),
          ),

          const SizedBox(width: AppDimensions.md),

          // Customer Name & Address
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customer.name,
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (customer.address.isNotEmpty) ...[
                  Text(
                    customer.address,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Contact: Phone & Email
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (customer.phone.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 13, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        customer.phone,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                if (customer.email.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.email, size: 13, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        customer.email,
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: AppDimensions.md),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSelectForPos != null) ...[
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                  tooltip: 'Select for Current Bill',
                  onPressed: onSelectForPos,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.accent, size: 20),
                tooltip: 'Edit Customer',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                tooltip: 'Delete Customer',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
