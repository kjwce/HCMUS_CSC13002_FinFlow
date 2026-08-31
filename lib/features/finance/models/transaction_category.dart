import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum TransactionCategoryType { expense, income }

/// Single source of truth for the transaction category catalogue.
class TransactionCategory {
  const TransactionCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    this.assetPath,
    this.type = TransactionCategoryType.expense,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String? assetPath;
  final TransactionCategoryType type;

  bool get isIncome => type == TransactionCategoryType.income;

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

  static const _expenseRoot = 'assets/icons/categories/duotone/expense';
  static const _incomeRoot = 'assets/icons/categories/duotone/income';

  static const List<TransactionCategory> expenses = [
    TransactionCategory(
      key: 'Food',
      label: 'Food',
      icon: Icons.restaurant,
      color: Color(0xFFE87516),
      assetPath: '$_expenseRoot/food.svg',
    ),
    TransactionCategory(
      key: 'Groceries',
      label: 'Groceries',
      icon: Icons.shopping_cart,
      color: Color(0xFFDB7C13),
      assetPath: '$_expenseRoot/groceries.svg',
    ),
    TransactionCategory(
      key: 'Transport',
      label: 'Transport',
      icon: Icons.directions_bus,
      color: Color(0xFF2878B5),
      assetPath: '$_expenseRoot/transport.svg',
    ),
    TransactionCategory(
      key: 'Fuel',
      label: 'Fuel',
      icon: Icons.local_gas_station,
      color: Color(0xFFD97706),
      assetPath: '$_expenseRoot/fuel.svg',
    ),
    TransactionCategory(
      key: 'Rent',
      label: 'Rent',
      icon: Icons.home_work,
      color: Color(0xFF8A5A44),
      assetPath: '$_expenseRoot/rent.svg',
    ),
    TransactionCategory(
      key: 'Utilities',
      label: 'Utilities',
      icon: Icons.bolt,
      color: Color(0xFFE0A000),
      assetPath: '$_expenseRoot/utilities.svg',
    ),
    TransactionCategory(
      key: 'Bills',
      label: 'Bills',
      icon: Icons.receipt,
      color: Color(0xFF64748B),
      assetPath: '$_expenseRoot/bills.svg',
    ),
    TransactionCategory(
      key: 'Internet & Phone',
      label: 'Internet & Phone',
      icon: Icons.wifi,
      color: Color(0xFF3976B8),
      assetPath: '$_expenseRoot/internet_phone.svg',
    ),
    TransactionCategory(
      key: 'Shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag,
      color: Color(0xFFCF4F75),
      assetPath: '$_expenseRoot/shopping.svg',
    ),
    TransactionCategory(
      key: 'Clothes',
      label: 'Clothes',
      icon: Icons.checkroom,
      color: Color(0xFF6F56C9),
      assetPath: '$_expenseRoot/clothes.svg',
    ),
    TransactionCategory(
      key: 'Beauty',
      label: 'Beauty',
      icon: Icons.face,
      color: Color(0xFFD64F91),
      assetPath: '$_expenseRoot/beauty.svg',
    ),
    TransactionCategory(
      key: 'Entertainment',
      label: 'Entertainment',
      icon: Icons.movie,
      color: Color(0xFF7857C6),
      assetPath: '$_expenseRoot/entertainment.svg',
    ),
    TransactionCategory(
      key: 'Travel',
      label: 'Travel',
      icon: Icons.flight,
      color: Color(0xFF227FA3),
      assetPath: '$_expenseRoot/travel.svg',
    ),
    TransactionCategory(
      key: 'Education',
      label: 'Education',
      icon: Icons.school,
      color: Color(0xFF4267B2),
      assetPath: '$_expenseRoot/education.svg',
    ),
    TransactionCategory(
      key: 'Fitness',
      label: 'Fitness',
      icon: Icons.fitness_center,
      color: Color(0xFF13A08A),
      assetPath: '$_expenseRoot/fitness.svg',
    ),
    TransactionCategory(
      key: 'Health',
      label: 'Health',
      icon: Icons.favorite,
      color: Color(0xFF159A7D),
      assetPath: '$_expenseRoot/health.svg',
    ),
    TransactionCategory(
      key: 'Pets',
      label: 'Pets',
      icon: Icons.pets,
      color: Color(0xFFA06B3B),
      assetPath: '$_expenseRoot/pets.svg',
    ),
    TransactionCategory(
      key: 'Gift',
      label: 'Gift',
      icon: Icons.card_giftcard,
      color: Color(0xFF2D6FC2),
      assetPath: '$_expenseRoot/gift.svg',
    ),
    TransactionCategory(
      key: 'Donation',
      label: 'Donation',
      icon: Icons.volunteer_activism,
      color: Color(0xFFC54886),
      assetPath: '$_expenseRoot/donation.svg',
    ),
    TransactionCategory(
      key: 'Subscription',
      label: 'Subscription',
      icon: Icons.subscriptions,
      color: Color(0xFF7C4DB4),
      assetPath: '$_expenseRoot/subscription.svg',
    ),
    TransactionCategory(
      key: 'Insurance',
      label: 'Insurance',
      icon: Icons.shield,
      color: Color(0xFF317D74),
      assetPath: '$_expenseRoot/insurance.svg',
    ),
    TransactionCategory(
      key: 'Loan Payment',
      label: 'Loan Payment',
      icon: Icons.payments,
      color: Color(0xFFB65C4B),
      assetPath: '$_expenseRoot/loan_payment.svg',
    ),
    TransactionCategory(
      key: 'Service',
      label: 'Service',
      icon: Icons.room_service_outlined,
      color: Color(0xFF168A83),
      assetPath: '$_expenseRoot/service.svg',
    ),
    // Keep the stored key "Other" for backward compatibility.
    TransactionCategory(
      key: 'Other',
      label: 'Other Expense',
      icon: Icons.more_horiz,
      color: Color(0xFF7A8580),
      assetPath: '$_expenseRoot/other_expense.svg',
    ),
  ];

