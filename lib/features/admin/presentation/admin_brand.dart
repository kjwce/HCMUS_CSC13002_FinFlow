import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AdminBrand extends StatelessWidget {
  const AdminBrand({
    super.key,
    this.light = false,
    this.iconSize = 42,
    this.showName = true,
    this.showAdminBadge = true,
  });

  final bool light;
  final double iconSize;
  final bool showName;
  final bool showAdminBadge;

  @override
  Widget build(BuildContext context) {
    final foreground = light
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/finflow_admin_logo.svg',
          width: iconSize,
          height: iconSize,
          semanticsLabel: 'FinFlow Admin',
        ),
        if (showName) ...[
          const SizedBox(width: 11),
          Text(
            'FinFlow',
            style: TextStyle(
              fontSize: iconSize >= 40 ? 22 : 20,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
        if (showName && showAdminBadge) ...[
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: light ? Colors.white12 : const Color(0xFFE4F2EC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ADMIN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: light ? Colors.white : const Color(0xFF0B6B4F),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
