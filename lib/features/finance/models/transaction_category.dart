import 'package:flutter/material.dart';

/// Single source of truth for all transaction categories.
///
/// Each entry defines the key (stored in DB), display label, icon, and color.
/// The first 8 entries are the "popular" ones shown on the main Add screen.
class TransactionCategory {
  const TransactionCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;

  /// All 14 built-in categories.
  static const List<TransactionCategory> all = [
    // ── Popular 8 (shown on main Add screen) ──
    TransactionCategory(
      key: 'Food',
      label: 'Food',
      icon: Icons.restaurant,
      color: Color(0xFF50D244),
    ),
    TransactionCategory(
      key: 'Car',
      label: 'Car',
      icon: Icons.directions_car,
      color: Color(0xFFFF8C21),
    ),
    TransactionCategory(
      key: 'Gift',
      label: 'Gift',
      icon: Icons.card_giftcard,
      color: Color(0xFF0076E3),
    ),
    TransactionCategory(
      key: 'Health',
      label: 'Health',
      icon: Icons.favorite,
      color: Color(0xFF1ABF97),
    ),
    TransactionCategory(
      key: 'Clothes',
      label: 'Clothes',
      icon: Icons.checkroom,
      color: Color(0xFFA854EA),
    ),
    TransactionCategory(
      key: 'Home',
      label: 'Home',
      icon: Icons.home,
      color: Color(0xFFFF5843),
    ),
    TransactionCategory(
      key: 'Donation',
      label: 'Donation',
      icon: Icons.volunteer_activism,
      color: Color(0xFFFF7AE2),
    ),
    TransactionCategory(
      key: 'Beauty',
      label: 'Beauty',
      icon: Icons.face,
      color: Color(0xFF5E957D),
    ),
    // ── Extended (shown in "More" sheet) ──
    TransactionCategory(
      key: 'Transport',
      label: 'Transport',
      icon: Icons.directions_bus,
      color: Color(0xFF3799D2),
    ),
    TransactionCategory(
      key: 'Shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag,
      color: Color(0xFFFF6384),
    ),
    TransactionCategory(
      key: 'Subscription',
      label: 'Subscription',
      icon: Icons.subscriptions,
      color: Color(0xFF9C27B0),
    ),
    TransactionCategory(
      key: 'Bills',
      label: 'Bills',
      icon: Icons.receipt,
      color: Color(0xFF795548),
    ),
    TransactionCategory(
      key: 'Salary',
      label: 'Salary',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF00897B),
    ),
    TransactionCategory(
      key: 'Other',
      label: 'Other',
      icon: Icons.receipt_long,
      color: Color(0xFF9E9E9E),
    ),
  ];

  /// Popular 8 — shown directly on Add screen.
  static List<TransactionCategory> get popular => all.sublist(0, 8);

  /// Extended 6 — shown in "More" bottom sheet.
  static List<TransactionCategory> get extended => all.sublist(8);

  /// Look up a built-in category by its [key].
  /// Returns the "Other" category if not found (backward-compatible fallback).
  static TransactionCategory fromKey(String key) {
    return all.firstWhere(
      (c) => c.key == key,
      orElse: () => all.last, // "Other"
    );
  }
}

/// In-memory store for user-defined custom categories.
class CustomCategoryStore {
  CustomCategoryStore._();
  static final CustomCategoryStore instance = CustomCategoryStore._();

  final List<CustomCategoryDef> _items = [];

  List<CustomCategoryDef> get items => List.unmodifiable(_items);

  void add(CustomCategoryDef cat) => _items.add(cat);

  /// Look up icon/color for a custom category key.
  CustomCategoryDef? findByKey(String key) {
    for (final c in _items) {
      if (c.name == key) return c;
    }
    return null;
  }
}

class CustomCategoryDef {
  const CustomCategoryDef({
    required this.name,
    required this.iconData,
    required this.color,
  });
  final String name;
  final IconData iconData;
  final Color color;
}
