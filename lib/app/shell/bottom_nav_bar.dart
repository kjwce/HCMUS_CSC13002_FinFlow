import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

/// Floating pill navigation used across the app.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    this.selectedIndex = 0,
    this.onTabChanged,
    this.onAddTap,
  });

  final int selectedIndex;
  final ValueChanged<int>? onTabChanged;
  final VoidCallback? onAddTap;

  static const _primary = Color(0xFF07513F);
  static const _inactive = Color(0xFF64766F);

  @override
  Widget build(BuildContext context) {
    final pageColor = context.finFlowColors.pageBackground;
    final navColor = context.finFlowColors.surface;

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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF052E24).withValues(alpha: 0.16),
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
                        icon: Icons.home_rounded,
                        label: 'Home',
                        index: 0,
                      ),
                    ),
                    Expanded(
                      child: _navItem(
                        context,
                        icon: Icons.smart_toy_rounded,
                        label: 'Chatbot',
                        index: 1,
                      ),
                    ),
                    Expanded(child: _addButton(context)),
                    Expanded(
                      child: _navItem(
                        context,
                        icon: Icons.group_rounded,
                        label: 'Community',
                        index: 3,
                      ),
                    ),
                    Expanded(
                      child: _navItem(
                        context,
                        icon: Icons.person_rounded,
                        label: 'Profile',
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
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? _primary : _inactive;

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
              Icon(icon, size: Responsive.w(context, 28), color: color),
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
    return Semantics(
      button: true,
      label: 'Add transaction',
      child: InkWell(
        onTap: onAddTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Container(
            width: Responsive.w(context, 56),
            height: Responsive.w(context, 56),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: Responsive.w(context, 32),
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    if (onTabChanged != null) {
      onTabChanged!(index);
    } else {
      Navigator.of(context).pop(index);
    }
  }
}
