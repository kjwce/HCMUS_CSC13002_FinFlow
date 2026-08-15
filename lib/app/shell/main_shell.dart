import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/chatbot/presentation/chat_screen.dart';
import '../../features/community/services/notification_service.dart';
import '../../features/finance/presentation/add_transaction_sheet.dart';
import '../../features/scan/presentation/scan_screen.dart';
import '../screens/community_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import 'bottom_nav_bar.dart';
import 'finflow_app.dart';

/// MAIN SHELL — bottom nav with four destinations + center add action.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  var _index = 0;
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read the tab index passed as route argument only once to avoid
    // re-triggering on every rebuild.
    if (!_argsRead) {
      _argsRead = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int && args >= 0 && args <= 4) {
        _index = args;
      }
      // Redirect new users (from social sign-in) to budget setup.
      // Only redirect when there is an authenticated user who hasn't set
      // a budget.  After logout (currentUser == null) this check must be
      // skipped, otherwise the user is sent to the budget screen instead
      // of the sign-in screen.
      final user = AuthService.instance.currentUser;
      if (user != null && user.budgetLimit <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.budgetSetup);
        });
      }
      // Init notification service for community features
      if (user != null) {
        NotificationService.instance.startForUser(user.id);
      }
    }
  }

  @override
  void dispose() {
    NotificationService.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF081C18)
          : context.finFlowColors.pageBackground,
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              isActive: _index == 0,
              onAddTap: () => AddTransactionSheet.show(context),
              onTabChanged: (i) => setState(() => _index = i),
            ),
            ChatScreen(showBackButton: false),
            ScanScreen(),
            CommunityScreen(),
            ProfileScreen(onTabChanged: (i) => setState(() => _index = i)),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _index,
        onTabChanged: (i) => setState(() => _index = i),
        onAddTap: () => AddTransactionSheet.show(context),
      ),
    );
  }
}
