import 'package:flutter/material.dart';
import 'constants/app_constants.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';
import 'theme/app_theme.dart';

/// Root POS Application Widget
class PosApp extends StatelessWidget {
  final RouteGenerator routeGenerator;

  const PosApp({
    super.key,
    required this.routeGenerator,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.login,
      onGenerateRoute: routeGenerator.generateRoute,
    );
  }
}
