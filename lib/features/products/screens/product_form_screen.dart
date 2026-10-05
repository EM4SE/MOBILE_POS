import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/product_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/product_controller.dart';

/// Form screen to add or edit product catalog items
class ProductFormScreen extends StatefulWidget {
  final ProductController controller;
  final Product? productToEdit;

  const ProductFormScreen({
    super.key,
    required this.controller,
    this.productToEdit,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late bool _active;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _codeController = TextEditingController(text: p?.code ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _costController = TextEditingController(text: p != null && p.cost > 0 ? p.cost.toStringAsFixed(2) : '');
    _active = p?.active ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await widget.controller.saveProduct(
      id: widget.productToEdit?.id,
      code: _codeController.text,
      barcode: _barcodeController.text,
      description: _descriptionController.text,
      price: CurrencyFormatter.parseDouble(_priceController.text),
      cost: CurrencyFormatter.parseDouble(_costController.text),
      active: _active,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productToEdit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: isEdit ? 'Edit Product' : 'Add New Product',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 640),
              padding: const EdgeInsets.all(AppDimensions.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Row 1: Code and Barcode
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _codeController,
                            label: 'Product Code *',
                            hintText: 'e.g. P101',
                            validator: Validators.requiredField,
                            prefixIcon: Icons.qr_code,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: AppTextField(
                            controller: _barcodeController,
                            label: 'Barcode (Optional)',
                            hintText: 'e.g. 890103001',
                            prefixIcon: Icons.view_week,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.md),

                    // Row 2: Description
                    AppTextField(
                      controller: _descriptionController,
                      label: 'Product Description *',
                      hintText: 'e.g. Coca Cola 400ml',
                      validator: Validators.requiredField,
                      prefixIcon: Icons.inventory_2,
                    ),

                    const SizedBox(height: AppDimensions.md),

                    // Row 3: Price and Cost
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _priceController,
                            label: 'Selling Price *',
                            hintText: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: Validators.validNumber,
                            prefixIcon: Icons.payments,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: AppTextField(
                            controller: _costController,
                            label: 'Unit Cost (Optional)',
                            hintText: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: Icons.price_check,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.md),

                    // Row 4: Active Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active Status', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Available for POS billing transactions', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          Switch(
                            value: _active,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setState(() => _active = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimensions.xl),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.outline,
                          width: 110,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        AppButton(
                          label: isEdit ? 'Update Product' : 'Save Product',
                          variant: AppButtonVariant.primary,
                          width: 160,
                          isLoading: _isSaving,
                          onPressed: _handleSave,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
