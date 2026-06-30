import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/finflow_logo.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      final route = isLoggedIn ? AppRoutes.dashboard : AppRoutes.onboarding;
      Navigator.of(context).pushReplacementNamed(route);
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
            FinFlowLogo(foregroundColor: Colors.white, showText: false, size: 109),
            const SizedBox(height: 16),
            Text(
              'FinFlow',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 52,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Take Control of Your Finances\nwith Budget Genius',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF4B4544),
                fontSize: 18,
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
