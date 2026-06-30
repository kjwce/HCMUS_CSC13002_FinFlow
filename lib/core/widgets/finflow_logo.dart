import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

class FinFlowLogo extends StatelessWidget {
  const FinFlowLogo({
    super.key,
    this.foregroundColor = AppColors.deepEmerald,
    this.showText = true,
    this.size = 72,
  });

  final Color foregroundColor;
  final bool showText;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/finflow_logo.svg',
          height: size,
          width: size,
          colorFilter: foregroundColor == AppColors.deepEmerald
              ? null
              : ColorFilter.mode(foregroundColor, BlendMode.srcIn),
        ),
        if (showText) ...[
          const SizedBox(height: 8),
          Text(
            'FinFlow',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}
