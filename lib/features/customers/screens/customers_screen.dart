import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/customer_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_list_item.dart';

/// Customers Screen managing customer directory, search queries, and selection for POS
class CustomersScreen extends StatefulWidget {
  final CustomerController controller;
  final bool isSelectionMode;
  final void Function(Customer customer)? onCustomerSelected;

  const CustomersScreen({
    super.key,
    required this.controller,
    this.isSelectionMode = false,
    this.onCustomerSelected,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(Customer customer) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete Customer',
      message: 'Are you sure you want to permanently delete "${customer.name}"?',
      confirmLabel: 'Delete',
      confirmVariant: AppButtonVariant.danger,
    );

    if (confirmed && customer.id != null) {
      final success = await widget.controller.deleteCustomer(customer.id!);
      if (success && mounted) {
        AppDialog.showSnackBar(context, 'Customer deleted successfully');
      }
    }
  }

  void _openCustomerForm([Customer? customer]) {
    Navigator.of(context).pushNamed(
      AppRoutes.customerForm,
      arguments: customer,
    ).then((saved) {
      if (saved == true && mounted) {
        AppDialog.showSnackBar(
          context,
          customer == null ? 'Customer created successfully' : 'Customer updated successfully',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: widget.isSelectionMode ? 'Select Customer For Bill' : 'Customer Management',
        showBackButton: true,
        actions: [
          AppButton(
            label: 'New Customer',
            icon: Icons.person_add,
            variant: AppButtonVariant.success,
            height: 38,
            onPressed: () => _openCustomerForm(),
          ),
          const SizedBox(width: AppDimensions.sm),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _searchController,
                      hintText: 'Search by customer name, phone number, or email...',
                      prefixIcon: Icons.search,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                widget.controller.setSearchQuery('');
                              },
                            )
                          : null,
                      onChanged: (val) => widget.controller.setSearchQuery(val),
                    ),
                  ),
                ],
              ),
            ),

            // Customer List Header Bar
            Container(
              height: AppDimensions.tableHeaderHeight,
              color: AppColors.tableHeader,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              child: const Row(
                children: [
                  SizedBox(width: 48, child: Text('', style: AppTextStyles.tableHeader)),
                  Expanded(flex: 3, child: Text('Customer / Company', style: AppTextStyles.tableHeader)),
                  Expanded(flex: 3, child: Text('Contact Info', style: AppTextStyles.tableHeader)),
                  SizedBox(width: 140, child: Text('Actions', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                ],
              ),
            ),

            // Customer List Body
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  if (widget.controller.isLoading) {
                    return const LoadingIndicator(message: 'Loading customer directory...');
                  }

                  final customers = widget.controller.customers;

                  if (customers.isEmpty) {
                    return EmptyState(
                      icon: Icons.people_outline,
                      title: 'No Customers Found',
                      message: _searchController.text.isNotEmpty
                          ? 'Try changing your search keywords'
                          : 'Add your regular clients, accounts, or corporate customers',
                      actionLabel: 'Add First Customer',
                      onAction: () => _openCustomerForm(),
                    );
                  }

                  return ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return CustomerListItem(
                        customer: customer,
                        onEdit: () => _openCustomerForm(customer),
                        onDelete: () => _handleDelete(customer),
                        onSelectForPos: widget.isSelectionMode
                            ? () {
                                if (widget.onCustomerSelected != null) {
                                  widget.onCustomerSelected!(customer);
                                }
                                Navigator.of(context).pop(customer);
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