  static const List<TransactionCategory> incomes = [
    TransactionCategory(
      key: 'Salary',
      label: 'Salary',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF00897B),
      assetPath: '$_incomeRoot/salary.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Bonus',
      label: 'Bonus',
      icon: Icons.workspace_premium,
      color: Color(0xFFD49600),
      assetPath: '$_incomeRoot/bonus.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Business',
      label: 'Business',
      icon: Icons.business_center,
      color: Color(0xFF287B6E),
      assetPath: '$_incomeRoot/business.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Freelance',
      label: 'Freelance',
      icon: Icons.laptop_mac,
      color: Color(0xFF3C73B9),
      assetPath: '$_incomeRoot/freelance.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Investment',
      label: 'Investment',
      icon: Icons.trending_up,
      color: Color(0xFF167A62),
      assetPath: '$_incomeRoot/investment.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Interest',
      label: 'Interest',
      icon: Icons.percent,
      color: Color(0xFF4C8B53),
      assetPath: '$_incomeRoot/interest.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Rental Income',
      label: 'Rental Income',
      icon: Icons.home_work,
      color: Color(0xFF8A6642),
      assetPath: '$_incomeRoot/rental_income.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Gift Received',
      label: 'Gift Received',
      icon: Icons.redeem,
      color: Color(0xFF7658B6),
      assetPath: '$_incomeRoot/gift_received.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Refund',
      label: 'Refund',
      icon: Icons.undo,
      color: Color(0xFF2489A4),
      assetPath: '$_incomeRoot/refund.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Cashback',
      label: 'Cashback',
      icon: Icons.savings,
      color: Color(0xFF00A17A),
      assetPath: '$_incomeRoot/cashback.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Allowance',
      label: 'Allowance',
      icon: Icons.wallet,
      color: Color(0xFF54805D),
      assetPath: '$_incomeRoot/allowance.svg',
      type: TransactionCategoryType.income,
    ),
    TransactionCategory(
      key: 'Other Income',
      label: 'Other Income',
      icon: Icons.add_circle_outline,
      color: Color(0xFF5F7E75),
      assetPath: '$_incomeRoot/other_income.svg',
      type: TransactionCategoryType.income,
    ),
  ];

  static const List<TransactionCategory> all = [...expenses, ...incomes];

  static List<TransactionCategory> forType({required bool isIncome}) =>
      isIncome ? incomes : expenses;

  static List<TransactionCategory> get popular => expenses.take(8).toList();
  static List<TransactionCategory> get extended => expenses.skip(8).toList();

  static const Map<String, String> _legacyAliases = {
    'Car': 'Transport',
    'Home': 'Rent',
  };

  static bool containsKey(String key) =>
      all.any((category) => category.key == key) ||
      _legacyAliases.containsKey(key);

  static TransactionCategory fromKey(String key) {
    final canonicalKey = _legacyAliases[key] ?? key;
    for (final category in all) {
      if (category.key == canonicalKey) return category;
    }
    return expenses.last;
  }

  /// Normalizes renamed legacy keys without collapsing historical detail.
  ///
  /// Older data may contain an expense-style category on a positive
  /// transaction. Charts keep that category visible so users can still see
  /// the complete historical breakdown; new entry forms enforce the split.
  static String normalizedKey(String key, {required bool isIncome}) {
    if (isIncome && key == 'Gift') return 'Gift Received';
    return _legacyAliases[key] ?? key;
  }

  static TransactionCategory resolve(String key) {
    final custom = CustomCategoryStore.instance.findByKey(key);
    if (custom != null) {
      return TransactionCategory(
        key: custom.name,
        label: custom.name,
        icon: custom.iconData,
        color: custom.color,
        type: custom.type,
      );
    }
    return fromKey(key);
  }
}

class CustomCategoryStore {
  CustomCategoryStore._();
  static final CustomCategoryStore instance = CustomCategoryStore._();

  final List<CustomCategoryDef> _items = [];
  List<CustomCategoryDef> get items => List.unmodifiable(_items);
  void add(CustomCategoryDef cat) => _items.add(cat);

  CustomCategoryDef? findByKey(String key) {
    for (final category in _items) {
      if (category.name == key) return category;
    }
    return null;
  }
}

class CustomCategoryDef {
  const CustomCategoryDef({
    required this.name,
    required this.iconData,
    required this.color,
    this.type = TransactionCategoryType.expense,
  });

  final String name;
  final IconData iconData;
  final Color color;
  final TransactionCategoryType type;
}
