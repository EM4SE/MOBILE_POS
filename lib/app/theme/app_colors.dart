import 'package:flutter/material.dart';

/// Centralized color palette tailored for high-contrast commercial POS terminals
/// Features flat sharp tiles, high legibility, and professional dark & light contrast.
class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primary = Color(0xFF006699); // Crisp POS Navy/Cyan blue
  static const Color primaryDark = Color(0xFF004466);
  static const Color primaryLight = Color(0xFFE6F2F8);

  // Accent & Action colors (Windows 8 metro-inspired sharp accents)
  static const Color accent = Color(0xFF0078D7);
  static const Color success = Color(0xFF107C41); // Office Green
  static const Color warning = Color(0xFFD83B01); // High-vis Orange
  static const Color error = Color(0xFFE81123); // Sharp Red
  static const Color info = Color(0xFF008272); // Teal

  // Tile specific colors (Windows 8 Metro style)
  static const Color tileProducts = Color(0xFF0078D7); // Cobalt Blue
  static const Color tileCustomers = Color(0xFF107C41); // Green
  static const Color tilePos = Color(0xFF008272); // Teal/Emerald
  static const Color tileSettings = Color(0xFF5C2D91); // Purple
  static const Color tileReports = Color(0xFFD83B01); // Orange
  static const Color tileLogout = Color(0xFFD13438); // Crimson

  // Neutral / Layout colors
  static const Color background = Color(0xFFF2F4F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFEAECEF);
  static const Color headerBackground = Color(0xFF1E2631); // Dark charcoal header

  // Table & grid colors
  static const Color tableHeader = Color(0xFF2C3E50);
  static const Color tableRowEven = Color(0xFFFFFFFF);
  static const Color tableRowOdd = Color(0xFFF7F9FB);
  static const Color tableRowSelected = Color(0xFFD4E6F1);
  static const Color border = Color(0xFFD1D5DB);
  static const Color borderDark = Color(0xFF9CA3AF);

  // Typography colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF9FAFB);

  // Keypad colors
  static const Color keypadBackground = Color(0xFFE5E7EB);
  static const Color keypadButton = Color(0xFFFFFFFF);
  static const Color keypadButtonPress = Color(0xFFCBD5E1);
  static const Color keypadAction = Color(0xFF107C41);
  static const Color keypadActionText = Color(0xFFFFFFFF);
  static const Color keypadDelete = Color(0xFFE81123);
}
