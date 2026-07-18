import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_manager.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/new_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/verification_screen.dart';
import '../../features/budget/presentation/budget_setup_screen.dart';
import '../../features/chatbot/presentation/chat_screen.dart';
import '../screens/community_screen.dart';
import '../../features/finance/presentation/wallet_onboarding_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/community/presentation/notification_screen.dart';
import '../../features/debug/presentation/database_viewer_screen.dart';
import '../../features/launch/presentation/launch_screen.dart';
import '../../features/launch/presentation/onboarding_screen.dart';
import '../../features/scan/presentation/scan_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/budget_limits_screen.dart';
import '../../features/settings/presentation/security_screen.dart';
import 'main_shell.dart';
import '../../main.dart';

class AppRoutes {
  static const launch = '/';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const verification = '/verify';
  static const newPassword = '/new-password';
  static const dashboard = '/dashboard';
  static const settings = '/settings';
  static const budgetLimits = '/budget-limits';
  static const security = '/security';
  static const changePassword = '/change-password';
  static const chat = '/chat';
  static const scan = '/scan';
  static const community = '/community';
  static const databaseViewer = '/database-viewer';
  static const editProfile = '/edit-profile';
  static const budgetSetup = '/budget-setup';
  static const walletOnboarding = '/wallet-onboarding';
  static const notifications = '/notifications';
  static const communityPostDetail = '/community-post-detail';
}

class FinFlowApp extends StatelessWidget {
  const FinFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeManager.instance,
      builder: (context, _) {
        return MediaQuery(
          // Prevent the device's system font-size setting from breaking the layout.
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: MaterialApp(
            title: 'FinFlow',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: AppThemeManager.instance.mode,
            builder: (context, child) {
              final isDark = AppThemeManager.instance.isDark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor:
                      context.finFlowColors.navigationBackground,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                ),
                child: child!,
              );
            },
            initialRoute: AppRoutes.launch,
            routes: {
              AppRoutes.launch: (_) => const LaunchScreen(),
              AppRoutes.onboarding: (_) => const OnboardingScreen(),
              AppRoutes.signIn: (_) => const SignInScreen(),
              AppRoutes.signUp: (_) => const SignUpScreen(),
              AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
              AppRoutes.verification: (_) => const VerificationScreen(),
              AppRoutes.newPassword: (_) => const NewPasswordScreen(),
              AppRoutes.dashboard: (_) => const MainShell(),
              AppRoutes.settings: (_) => const SettingsScreen(),
              AppRoutes.budgetLimits: (_) => const BudgetLimitsScreen(),
              AppRoutes.security: (_) => const SecurityScreen(),
              AppRoutes.changePassword: (_) => const ChangePasswordScreen(),
              AppRoutes.chat: (_) => const ChatScreen(),
              AppRoutes.scan: (_) => const ScanScreen(),
              AppRoutes.community: (_) => const CommunityScreen(),
              AppRoutes.databaseViewer: (_) => const DatabaseViewerScreen(),
              AppRoutes.editProfile: (_) => const EditProfileScreen(),
              AppRoutes.budgetSetup: (_) => const BudgetSetupScreen(),
              AppRoutes.walletOnboarding: (_) => const WalletOnboardingScreen(),
              AppRoutes.notifications: (_) => const NotificationScreen(),
            },
          ),
        );
      },
    );
  }
}
