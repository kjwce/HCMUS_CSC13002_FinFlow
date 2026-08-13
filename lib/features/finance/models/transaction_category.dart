import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    this.assetPath,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String? assetPath;

  Widget buildIcon({double? size, Color? color, Key? widgetKey}) {
    final resolvedColor = color ?? this.color;
    if (assetPath != null) {
      return Align(
        key: widgetKey,
        widthFactor: 1,
        heightFactor: 1,
        child: SvgPicture.asset(
          assetPath!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
        ),
      );
    }
    return Icon(icon, key: widgetKey, size: size, color: resolvedColor);
  }

  /// All 15 built-in categories.
  static const List<TransactionCategory> all = [
    // ── Popular 8 (shown on main Add screen) ──
    TransactionCategory(
      key: 'Food',
      label: 'Food',
      icon: Icons.restaurant,
      color: Color(0xFFE87516),
      assetPath: 'assets/icons/categories/fill/expense_food.svg',
    ),
    TransactionCategory(
      key: 'Car',
      label: 'Car',
      icon: Icons.directions_car,
      color: Color(0xFFD97706),
      assetPath: 'assets/icons/categories/fill/expense_car.svg',
    ),
    TransactionCategory(
      key: 'Gift',
      label: 'Gift',
      icon: Icons.card_giftcard,
      color: Color(0xFF2D6FC2),
      assetPath: 'assets/icons/categories/fill/expense_gift.svg',
    ),
    TransactionCategory(
      key: 'Health',
      label: 'Health',
      icon: Icons.favorite,
      color: Color(0xFF159A7D),
      assetPath: 'assets/icons/categories/fill/expense_health.svg',
    ),
    TransactionCategory(
      key: 'Clothes',
      label: 'Clothes',
      icon: Icons.checkroom,
      color: Color(0xFF6F56C9),
      assetPath: 'assets/icons/categories/fill/expense_clothes.svg',
    ),
    TransactionCategory(
      key: 'Home',
      label: 'Home',
      icon: Icons.home,
      color: Color(0xFFE05252),
      assetPath: 'assets/icons/categories/fill/expense_home.svg',
    ),
    TransactionCategory(
      key: 'Donation',
      label: 'Donation',
      icon: Icons.volunteer_activism,
      color: Color(0xFFC54886),
      assetPath: 'assets/icons/categories/fill/expense_donation.svg',
    ),
    TransactionCategory(
      key: 'Beauty',
      label: 'Beauty',
      icon: Icons.face,
      color: Color(0xFFD64F91),
      assetPath: 'assets/icons/categories/fill/expense_beauty.svg',
    ),
    // ── Extended (shown in "More" sheet) ──
    TransactionCategory(
      key: 'Transport',
      label: 'Transport',
      icon: Icons.directions_bus,
      color: Color(0xFF2878B5),
      assetPath: 'assets/icons/categories/fill/expense_transport.svg',
    ),
    TransactionCategory(
      key: 'Shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag,
      color: Color(0xFFCF4F75),
      assetPath: 'assets/icons/categories/fill/expense_shopping.svg',
    ),
    TransactionCategory(
      key: 'Subscription',
      label: 'Subscription',
      icon: Icons.subscriptions,
      color: Color(0xFF7C4DB4),
      assetPath: 'assets/icons/categories/fill/expense_subscription.svg',
    ),
    TransactionCategory(
      key: 'Bills',
      label: 'Bills',
      icon: Icons.receipt,
      color: Color(0xFF64748B),
      assetPath: 'assets/icons/categories/fill/expense_bills.svg',
    ),
    TransactionCategory(
      key: 'Salary',
      label: 'Salary',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF00897B),
      assetPath: 'assets/icons/categories/fill/income_salary.svg',
    ),
    TransactionCategory(
      key: 'Service',
      label: 'Service',
      icon: Icons.room_service_outlined,
      color: Color(0xFF168A83),
      assetPath: 'assets/icons/categories/fill/expense_service.svg',
    ),
    TransactionCategory(
      key: 'Other',
      label: 'Other',
      icon: Icons.receipt_long,
      color: Color(0xFF7A8580),
      assetPath: 'assets/icons/categories/fill/expense_other.svg',
    ),
  ];

  /// Popular 8 — shown directly on Add screen.
  static List<TransactionCategory> get popular => all.sublist(0, 8);

  /// Extended 7 — shown in "More" bottom sheet.
  static List<TransactionCategory> get extended => all.sublist(8);

  /// Look up a built-in category by its [key].
  /// Returns the "Other" category if not found (backward-compatible fallback).
  static TransactionCategory fromKey(String key) {
    return all.firstWhere(
      (c) => c.key == key,
      orElse: () => all.last, // "Other"
    );
  }

  /// Resolves both built-in and user-created categories.
  /// Unknown keys still fall back to "Other" for backward compatibility.
  static TransactionCategory resolve(String key) {
    final custom = CustomCategoryStore.instance.findByKey(key);
    if (custom != null) {
      return TransactionCategory(
        key: custom.name,
        label: custom.name,
        icon: custom.iconData,
        color: custom.color,
      );
    }
    return fromKey(key);
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
