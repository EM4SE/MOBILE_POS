import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../shared/widgets/app_header.dart';

/// 2x2 Square Grid Action Menu for POS Reports (Identical styling to More Menu)
class ReportsMenuScreen extends StatelessWidget {
  const ReportsMenuScreen({super.key});

  Widget _buildSquareTile({
    required BuildContext context,
    required String label,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 2,
      child: InkWell(
        onTap: () {
          FeedbackHelper.vibrate();
          onTap();
        },
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
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
      appBar: const AppHeader(
        title: 'REPORTS & READINGS',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              // 1. ITEM WISE SALE
              _buildSquareTile(
                context: context,
                label: 'ITEM WISE SALE',
                description: 'Sales quantity & revenue per product item',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF0891B2), // Cyan/Teal
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.reportItemWise),
              ),

              // 2. TOTAL SALE
              _buildSquareTile(
                context: context,
                label: 'TOTAL SALE',
                description: 'Overall sales, discounts, returns & payment breakdown',
                icon: Icons.assessment_outlined,
                color: const Color(0xFF0D6EFD), // POS Blue
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.reportTotalSales),
              ),

              // 3. Z READING (Day End Summary)
              _buildSquareTile(
                context: context,
                label: 'Z READING',
                description: 'Full Day End financial & drawer reconciliation',
                icon: Icons.receipt_long,
                color: const Color(0xFFDC3545), // Danger Red
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.reportZReading),
              ),

              // 4. X READING (Current Shift Summary)
              _buildSquareTile(
                context: context,
                label: 'X READING',
                description: 'Live mid-shift sales & drawer audit',
                icon: Icons.summarize_outlined,
                color: const Color(0xFFD97706), // Warm Amber
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.reportXReading),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
