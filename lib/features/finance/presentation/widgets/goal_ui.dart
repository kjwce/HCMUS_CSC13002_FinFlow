import 'package:flutter/material.dart';

import '../../../../core/i18n/app_language.dart';
import '../../models/goal_category.dart';

const goalPrimary = Color(0xFF006C53);
const goalDark = Color(0xFF00513E);
const goalMint = Color(0xFFE2F5ED);
const goalSuccess = Color(0xFF00C49A);
const goalSurface = Color(0xFFF9F9FC);
const goalSurfaceLow = Color(0xFFF3F3F6);
const goalOutline = Color(0xFFBEC9C3);
const goalText = Color(0xFF1A1C1E);
const goalMuted = Color(0xFF3E4944);
const goalError = Color(0xFFBA1A1A);

String formatVnd(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}${buffer.toString()}';
}

String formatGoalDate(DateTime? date) {
  if (date == null) {
    return AppStrings.choose('No target date', 'Không có ngày mục tiêu');
  }
  if (AppStrings.isVietnamese) {
    return '${date.day} Thg ${date.month}, ${date.year}';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

Widget goalIconWidgetFor(
  String category, {
  required Color color,
  required double size,
}) => GoalCategory.fromKey(category).buildIcon(color: color, size: size);

class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.value, this.height = 10});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = value.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rawWidth = constraints.maxWidth * progress;
          final fillWidth = progress <= 0
              ? 0.0
              : rawWidth.clamp(height, constraints.maxWidth);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF29483F) : goalSurfaceLow,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: fillWidth,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF38D6AC) : goalPrimary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GoalIconTile extends StatelessWidget {
  const GoalIconTile({super.key, required this.category, this.size = 44});

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolved = GoalCategory.fromKey(category);
    final accent = resolved.color;
    final iconSize = (size * .46).clamp(18.0, 22.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B3D35) : accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF29483F)) : null,
      ),
      child: goalIconWidgetFor(
        category,
        color: isDark && accent == goalPrimary
            ? const Color(0xFF38D6AC)
            : accent,
        size: iconSize,
      ),
    );
  }
}

ButtonStyle goalFilledButtonStyle() => FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  backgroundColor: goalPrimary,
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  textStyle: const TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 14,
  ),
);
