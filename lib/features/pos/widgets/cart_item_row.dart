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
  final void Function(double newDiscount) onDiscountChanged;
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
    required this.onDiscountChanged,
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

                  // Full-width numeric keypad
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

  /// Opens Item Discount Keypad Bottom Sheet with % and Amount modes
  void _showItemDiscountKeypad(BuildContext context) {
    bool isPct = true;
    String inputBuf = '';
    final gross = item.quantity * item.unitPrice;

    if (item.discount > 0 && gross > 0) {
      final pct = (item.discount / gross) * 100.0;
      if (pct == pct.roundToDouble()) {
        isPct = true;
        inputBuf = pct.toInt().toString();
      } else {
        isPct = false;
        inputBuf = item.discount.toStringAsFixed(0);
      }
    }

    final pctPresets = [5, 10, 15, 20, 25, 50];
    final amtPresets = [10, 20, 50, 100, 200, 500];

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
            final enteredVal = double.tryParse(inputBuf) ?? 0.0;
            final calculatedDisc = isPct
                ? (gross * (enteredVal.clamp(0.0, 100.0) / 100.0)).clamp(0.0, gross)
                : enteredVal.clamp(0.0, gross);
            final netTotal = (gross - calculatedDisc).clamp(0.0, double.infinity);

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: const Color(0xFF7C3AED),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Item Discount: ${item.productDescription}',
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

                  // Calculations Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: AppColors.background,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BASE TOTAL', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(CurrencyFormatter.formatWithSymbol(gross), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('DISCOUNT', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.warning)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text('-${CurrencyFormatter.formatWithSymbol(calculatedDisc)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.warning)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('NET TOTAL', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.success)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(CurrencyFormatter.formatWithSymbol(netTotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.success)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mode Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: AppColors.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                isPct = true;
                                inputBuf = '';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isPct ? const Color(0xFF7C3AED) : AppColors.surfaceSecondary,
                                border: Border.all(color: isPct ? const Color(0xFF7C3AED) : AppColors.border),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'PERCENTAGE (%)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPct ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                isPct = false;
                                inputBuf = '';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: !isPct ? const Color(0xFF7C3AED) : AppColors.surfaceSecondary,
                                border: Border.all(color: !isPct ? const Color(0xFF7C3AED) : AppColors.border),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'AMOUNT (LKR)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !isPct ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Input Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: AppColors.surfaceSecondary,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            isPct ? 'ENTER PERCENTAGE:' : 'ENTER AMOUNT:',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isPct
                                ? (inputBuf.isEmpty ? '0 %' : '$inputBuf %')
                                : (inputBuf.isEmpty ? 'LKR 0.00' : 'LKR $inputBuf'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Presets
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: AppColors.surface,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: (isPct ? pctPresets : amtPresets).map((preset) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {
                                  inputBuf = preset.toString();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  isPct ? '$preset%' : 'LKR $preset',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Numeric Keypad
                  NumericKeypad(
                    buttonHeight: 52.0,
                    onDigitPressed: (digit) {
                      setSheetState(() {
                        if (inputBuf.length < 6) {
                          inputBuf += digit;
                        }
                      });
                    },
                    onBackspace: () {
                      setSheetState(() {
                        if (inputBuf.isNotEmpty) {
                          inputBuf = inputBuf.substring(0, inputBuf.length - 1);
                        }
                      });
                    },
                    onClear: () {
                      setSheetState(() {
                        inputBuf = '';
                      });
                    },
                    onSubmit: () {
                      onDiscountChanged(calculatedDisc);
                      Navigator.of(ctx).pop();
                    },
                    submitLabel: 'APPLY',
                    submitIcon: Icons.check,
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
              leading: const Icon(Icons.discount_outlined, color: Color(0xFF7C3AED), size: 20),
              title: const Text('Item Discount (% / LKR)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                item.discount > 0 ? 'Current: -${CurrencyFormatter.formatWithSymbol(item.discount)}' : 'Set percentage or amount',
                style: TextStyle(fontSize: 11, color: item.discount > 0 ? AppColors.warning : AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () {
                Navigator.of(ctx).pop();
                _showItemDiscountKeypad(context);
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

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.tableRowSelected
        : (isEven ? AppColors.tableRowEven : AppColors.tableRowOdd);

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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

          // Description Column (Clickable -> Opens Action / Remove / Item Discount Popup)
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: () => _showItemActionDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productDescription,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (item.productCode.isNotEmpty)
                          Flexible(
                            child: Text(
                              'Code: ${item.productCode}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (item.discount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '-${CurrencyFormatter.formatWithSymbol(item.discount)}',
                              style: const TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    border: Border.all(color: AppColors.primary.withAlpha(80)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
          ),

          // Price Column
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  CurrencyFormatter.formatAmount(item.unitPrice),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),

          // Total Column (Shows net total and strikethrough if discounted)
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 6, left: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      CurrencyFormatter.formatAmount(item.lineTotal),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (item.discount > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.formatAmount(item.quantity * item.unitPrice),
                        style: const TextStyle(
                          fontSize: 9.0,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
