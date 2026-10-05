import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../data/models/customer_model.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../controllers/pos_controller.dart';
import '../widgets/camera_barcode_scanner_sheet.dart';
import '../widgets/cart_table.dart';
import '../widgets/pos_summary.dart';

/// Main POS Terminal Billing Screen (Primary 1280x720 Landscape View)
class PosScreen extends StatefulWidget {
  final PosController controller;
  final AuthenticationService authService;

  const PosScreen({
    super.key,
    required this.controller,
    required this.authService,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _barcodeInputController = TextEditingController();

  @override
  void dispose() {
    _barcodeInputController.dispose();
    super.dispose();
  }

  void _openMoreMenu() {
    Navigator.of(context).pushNamed(AppRoutes.more);
  }

  Future<void> _handleBarcodeSubmit(String code) async {
    if (code.trim().isEmpty) return;
    final added = await widget.controller.quickAddByCodeOrBarcode(code);
    if (!mounted) return;
    if (added) {
      _barcodeInputController.clear();
    } else {
      AppDialog.showSnackBar(context, 'No product matches: $code', isError: true);
    }
  }

  void _openProductSelector() {
    Navigator.of(context).pushNamed(
      AppRoutes.products,
      arguments: {'isSelectionMode': true},
    );
  }

  void _openCustomerSelector() {
    Navigator.of(context).pushNamed(
      AppRoutes.customers,
      arguments: {'isSelectionMode': true},
    ).then((selected) {
      if (selected is Customer && mounted) {
        widget.controller.selectCustomer(selected);
        AppDialog.showSnackBar(context, 'Customer set to: ${selected.name}');
      }
    });
  }

  void _openCameraBarcodeScanner() {
    CameraBarcodeScannerSheet.show(
      context,
      onBarcodeScanned: (barcode) {
        _handleBarcodeSubmit(barcode);
      },
    );
  }

  void _handleCheckout() {
    Navigator.of(context).pushNamed(AppRoutes.payment);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Quick Barcode / Item Bar
            Container(
              color: AppColors.surfaceSecondary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sm,
                vertical: 6,
              ),
              child: Row(
                children: [
                  // 1. Barcode / Code search input (No inner scanner icon, compact)
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _barcodeInputController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter Code / Barcode (Press Enter)...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onSubmitted: _handleBarcodeSubmit,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 2. Dedicated Camera Scanner Button with Scanner Icon
                  SizedBox(
                    height: 40,
                    width: 44,
                    child: Tooltip(
                      message: 'Scan Barcode with Camera',
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.headerBackground,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                          ),
                          elevation: 1,
                        ),
                        onPressed: _openCameraBarcodeScanner,
                        child: const Icon(Icons.qr_code_scanner, size: 22),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 3. PRODUCTS Button
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tileProducts,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                        ),
                        elevation: 1,
                      ),
                      onPressed: _openProductSelector,
                      icon: const Icon(Icons.grid_view, size: 16),
                      label: const Text(
                        'PRODUCTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Billing Table Component (Description | Qty | Price | Total)
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  return CartTable(
                    items: widget.controller.cartItems,
                    selectedIndex: widget.controller.editingIndex,
                    onQuantityChanged: (index, newQty) => widget.controller.updateQuantity(index, newQty),
                    onPriceChanged: (index, newPrice) => widget.controller.updatePrice(index, newPrice),
                    onDiscountChanged: (index, newDiscount) => widget.controller.updateItemDiscount(index, newDiscount),
                    onDeleteItem: (index) => widget.controller.removeItem(index),
                    onSelectItem: (index) => widget.controller.setEditingIndex(index),
                    onAddProduct: _openProductSelector,
                  );
                },
              ),
            ),

            // Two-Tier POS Bottom Bar (Details/Total Bar + MORE, CUSTOMER, PAY NOW)
            PosSummary(
              controller: widget.controller,
              onMorePressed: _openMoreMenu,
              onSelectCustomer: _openCustomerSelector,
              onCheckout: _handleCheckout,
            ),
          ],
        ),
      ),
    );
  }
}
