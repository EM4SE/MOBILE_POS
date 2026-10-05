import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';

/// Reusable table / card row for product management lists
class ProductListItem extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback? onSelectForPos;

  const ProductListItem({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
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
          // Active Indicator Badge
          InkWell(
            onTap: onToggleActive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: product.active ? AppColors.success.withAlpha(25) : AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                border: Border.all(
                  color: product.active ? AppColors.success : AppColors.error,
                ),
              ),
              child: Text(
                product.active ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(
                  color: product.active ? AppColors.success : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: AppDimensions.md),

          // Code
          SizedBox(
            width: 90,
            child: Text(
              product.code,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Description & Barcode
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.description,
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.barcode.isNotEmpty) ...[
                  Text(
                    'Barcode: ${product.barcode}',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // Price & Cost
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.formatWithSymbol(product.price),
                  style: AppTextStyles.currencyMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (product.cost > 0) ...[
                  Text(
                    'Cost: ${CurrencyFormatter.formatAmount(product.cost)}',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
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
                  icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                  tooltip: 'Add to Bill',
                  onPressed: onSelectForPos,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.accent, size: 20),
                tooltip: 'Edit Product',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                tooltip: 'Delete Product',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
