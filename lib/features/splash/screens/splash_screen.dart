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
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
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
