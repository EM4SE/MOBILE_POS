import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/customer_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/customer_controller.dart';

/// Form screen to add or edit customer records
class CustomerFormScreen extends StatefulWidget {
  final CustomerController controller;
  final Customer? customerToEdit;

  const CustomerFormScreen({
    super.key,
    required this.controller,
    this.customerToEdit,
  });

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customerToEdit;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await widget.controller.saveCustomer(
      id: widget.customerToEdit?.id,
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      address: _addressController.text,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customerToEdit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: isEdit ? 'Edit Customer' : 'Add New Customer',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
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
                    // Name
                    AppTextField(
                      controller: _nameController,
                      label: 'Customer / Company Name *',
                      hintText: 'e.g. John Doe / Acme Corp',
                      validator: Validators.requiredField,
                      prefixIcon: Icons.person,
                    ),

                    const SizedBox(height: AppDimensions.md),

                    // Phone and Email
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hintText: 'e.g. 077 123 4567',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: AppTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            hintText: 'e.g. customer@example.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.optionalEmail,
                            prefixIcon: Icons.email,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.md),

                    // Address
                    AppTextField(
                      controller: _addressController,
                      label: 'Billing / Shipping Address',
                      hintText: 'Street, City, Postal Code',
                      maxLines: 2,
                      prefixIcon: Icons.location_on,
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
                          label: isEdit ? 'Update Customer' : 'Save Customer',
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
