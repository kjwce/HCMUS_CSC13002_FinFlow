import 'package:flutter/material.dart';

import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

/// Floating pill navigation used across the app.
class AppBottomNavBar extends StatefulWidget {
  const AppBottomNavBar({
    super.key,
    this.selectedIndex = 0,
    this.onTabChanged,
    this.onAddTap,
  });

  final int selectedIndex;
  final ValueChanged<int>? onTabChanged;
  final VoidCallback? onAddTap;

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  int? _bouncingIndex;
  bool _isAddAnimating = false;

  static const _primary = Color(0xFF07513F);
  static const _inactive = Color(0xFF64766F);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark
        ? const Color(0xFF081C18)
        : context.finFlowColors.pageBackground;
    final navColor = isDark
        ? const Color(0xFF16352E)
        : context.finFlowColors.surface;

    return ColoredBox(
      color: pageColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: Responsive.h(context, 70),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.w(context, 16),
              Responsive.h(context, 4),
              Responsive.w(context, 16),
              Responsive.h(context, 4),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: navColor,
                borderRadius: BorderRadius.circular(999),
                border: isDark
                    ? Border.all(color: const Color(0xFF29483F))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x66000000)
                        : const Color(0xFF052E24).withValues(alpha: 0.16),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _navItem(
                        context,
                        outlinedIcon: Icons.home_outlined,
                        filledIcon: Icons.home_rounded,
                        label: AppStrings.navHome,
                        index: 0,
                      ),
                    ),
                    Expanded(
                      child: _navItem(
                        context,
                        outlinedIcon: Icons.smart_toy_outlined,
                        filledIcon: Icons.smart_toy_rounded,
                        label: AppStrings.choose('Chatbot', 'Trợ lý AI'),
                        index: 1,
                      ),
                    ),
                    Expanded(child: _addButton(context)),
                    Expanded(
                      child: _navItem(
                        context,
                        outlinedIcon: Icons.group_outlined,
                        filledIcon: Icons.group_rounded,
                        label: AppStrings.navCommunity,
                        index: 3,
                      ),
                    ),
                    Expanded(
                      child: _navItem(
                        context,
                        outlinedIcon: Icons.person_outline_rounded,
                        filledIcon: Icons.person_rounded,
                        label: AppStrings.navProfile,
                        index: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData outlinedIcon,
    required IconData filledIcon,
    required String label,
    required int index,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = widget.selectedIndex == index;
    final color = isDark
        ? isSelected
              ? const Color(0xFF38D6AC)
              : const Color(0xFFA9C1B9)
        : isSelected
        ? _primary
        : _inactive;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: () => _onTap(context, index),
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSlide(
                offset: _bouncingIndex == index
                    ? const Offset(0, -0.20)
                    : Offset.zero,
                duration: const Duration(milliseconds: 150),
                curve: _bouncingIndex == index
                    ? Curves.easeOutCubic
                    : Curves.easeInCubic,
                child: Icon(
                  isSelected ? filledIcon : outlinedIcon,
                  size: Responsive.w(context, 28),
                  color: color,
                ),
              ),
              SizedBox(height: Responsive.h(context, 1)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 10),
                  height: 1.1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: AppStrings.addTransaction,
      child: InkWell(
        onTap: _isAddAnimating ? null : _onAddButtonTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: Responsive.w(context, 56),
            height: Responsive.w(context, 56),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF38D6AC)
                  : _isAddAnimating
                  ? _primary
                  : AppColors.primaryGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(
                    alpha: _isAddAnimating ? 0.32 : 0.22,
                  ),
                  blurRadius: _isAddAnimating ? 18 : 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: AnimatedRotation(
              // 45 degrees turns the plus into a close icon. A 180-degree
              // rotation would still look like a plus.
              turns: _isAddAnimating ? .125 : 0,
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.add_rounded,
                color: isDark ? const Color(0xFF081C18) : Colors.white,
                size: Responsive.w(context, 32),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onAddButtonTap() {
    if (_isAddAnimating) return;
    setState(() {
      _isAddAnimating = true;
    });

    Future<void>.delayed(const Duration(milliseconds: 175), () {
      if (!mounted) return;
      widget.onAddTap?.call();
      if (mounted) setState(() => _isAddAnimating = false);
    });
  }

  void _onTap(BuildContext context, int index) {
    setState(() => _bouncingIndex = index);
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (mounted && _bouncingIndex == index) {
        setState(() => _bouncingIndex = null);
      }
    });

    if (widget.onTabChanged != null) {
      widget.onTabChanged!(index);
    } else {
      Navigator.of(context).pop(index);
    }
  }
}
