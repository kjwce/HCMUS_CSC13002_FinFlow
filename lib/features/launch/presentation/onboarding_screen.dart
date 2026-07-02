import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FFF3),
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative teal ellipses (like Figma "shape" instances)
            IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    right: Responsive.w(context, -44),
                    top: Responsive.h(context, -36),
                    child: _DecorativeCircle(size: Responsive.w(context, 200)),
                  ),
                  Positioned(
                    left: Responsive.w(context, -38),
                    bottom: Responsive.h(context, -32),
                    child: _DecorativeCircle(size: Responsive.w(context, 200)),
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
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: Responsive.sp(context, 52),
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
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: const Color(0xFF093030),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'Log In',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: Responsive.sp(context, 20),
                          fontWeight: FontWeight.w600,
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
                        backgroundColor: AppColors.lightGreen,
                        foregroundColor: const Color(0xFF0E3E3E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: Responsive.sp(context, 20),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 20)),
                  // Forgot Password link
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: Responsive.sp(context, 14),
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF093030),
                      ),
                    ),
                  ),
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
  const _DecorativeCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF8FE1D7),
        shape: BoxShape.circle,
      ),
    );
  }
}
