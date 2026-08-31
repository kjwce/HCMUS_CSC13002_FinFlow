import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/home_header_controls.dart';
import '../../../core/widgets/decorated_phone_scaffold.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.finFlowColors.pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            if (AuthBackgroundStyle.useFinancePattern)
              const Positioned.fill(child: AuthFinanceBackground()),
            // Decorative teal ellipses (like Figma "shape" instances)
            if (!AuthBackgroundStyle.useFinancePattern)
              IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      right: Responsive.w(context, -44),
                      top: Responsive.h(context, -36),
                      child: _DecorativeCircle(
                        size: Responsive.w(context, 200),
                        isDark: isDark,
                      ),
                    ),
                    Positioned(
                      left: Responsive.w(context, -38),
                      bottom: Responsive.h(context, -32),
                      child: _DecorativeCircle(
                        size: Responsive.w(context, 200),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            // Main content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/finflow_logo.svg',
                    height: Responsive.w(context, 109),
                    width: Responsive.w(context, 109),
                    colorFilter: ColorFilter.mode(
                      AppColors.primaryGreen,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 14)),
                  Text(
                    'FinFlow',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontFamily: 'Hanken Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.sp(context, 52),
                      height: 1,
                      letterSpacing: -1.2,
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 32)),
                  // Log In button — xanh lá đậm (#00D09E)
                  SizedBox(
                    width: Responsive.w(context, 207),
                    height: Responsive.h(context, 45),
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.signIn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepEmerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        AppStrings.choose('Log In', 'Đăng nhập'),
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 12)),
                  // Sign Up button — xanh lá nhạt (#DFF7E2)
                  SizedBox(
                    width: Responsive.w(context, 207),
                    height: Responsive.h(context, 45),
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.signUp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepEmerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        AppStrings.signUp,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: Responsive.h(context, 8),
              right: Responsive.w(context, 16),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HomeLanguageSelector(),
                  SizedBox(width: 8),
                  HomeThemeToggle(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16483E) : const Color(0xFF8FE1D7),
        shape: BoxShape.circle,
      ),
    );
  }
}
