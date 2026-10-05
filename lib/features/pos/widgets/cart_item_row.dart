import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/sale_item_model.dart';
import '../../authentication/widgets/numeric_keypad.dart';

/// Compact POS Cart Item Row with small fonts, touchable quantity number pad, and description actions popup
class CartItemRow extends StatelessWidget {
  final int index;
  final SaleItem item;
  final bool isSelected;
  final bool isEven;
  final void Function(double newQty) onQuantityChanged;
  final void Function(double newPrice) onPriceChanged;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const CartItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.isSelected,
    required this.isEven,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onDelete,
    required this.onSelect,
  });

  /// Opens seamless Numeric Keypad bottom sheet to enter quantity
  void _showQuantityKeypad(BuildContext context) {
    String enteredQty = CurrencyFormatter.formatQuantity(item.quantity);
    bool isFirstInput = true; // First keypress overwrites current quantity

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: AppColors.headerBackground,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.productDescription,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: const Icon(Icons.close, color: Colors.white70, size: 20),
                        ),
                      ],
                    ),
                  ),

                  // Display Area
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.primaryLight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ENTER QUANTITY:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          enteredQty.isEmpty ? '0' : enteredQty,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick presets row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: AppColors.surfaceSecondary,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [1, 2, 3, 5, 10].map((preset) {
                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              isFirstInput = false;
                              enteredQty = preset.toString();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '+$preset',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Full-width numeric keypad (same as lock screen)
                  NumericKeypad(
                    buttonHeight: 58.0,
                    onDigitPressed: (digit) {
                      setSheetState(() {
                        if (isFirstInput) {
                          enteredQty = digit;
                          isFirstInput = false;
                        } else if (enteredQty.length < 5) {
                          enteredQty += digit;
                        }
                      });
                    },
                    onBackspace: () {
                      setSheetState(() {
                        isFirstInput = false;
                        if (enteredQty.isNotEmpty) {
                          enteredQty = enteredQty.substring(0, enteredQty.length - 1);
                        }
                      });
                    },
                    onClear: () {
                      setSheetState(() {
                        isFirstInput = false;
                        enteredQty = '';
                      });
                    },
                    onSubmit: () {
                      final qty = double.tryParse(enteredQty) ?? 1.0;
                      if (qty > 0) {
                        onQuantityChanged(qty);
                      }
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Opens item actions popup when description is clicked (Remove Item, Discount, Price Edit)
  void _showItemActionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(14),
        titlePadding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productDescription,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 2,
            ),
            const SizedBox(height: 2),
            Text(
              'Code: ${item.productCode} • ${CurrencyFormatter.formatWithSymbol(item.unitPrice)} each',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Option 1: Change Quantity
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 20),
              title: const Text('Change Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text('Current: ${CurrencyFormatter.formatQuantity(item.quantity)}', style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () {
                Navigator.of(ctx).pop();
                _showQuantityKeypad(context);
              },
            ),

            // Option 2: Apply Item Discount
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.discount_outlined, color: AppColors.warning, size: 20),
              title: const Text('Add Item Discount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Reduce line item price', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () {
                Navigator.of(ctx).pop();
                _showItemDiscountDialog(context);
              },
            ),

            const SizedBox(height: 10),

            // Option 3: Remove Item Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text(
                  'REMOVE ITEM FROM BILL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onDelete();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to enter line item discount
  void _showItemDiscountDialog(BuildContext context) {
    final discCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Discount: ${item.productDescription}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Total: ${CurrencyFormatter.formatWithSymbol(item.lineTotal)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: discCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Discount Amount (Rs.)',
                hintText: '0.00',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              final disc = CurrencyFormatter.parseDouble(discCtrl.text);
              if (disc > 0) {
                final total = item.quantity * item.unitPrice;
                final newTotal = (total - disc).clamp(0.0, double.infinity);
                final newUnitPrice = item.quantity > 0 ? (newTotal / item.quantity) : item.unitPrice;
                onPriceChanged(newUnitPrice);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply Discount', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.tableRowSelected
        : (isEven ? AppColors.tableRowEven : AppColors.tableRowOdd);

    return Container(
      height: 44, // Compact row height for small POS screens
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // Row number (#)
          Container(
            width: 26,
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Description Column (Clickable -> Opens Action / Remove Popup)
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: () => _showItemActionDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.productCode.isNotEmpty) ...[
                      Text(
                        'Code: ${item.productCode}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Quantity Column (Clickable -> Opens Number Pad)
          Expanded(
            flex: 2,
            child: Center(
              child: InkWell(
                onTap: () => _showQuantityKeypad(context),
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    border: Border.all(color: AppColors.primary.withAlpha(80)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    CurrencyFormatter.formatQuantity(item.quantity),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Price Column
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                CurrencyFormatter.formatAmount(item.unitPrice),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),

          // Total Column
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: Text(
                CurrencyFormatter.formatAmount(item.lineTotal),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
