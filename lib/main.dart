import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'app/routes/route_generator.dart';
import 'core/database/database_helper.dart';
import 'core/database/database_initializer.dart';
import 'core/services/authentication_service.dart';
import 'core/services/database_service.dart';
import 'data/datasources/local/customer_local_datasource.dart';
import 'data/datasources/local/product_local_datasource.dart';
import 'data/datasources/local/sales_local_datasource.dart';
import 'data/datasources/local/settings_local_datasource.dart';
import 'data/datasources/local/user_local_datasource.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/sales_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/user_repository.dart';
import 'features/authentication/controllers/login_controller.dart';
import 'features/customers/controllers/customer_controller.dart';
import 'features/pos/controllers/pos_controller.dart';
import 'features/products/controllers/product_controller.dart';
import 'features/settings/controllers/settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer portrait orientation for handheld POS mobile terminals
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable immersive full-screen mode (hides notification status bar and nav bar)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize SQLite cross-platform backend and pre-warm database connection
  DatabaseInitializer.initializePlatform();
  DatabaseHelper.instance.database; // Pre-warm database in background during splash/login

  // 1. Service Layer
  final DatabaseService databaseService = DatabaseServiceImpl(DatabaseHelper.instance);

  // 2. Data Source Layer
  final UserLocalDataSource userLocalDataSource = UserLocalDataSourceImpl(databaseService);
  final ProductLocalDataSource productLocalDataSource = ProductLocalDataSourceImpl(databaseService);
  final CustomerLocalDataSource customerLocalDataSource = CustomerLocalDataSourceImpl(databaseService);
  final SalesLocalDataSource salesLocalDataSource = SalesLocalDataSourceImpl(databaseService);
  final SettingsLocalDataSource settingsLocalDataSource = SettingsLocalDataSourceImpl(databaseService);

  // 3. Repository Layer
  final UserRepository userRepository = UserRepositoryImpl(userLocalDataSource);
  final ProductRepository productRepository = ProductRepositoryImpl(productLocalDataSource);
  final CustomerRepository customerRepository = CustomerRepositoryImpl(customerLocalDataSource);
  final SalesRepository salesRepository = SalesRepositoryImpl(salesLocalDataSource);
  final SettingsRepository settingsRepository = SettingsRepositoryImpl(settingsLocalDataSource);

  // 4. Core Authentication Service
  final AuthenticationService authService = AuthenticationServiceImpl(userRepository);

  // 5. Feature Controllers
  final LoginController loginController = LoginController(authService);
  final PosController posController = PosController(
    salesRepository: salesRepository,
    productRepository: productRepository,
    customerRepository: customerRepository,
    authService: authService,
    settingsRepository: settingsRepository,
  );
  final ProductController productController = ProductController(productRepository);
  final CustomerController customerController = CustomerController(customerRepository);
  final SettingsController settingsController = SettingsController(settingsRepository);

  // 6. Central Route Generator
  final RouteGenerator routeGenerator = RouteGenerator(
    authService: authService,
    loginController: loginController,
    posController: posController,
    productController: productController,
    customerController: customerController,
    settingsController: settingsController,
  );

  runApp(PosApp(routeGenerator: routeGenerator));
}
