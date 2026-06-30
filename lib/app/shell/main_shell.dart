import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/finance/presentation/add_transaction_sheet.dart';
import '../../features/scan/presentation/scan_screen.dart';
import '../screens/ai_screen.dart';
import '../screens/community_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import 'bottom_nav_bar.dart';
import 'finflow_app.dart';

/// MAIN SHELL — bottom nav with 5 tabs + center scan FAB
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  var _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read the tab index passed as route argument
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int && args >= 0 && args <= 4) {
      _index = args;
    }
    // Redirect new users (from social sign-in) to budget setup
    if (AuthService.instance.needsBudgetSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.budgetSetup);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(onAddTap: () => AddTransactionSheet.show(context)),
            const AiScreen(),
            const ScanScreen(),
            const CommunityScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _index,
        onTabChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
