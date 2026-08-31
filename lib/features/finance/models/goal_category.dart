import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Goal-specific categories, independent from income and expense categories.
class GoalCategory {
  const GoalCategory({
    required this.key,
    required this.label,
    required this.color,
    required this.assetPath,
  });

  final String key;
  final String label;
  final Color color;
  final String assetPath;

  Widget buildIcon({double? size, Color? color, Key? widgetKey}) => Align(
    key: widgetKey,
    widthFactor: 1,
    heightFactor: 1,
    child: SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color ?? this.color, BlendMode.srcIn),
    ),
  );

  static const _root = 'assets/icons/categories/duotone/goals';

  static const List<GoalCategory> all = [
    GoalCategory(
      key: 'Emergency Fund',
      label: 'Emergency Fund',
      color: Color(0xFFD84D4D),
      assetPath: '$_root/emergency_fund.svg',
    ),
    GoalCategory(
      key: 'Home',
      label: 'Home',
      color: Color(0xFFE05252),
      assetPath: '$_root/home.svg',
    ),
    GoalCategory(
      key: 'Vehicle',
      label: 'Vehicle',
      color: Color(0xFFD97706),
      assetPath: '$_root/vehicle.svg',
    ),
    GoalCategory(
      key: 'Travel',
      label: 'Travel',
      color: Color(0xFF2878B5),
      assetPath: '$_root/travel.svg',
    ),
    GoalCategory(
      key: 'Education',
      label: 'Education',
      color: Color(0xFF4267B2),
      assetPath: '$_root/education.svg',
    ),
    GoalCategory(
      key: 'Technology',
      label: 'Technology',
      color: Color(0xFF6750A4),
      assetPath: '$_root/technology.svg',
    ),
    GoalCategory(
      key: 'Wedding',
      label: 'Wedding',
      color: Color(0xFFC54886),
      assetPath: '$_root/wedding.svg',
    ),
    GoalCategory(
      key: 'Family',
      label: 'Family',
      color: Color(0xFF168A83),
      assetPath: '$_root/family.svg',
    ),
    GoalCategory(
      key: 'Health',
      label: 'Health',
      color: Color(0xFF159A7D),
      assetPath: '$_root/health.svg',
    ),
    GoalCategory(
      key: 'Business',
      label: 'Business',
      color: Color(0xFF8A6642),
      assetPath: '$_root/business.svg',
    ),
    GoalCategory(
      key: 'Investment',
      label: 'Investment',
      color: Color(0xFF087A5A),
      assetPath: '$_root/investment.svg',
    ),
    GoalCategory(
      key: 'Retirement',
      label: 'Retirement',
      color: Color(0xFFD49600),
      assetPath: '$_root/retirement.svg',
    ),
    GoalCategory(
      key: 'Shopping',
      label: 'Shopping',
      color: Color(0xFFCF4F75),
      assetPath: '$_root/shopping.svg',
    ),
    GoalCategory(
      key: 'Other Goal',
      label: 'Other Goal',
      color: Color(0xFF7A8580),
      assetPath: '$_root/other_goal.svg',
    ),
  ];

  static GoalCategory fromKey(String key) {
    final normalized = _canonicalKey(key);
    return all.firstWhere(
      (category) => category.key == normalized,
      orElse: () => all.last,
    );
  }

  /// Maps categories saved before Goal received its own catalogue.
  static String canonicalKey(String key) => fromKey(key).key;

  static String _canonicalKey(String key) {
    final normalized = key.trim().toLowerCase();
    for (final category in all) {
      if (category.key.toLowerCase() == normalized) return category.key;
    }
    return switch (normalized) {
      'car' || 'transport' || 'fuel' => 'Vehicle',
      'rent' || 'utilities' => 'Home',
      'tech' ||
      'tech upgrade' ||
      'internet & phone' ||
      'subscription' => 'Technology',
      'food' || 'groceries' || 'pets' || 'gift' => 'Family',
      'fitness' || 'insurance' => 'Health',
      'freelance' => 'Business',
      'interest' => 'Investment',
      'clothes' || 'beauty' => 'Shopping',
      'other' || 'other expense' || 'other income' => 'Other Goal',
      _ => 'Other Goal',
    };
  }
}
