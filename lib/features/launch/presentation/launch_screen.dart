import 'package:flutter/material.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/services/app_init_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/finflow_logo.dart';
import '../../auth/services/auth_service.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();

    // Wait until Supabase has restored its persisted local session.
    authInitNotifier.addListener(_onReady);
    if (authInitNotifier.value) _onReady();
  }

  @override
  void dispose() {
    authInitNotifier.removeListener(_onReady);
    super.dispose();
  }

  void _onReady() {
    if (!mounted || !authInitNotifier.value || _navigationScheduled) return;
    _navigationScheduled = true;

    // Small delay so the logo animation shows, then navigate.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final destination = AuthService.instance.hasActiveSession
          ? AppRoutes.dashboard
          : AppRoutes.onboarding;
      Navigator.of(context).pushReplacementNamed(destination);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.emerald,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FinFlowLogo(
              foregroundColor: Colors.white,
              showText: false,
              size: Responsive.w(context, 109),
            ),
            SizedBox(height: Responsive.h(context, 16)),
            Text(
              'FinFlow',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: Responsive.sp(context, 52),
              ),
            ),
            SizedBox(height: Responsive.h(context, 16)),
            Text(
              AppStrings.choose(
                'Take Control of Your Finances\nwith Budget Genius',
                'Làm chủ tài chính của bạn\ncùng trợ lý ngân sách thông minh',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF4B4544),
                fontSize: Responsive.sp(context, 18),
                fontWeight: FontWeight.w400,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
