import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/sale_item_model.dart';
import '../../../shared/widgets/empty_state.dart';
import 'cart_item_row.dart';

/// Billing table widget displaying columns: Description, Qty, Price, Total
class CartTable extends StatelessWidget {
  final List<SaleItem> items;
  final int? selectedIndex;
  final void Function(int index, double qty) onQuantityChanged;
  final void Function(int index, double price) onPriceChanged;
  final void Function(int index, double discount) onDiscountChanged;
  final void Function(int index) onDeleteItem;
  final void Function(int index) onSelectItem;
  final VoidCallback onAddProduct;

  const CartTable({
    super.key,
    required this.items,
    this.selectedIndex,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onDiscountChanged,
    required this.onDeleteItem,
    required this.onSelectItem,
    required this.onAddProduct,
  });

  Widget _buildTableHeader() {
    return Container(
      height: 30,
      color: AppColors.tableHeader,
      child: const Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '#',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Description',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Qty',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Price',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(right: 8, left: 4),
              child: Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          // Fixed Header
          _buildTableHeader(),

          // Scrollable Body or Empty State
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Current Bill is Empty',
                    message: 'Add items to start building the customer invoice',
                    actionLabel: 'Select Product',
                    onAction: onAddProduct,
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return CartItemRow(
                        index: index,
                        item: item,
                        isSelected: selectedIndex == index,
                        isEven: index.isEven,
                        onQuantityChanged: (newQty) => onQuantityChanged(index, newQty),
                        onPriceChanged: (newPrice) => onPriceChanged(index, newPrice),
                        onDiscountChanged: (newDiscount) => onDiscountChanged(index, newDiscount),
                        onDelete: () => onDeleteItem(index),
                        onSelect: () => onSelectItem(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
