import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../pos/controllers/pos_controller.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_list_item.dart';

/// Customers Screen with Header Search Bar and Direct Selection for Current Bill
class CustomersScreen extends StatefulWidget {
  final CustomerController controller;
  final PosController posController;
  final bool isSelectionMode;
  final void Function(Customer customer)? onCustomerSelected;

  const CustomersScreen({
    super.key,
    required this.controller,
    required this.posController,
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

  void _selectCustomer(Customer? customer) {
    FeedbackHelper.vibrate();
    widget.posController.selectCustomer(customer);
    if (customer != null && widget.onCustomerSelected != null) {
      widget.onCustomerSelected!(customer);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          customer != null
              ? 'Customer "${customer.name}" assigned to current bill.'
              : 'Current bill set to Walk-in Customer.',
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.pos, (route) => false);
  }

  Widget _buildWalkInTile(bool isSelected) {
    return Material(
      color: isSelected ? const Color(0xFFE0F2FE) : AppColors.surface,
      child: InkWell(
        onTap: () => _selectCustomer(null),
        splashColor: AppColors.primaryLight,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE0F2FE) : AppColors.surfaceSecondary,
            border: Border(
              bottom: const BorderSide(color: AppColors.border, width: 1.2),
              left: isSelected
                  ? const BorderSide(color: Color(0xFF0284C7), width: 4.0)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0284C7) : AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: isSelected ? Colors.white : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Walk-in Customer (Default)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: isSelected ? const Color(0xFF0369A1) : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Unassigned / General counter sale',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
                size: 18,
                color: isSelected ? const Color(0xFF0284C7) : AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCustomer = widget.posController.selectedCustomer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.pos, (route) => false),
          tooltip: 'Back to POS',
        ),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search customer by name or phone...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        widget.controller.setSearchQuery('');
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (val) {
              widget.controller.setSearchQuery(val);
              setState(() {});
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Prominent Walk-in Button (Default / Unassigned)
            _buildWalkInTile(selectedCustomer == null),

            // Section Divider Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: AppColors.tableHeader,
              width: double.infinity,
              child: const Text(
                'CUSTOMER DIRECTORY (TAP TO ASSIGN TO BILL)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
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
                          ? 'No matching customer found for "${_searchController.text}"'
                          : 'No registered customers available',
                    );
                  }

                  return ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final isSelected = selectedCustomer?.id == customer.id ||
                          (selectedCustomer?.name == customer.name && customer.name.isNotEmpty);

                      return CustomerListItem(
                        customer: customer,
                        isSelected: isSelected,
                        onTap: () => _selectCustomer(customer),
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
