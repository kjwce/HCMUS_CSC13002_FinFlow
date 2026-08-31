import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        ? const Color(0xFF112622)
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
                        regularAsset:
                            'assets/icons/navigation/house-line-regular.svg',
                        filledAsset:
                            'assets/icons/navigation/house-line-fill.svg',
                        label: AppStrings.navHome,
                        index: 0,
                      ),
                    ),
                    Expanded(
                      child: _navItem(
                        context,
                        regularAsset:
                            'assets/icons/navigation/robot-regular.svg',
                        filledAsset: 'assets/icons/navigation/robot-fill.svg',
                        label: AppStrings.choose('Chatbot', 'Trợ lý AI'),
                        index: 1,
                      ),
                    ),
                    Expanded(child: _addButton(context)),
                    Expanded(
                      child: _navItem(
                        context,
                        regularAsset:
                            'assets/icons/navigation/users-three-regular.svg',
                        filledAsset:
                            'assets/icons/navigation/users-three-fill.svg',
                        label: AppStrings.navCommunity,
                        index: 3,
                      ),
                    ),
                    Expanded(
                      child: _navItem(
                        context,
                        regularAsset:
                            'assets/icons/navigation/user-circle-regular.svg',
                        filledAsset:
                            'assets/icons/navigation/user-circle-fill.svg',
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
    required String regularAsset,
    required String filledAsset,
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
    final iconAsset = isSelected ? filledAsset : regularAsset;

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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: SvgPicture.asset(
                    iconAsset,
                    key: Key(
                      'bottom-nav-icon-$index-${isSelected ? 'fill' : 'regular'}',
                    ),
                    width: Responsive.w(context, 28),
                    height: Responsive.w(context, 28),
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(context, 1)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 11.5),
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
                  ? const Color(0xFF006C53)
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
                color: Colors.white,
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
