import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/widgets/pos_animated_loader.dart';

/// Lightweight, ultra-fast startup splash screen for 1GB RAM Android POS terminals.
class SplashScreen extends StatefulWidget {
  final AuthenticationService authService;
  final ShiftService shiftService;

  const SplashScreen({
    super.key,
    required this.authService,
    required this.shiftService,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startBootSequence();
  }

  Future<void> _startBootSequence() async {
    try {
      // Concurrently initialize SQLite backend & active session in parallel
      await Future.wait([
        DatabaseHelper.instance.database,
        widget.shiftService.checkActiveSession(),
      ]);

      // Load cashiers from ERP server via sp_Android_Common_API @Iid = 8
      final cashiers = await widget.authService.syncCashiersFromApi().timeout(const Duration(seconds: 10));
      if (cashiers.isEmpty) {
        throw Exception('No cashiers returned from ERP server');
      }

      if (!mounted) return;

      final user = widget.authService.currentUser.value;

      if (user != null) {
        if (!widget.shiftService.hasActiveDay) {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.startShift,
            arguments: true,
          );
        } else if (!widget.shiftService.hasActiveShift) {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.startShift,
            arguments: false,
          );
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.pos);
        }
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    } catch (e) {
      debugPrint('Could not load cashiers on startup: $e');
      if (!mounted) return;
      // If failed to load cashiers, load API Base URL set screen
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.apiBaseUrl,
        arguments: {
          'isInitialSetup': true,
          'initialErrorMessage': 'Could not load cashiers from ERP ($e)',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E2631), // Matches Android native launch theme
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ONIMTA MOBILE POS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 28),
              PosAnimatedLoader(
                title: 'Starting POS...',
                isDark: true,
                dotColor: Color(0xFF00B4D8),
                showCard: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
