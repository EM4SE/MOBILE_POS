import 'package:flutter/material.dart';
import '../../core/services/authentication_service.dart';
import '../../core/services/shift_service.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../features/authentication/controllers/login_controller.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/customers/controllers/customer_controller.dart';
import '../../features/customers/screens/customer_form_screen.dart';
import '../../features/customers/screens/customers_screen.dart';
import '../../features/more/screens/more_screen.dart';
import '../../features/pos/controllers/pos_controller.dart';
import '../../features/pos/screens/bill_detail_screen.dart';
import '../../features/pos/screens/cash_movement_screen.dart';
import '../../features/pos/screens/discount_screen.dart';
import '../../features/pos/screens/exchange_screen.dart';
import '../../features/pos/screens/held_bills_screen.dart';
import '../../features/pos/screens/payment_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/pos/screens/return_screen.dart';
import '../../features/products/controllers/product_controller.dart';
import '../../features/products/screens/product_form_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/reports/screens/item_wise_sales_screen.dart';
import '../../features/reports/screens/reports_menu_screen.dart';
import '../../features/reports/screens/total_sales_screen.dart';
import '../../features/reports/screens/x_reading_screen.dart';
import '../../features/reports/screens/z_reading_screen.dart';
import '../../features/settings/controllers/settings_controller.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/shift/screens/end_shift_screen.dart';
import '../../features/shift/screens/start_shift_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import 'app_routes.dart';

/// Central RouteGenerator dispatching named routes with controller & repository dependencies
class RouteGenerator {
  final AuthenticationService authService;
  final ShiftService shiftService;
  final LoginController loginController;
  final PosController posController;
  final ProductController productController;
  final CustomerController customerController;
  final SettingsController settingsController;
  final SalesRepository salesRepository;
  final ShiftRepository shiftRepository;

  RouteGenerator({
    required this.authService,
    required this.shiftService,
    required this.loginController,
    required this.posController,
    required this.productController,
    required this.customerController,
    required this.settingsController,
    required this.salesRepository,
    required this.shiftRepository,
  });

  Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.initial:
        return _buildRoute(
          SplashScreen(
            authService: authService,
            shiftService: shiftService,
          ),
          settings,
        );

      case AppRoutes.login:
        return _buildRoute(
          LoginScreen(
            controller: loginController,
            shiftService: shiftService,
          ),
          settings,
        );

      case AppRoutes.startShift:
        final isDayStart = (settings.arguments as bool?) ?? true;
        return _buildRoute(
          StartShiftScreen(
            shiftService: shiftService,
            authService: authService,
            isDayStart: isDayStart,
          ),
          settings,
        );

      case AppRoutes.endShift:
        return _buildRoute(
          EndShiftScreen(
            shiftService: shiftService,
            authService: authService,
          ),
          settings,
        );

      case AppRoutes.pos:
        return _buildRoute(
          PosScreen(
            controller: posController,
            authService: authService,
          ),
          settings,
        );

      case AppRoutes.more:
        return _buildRoute(
          MoreScreen(
            authService: authService,
            posController: posController,
          ),
          settings,
        );

      case AppRoutes.reports:
        return _buildRoute(
          const ReportsMenuScreen(),
          settings,
        );

      case AppRoutes.reportItemWise:
        return _buildRoute(
          ItemWiseSalesScreen(
            salesRepository: salesRepository,
            authService: authService,
          ),
          settings,
        );

      case AppRoutes.reportTotalSales:
        return _buildRoute(
          TotalSalesScreen(
            salesRepository: salesRepository,
            authService: authService,
          ),
          settings,
        );

      case AppRoutes.reportXReading:
        return _buildRoute(
          XReadingScreen(
            shiftRepository: shiftRepository,
            shiftService: shiftService,
            authService: authService,
          ),
          settings,
        );

      case AppRoutes.reportZReading:
        return _buildRoute(
          ZReadingScreen(
            shiftRepository: shiftRepository,
            shiftService: shiftService,
            authService: authService,
          ),
          settings,
        );

      case AppRoutes.products:
        final args = settings.arguments as Map<String, dynamic>?;
        final isSelectionMode = args?['isSelectionMode'] as bool? ?? false;
        final onSelected = args?['onProductSelected'] as void Function(Product)?;

        return _buildRoute(
          ProductsScreen(
            controller: productController,
            posController: posController,
            isSelectionMode: isSelectionMode,
            onProductSelected: onSelected,
          ),
          settings,
        );

      case AppRoutes.productForm:
        final product = settings.arguments as Product?;
        return _buildRoute(
          ProductFormScreen(
            controller: productController,
            productToEdit: product,
          ),
          settings,
        );

      case AppRoutes.customers:
        final args = settings.arguments as Map<String, dynamic>?;
        final isSelectionMode = args?['isSelectionMode'] as bool? ?? false;
        final onSelected = args?['onCustomerSelected'] as void Function(Customer)?;

        return _buildRoute(
          CustomersScreen(
            controller: customerController,
            posController: posController,
            isSelectionMode: isSelectionMode,
            onCustomerSelected: onSelected,
          ),
          settings,
        );

      case AppRoutes.customerForm:
        final customer = settings.arguments as Customer?;
        return _buildRoute(
          CustomerFormScreen(
            controller: customerController,
            customerToEdit: customer,
          ),
          settings,
        );

      case AppRoutes.settings:
        return _buildRoute(
          SettingsScreen(
            controller: settingsController,
            authService: authService,
          ),
          settings,
        );

      case AppRoutes.payment:
        return _buildRoute(
          PaymentScreen(controller: posController),
          settings,
        );

      case AppRoutes.billDetail:
        final sale = settings.arguments as Sale;
        return _buildRoute(
          BillDetailScreen(sale: sale),
          settings,
        );

      case AppRoutes.heldBills:
        return _buildRoute(
          HeldBillsScreen(posController: posController),
          settings,
        );

      case AppRoutes.cashMovement:
        final isPaidIn = (settings.arguments as bool?) ?? true;
        return _buildRoute(
          CashMovementScreen(
            isPaidIn: isPaidIn,
            shiftService: shiftService,
            authService: authService,
          ),
          settings,
        );

      case AppRoutes.discount:
        return _buildRoute(
          DiscountScreen(posController: posController),
          settings,
        );

      case AppRoutes.exchange:
        return _buildRoute(
          ExchangeScreen(controller: posController),
          settings,
        );

      case AppRoutes.returnItem:
        return _buildRoute(
          ReturnScreen(controller: posController),
          settings,
        );

      default:
        return _errorRoute(settings.name);
    }
  }

  PageRouteBuilder _buildRoute(Widget screen, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  Route<dynamic> _errorRoute(String? routeName) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('No route defined for $routeName'),
        ),
      ),
    );
  }
}
