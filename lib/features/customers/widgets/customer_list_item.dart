import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/customer_model.dart';

/// Clean touchable row for Customer selection in POS
class CustomerListItem extends StatelessWidget {
  final Customer customer;
  final bool isSelected;
  final VoidCallback onTap;

  const CustomerListItem({
    super.key,
    required this.customer,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFE0F2FE) : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primaryLight,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: const BorderSide(color: AppColors.border, width: 0.8),
              left: isSelected
                  ? const BorderSide(color: Color(0xFF0284C7), width: 4.0)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Customer Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF0891B2).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                ),
                child: Icon(
                  Icons.person,
                  color: isSelected ? Colors.white : const Color(0xFF0891B2),
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              // Customer Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isSelected ? const Color(0xFF0369A1) : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (customer.phone.isNotEmpty) ...[
                          const Icon(Icons.phone, size: 11, color: AppColors.textLight),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              customer.phone,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (customer.address.isNotEmpty || customer.email.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('•', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                            ),
                        ],
                        if (customer.address.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              customer.address,
                              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else if (customer.email.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              customer.email,
                              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Selection checkmark
              Icon(
                isSelected ? Icons.check_circle : Icons.chevron_right,
                size: 20,
                color: isSelected ? const Color(0xFF0284C7) : AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
