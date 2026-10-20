import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/settings_repository.dart';

class PosFeatureDefinition {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const PosFeatureDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class PosFeature {
  static const String newBill = 'NEW_BILL';
  static const String voidBill = 'VOID_BILL';
  static const String discount = 'DISCOUNT';
  static const String exchange = 'EXCHANGE';
  static const String returnItem = 'RETURN';
  static const String heldBill = 'HELD_BILL';
  static const String paidIn = 'PAID_IN';
  static const String paidOut = 'PAID_OUTS';
  static const String reports = 'REPORTS';
  static const String customers = 'CUSTOMERS';
  static const String products = 'PRODUCTS';
  static const String downloadProducts = 'DOWNLOAD_PRODUCTS';
  static const String settings = 'SETTINGS';
  static const String shiftEnd = 'SHIFT_END';

  static const List<PosFeatureDefinition> allFeatures = [
    PosFeatureDefinition(
      id: newBill,
      name: 'New Bill',
      description: 'Start a new transaction / clear or hold bill',
      icon: Icons.note_add_outlined,
    ),
    PosFeatureDefinition(
      id: voidBill,
      name: 'Void Bill',
      description: 'Void or cancel an ongoing cart',
      icon: Icons.delete_sweep_outlined,
    ),
    PosFeatureDefinition(
      id: discount,
      name: 'Discounts',
      description: 'Apply percentage or fixed amount discounts',
      icon: Icons.percent,
    ),
    PosFeatureDefinition(
      id: exchange,
      name: 'Exchange Voucher',
      description: 'Process item exchange and issue printed voucher',
      icon: Icons.sync_alt,
    ),
    PosFeatureDefinition(
      id: returnItem,
      name: 'Returns & Refunds',
      description: 'Process item return and refunds without voucher',
      icon: Icons.assignment_return,
    ),
    PosFeatureDefinition(
      id: heldBill,
      name: 'Held Bills',
      description: 'Recall and restore held customer carts',
      icon: Icons.pause_circle_outline,
    ),
    PosFeatureDefinition(
      id: paidIn,
      name: 'Cash Paid In',
      description: 'Record cash float entry into drawer',
      icon: Icons.arrow_downward,
    ),
    PosFeatureDefinition(
      id: paidOut,
      name: 'Cash Paid Out',
      description: 'Record cash expenses / disbursements from drawer',
      icon: Icons.arrow_upward,
    ),
    PosFeatureDefinition(
      id: reports,
      name: 'Reports (Z & X Reading)',
      description: 'View & print shift reports, total sales, and item-wise sales',
      icon: Icons.analytics_outlined,
    ),
    PosFeatureDefinition(
      id: customers,
      name: 'Customers',
      description: 'Manage customers and customer accounts',
      icon: Icons.people_outline,
    ),
    PosFeatureDefinition(
      id: products,
      name: 'Products Catalog',
      description: 'Browse, search, and manage products',
      icon: Icons.inventory_2_outlined,
    ),
    PosFeatureDefinition(
      id: downloadProducts,
      name: 'Download Products',
      description: 'Sync all products catalog from ERP server',
      icon: Icons.cloud_download_outlined,
    ),
    PosFeatureDefinition(
      id: settings,
      name: 'Settings',
      description: 'Configure printer, hardware, and store preferences',
      icon: Icons.settings_outlined,
    ),
    PosFeatureDefinition(
      id: shiftEnd,
      name: 'Shift & Day End',
      description: 'Reconcile drawer cash, end shift, and close business day',
      icon: Icons.schedule,
    ),
  ];
}

class CashierPermissionsService {
  final SettingsRepository _settingsRepository;

  CashierPermissionsService(this._settingsRepository);

  String _getKey(String username) => 'permissions_${username.trim().toLowerCase()}';

  /// Loads permissions map for a given cashier.
  /// If no custom permissions have been saved, defaults all to true (allowed).
  Future<Map<String, bool>> getPermissionsForCashier(String username) async {
    final key = _getKey(username);
    final rawJson = await _settingsRepository.getSetting(key);

    final Map<String, bool> permissions = {};
    for (final f in PosFeature.allFeatures) {
      permissions[f.id] = true; // Default allowed
    }

    if (rawJson != null && rawJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          for (final f in PosFeature.allFeatures) {
            if (decoded.containsKey(f.id)) {
              permissions[f.id] = decoded[f.id] == true;
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing permissions for $username: $e');
      }
    }

    return permissions;
  }

  /// Saves updated permissions map for a given cashier.
  Future<void> savePermissionsForCashier(
    String username,
    Map<String, bool> permissions,
  ) async {
    final key = _getKey(username);
    final jsonStr = jsonEncode(permissions);
    await _settingsRepository.updateSetting(key, jsonStr);
  }

  /// Checks if a user has permission to access a specific feature.
  /// Admin users always have full permission.
  Future<bool> hasPermission(User? user, String featureId) async {
    if (user == null) return false;
    if (user.isAdmin) return true;

    final perms = await getPermissionsForCashier(user.username);
    return perms[featureId] ?? true;
  }
}
