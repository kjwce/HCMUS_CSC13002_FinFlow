import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// One switch keeps the finance-pattern trial fully reversible.
abstract final class AuthBackgroundStyle {
  static const useFinancePattern = true;
}

class DecoratedPhoneScaffold extends StatelessWidget {
  const DecoratedPhoneScaffold({
    super.key,
    required this.child,
    this.backgroundColor,
    this.showCorners = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final bool showCorners;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? context.finFlowColors.pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            if (AuthBackgroundStyle.useFinancePattern)
              const Positioned.fill(child: AuthFinanceBackground())
            else if (showCorners)
              const _CornerBlobs(),
            child,
          ],
        ),
      ),
    );
  }
}

class AuthFinanceBackground extends StatelessWidget {
  const AuthFinanceBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Opacity(
        opacity: isDark ? 0.10 : 0.20,
        child: Image.asset(
          'assets/images/auth_finance_pattern.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          color: isDark ? const Color(0xFF176B58) : null,
          colorBlendMode: isDark ? BlendMode.modulate : null,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _CornerBlobs extends StatelessWidget {
  const _CornerBlobs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: Responsive.w(context, -38),
            top: Responsive.h(context, -32),
            child: _Blob(
              size: Responsive.w(context, 120),
              alignment: Alignment.bottomRight,
            ),
          ),
          Positioned(
            right: Responsive.w(context, -44),
            bottom: Responsive.h(context, -36),
            child: _Blob(
              size: Responsive.w(context, 140),
              alignment: Alignment.topLeft,
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.alignment});

  final double size;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.55),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(alignment == Alignment.topLeft ? size : 24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(
            alignment == Alignment.bottomRight ? size : 24,
          ),
        ),
      ),
    );
  }
}
