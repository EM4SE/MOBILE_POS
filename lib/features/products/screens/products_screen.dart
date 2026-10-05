import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../controllers/product_controller.dart';
import '../../pos/controllers/pos_controller.dart';

/// Product Grid Selection Screen with search in header and 3-per-row square cards
class ProductsScreen extends StatefulWidget {
  final ProductController controller;
  final PosController? posController;
  final bool isSelectionMode;
  final void Function(Product product)? onProductSelected;

  const ProductsScreen({
    super.key,
    required this.controller,
    this.posController,
    this.isSelectionMode = false,
    this.onProductSelected,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleProductTap(Product product) {
    if (widget.posController != null) {
      widget.posController!.addProductToCart(product);
      AppDialog.showTopAlert(
        context,
        'Added "${product.description}" to bill',
      );
    }
    if (widget.onProductSelected != null) {
      widget.onProductSelected!(product);
    }
    if (widget.isSelectionMode) {
      Navigator.of(context).pop(product);
    }
  }

  Widget _buildProductCard(Product product) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      elevation: 1,
      child: InkWell(
        onTap: () => _handleProductTap(product),
        splashColor: AppColors.primaryLight,
        highlightColor: const Color(0xFFCCE4F0),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Product Code / Tag
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    product.code,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),

              // Product Description
              Expanded(
                child: Center(
                  child: Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
              ),

              // Product Price
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  CurrencyFormatter.formatWithSymbol(product.price),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppDimensions.sm),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search products by name or code...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
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
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            if (widget.controller.isLoading) {
              return const LoadingIndicator(message: 'Loading products...');
            }

            final products = widget.controller.products;

            if (products.isEmpty) {
              return EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No Products Found',
                message: _searchController.text.isNotEmpty
                    ? 'No items match "${_searchController.text}"'
                    : 'Product catalog is empty',
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(AppDimensions.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(products[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
