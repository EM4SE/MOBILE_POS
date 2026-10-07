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

/// Product Grid Selection Screen with search in header, lazy loading on scroll, and 3-per-row cards
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadProducts(refresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
        widget.controller.loadMoreProducts();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
          padding: const EdgeInsets.all(7.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Code & Optional ISBN / Barcode Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        product.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  if (product.isbn.isNotEmpty && product.isbn != product.code) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          product.isbn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Product Description
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.18,
                      ),
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
                    fontSize: 12.5,
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
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name, code, barcode, or ISBN...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        widget.controller.clearSearch();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            tooltip: 'Sync from Server',
            onPressed: () async {
              AppDialog.showSnackBar(context, 'Syncing products from server...');
              final count = await widget.controller.syncProductsFromApi();
              if (context.mounted) {
                AppDialog.showSnackBar(context, 'Synced $count products successfully');
              }
            },
          ),
        ],
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
              return RefreshIndicator(
                onRefresh: () async {
                  await widget.controller.loadProducts(refresh: true);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No Products Found',
                        message: _searchController.text.isNotEmpty
                            ? 'No items match "${_searchController.text}"'
                            : 'Product catalog is empty. Tap sync to load from API.',
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await widget.controller.loadProducts(refresh: true);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Total Count Header Info
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${products.length} of ${widget.controller.totalCount} items',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (widget.controller.hasMore)
                            const Text(
                              'Scroll for more',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Product Grid Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 7,
                        mainAxisSpacing: 7,
                        childAspectRatio: 0.95,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildProductCard(products[index]);
                        },
                        childCount: products.length,
                      ),
                    ),
                  ),

                  // Bottom Loading Indicator for Infinite Scroll
                  if (widget.controller.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
