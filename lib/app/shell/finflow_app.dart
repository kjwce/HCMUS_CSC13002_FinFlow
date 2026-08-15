import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/i18n/app_language.dart';
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
import '../../features/budget/presentation/category_budgets_screen.dart';
import '../../features/chatbot/presentation/chat_screen.dart';
import '../screens/community_screen.dart';
import '../../features/finance/presentation/wallet_onboarding_screen.dart';
import '../../features/finance/presentation/goal_details_screen.dart';
import '../../features/finance/presentation/goal_form_screen.dart';
import '../../features/finance/presentation/saving_goals_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/community/presentation/notification_screen.dart';
import '../../features/community/presentation/community_activity_screen.dart';
import '../../features/debug/presentation/database_viewer_screen.dart';
import '../../features/launch/presentation/launch_screen.dart';
import '../../features/launch/presentation/onboarding_screen.dart';
import '../../features/scan/presentation/scan_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/budget_limits_screen.dart';
import '../../features/settings/presentation/security_screen.dart';
import '../../features/notification_import/presentation/bank_notification_import_screen.dart';
import 'main_shell.dart';
import '../../main.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

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
  static const categoryBudgets = '/category-budgets';
  static const walletOnboarding = '/wallet-onboarding';
  static const notifications = '/notifications';
  static const communityPostDetail = '/community-post-detail';
  static const communityActivity = '/community-activity';
  static const bankNotificationImport = '/bank-notification-import';
  static const savingGoals = '/saving-goals';
  static const createGoal = '/saving-goals/create';
  static const goalDetails = '/saving-goals/details';
  static const editGoal = '/saving-goals/edit';
}

class FinFlowApp extends StatelessWidget {
  const FinFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppThemeManager.instance,
        AppLanguage.instance,
      ]),
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
            navigatorObservers: [appRouteObserver],
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: AppThemeManager.instance.mode,
            locale: Locale(AppLanguage.instance.locale.code),
            supportedLocales: const [Locale('en'), Locale('vi')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
              AppRoutes.launch: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => LaunchScreen()),
              AppRoutes.onboarding: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => OnboardingScreen()),
              AppRoutes.signIn: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => SignInScreen()),
              AppRoutes.signUp: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => SignUpScreen()),
              AppRoutes.forgotPassword: (_) => _LanguageAwarePage(
                pageBuilder: (_) => ForgotPasswordScreen(),
              ),
              AppRoutes.verification: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => VerificationScreen()),
              AppRoutes.newPassword: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => NewPasswordScreen()),
              AppRoutes.dashboard: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => MainShell()),
              AppRoutes.settings: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => SettingsScreen()),
              AppRoutes.budgetLimits: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => BudgetLimitsScreen()),
              AppRoutes.security: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => SecurityScreen()),
              AppRoutes.changePassword: (_) => _LanguageAwarePage(
                pageBuilder: (_) => ChangePasswordScreen(),
              ),
              AppRoutes.chat: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => ChatScreen()),
              AppRoutes.scan: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => ScanScreen()),
              AppRoutes.community: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => CommunityScreen()),
              AppRoutes.databaseViewer: (_) => _LanguageAwarePage(
                pageBuilder: (_) => DatabaseViewerScreen(),
              ),
              AppRoutes.editProfile: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => EditProfileScreen()),
              AppRoutes.budgetSetup: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => BudgetSetupScreen()),
              AppRoutes.categoryBudgets: (_) => _LanguageAwarePage(
                pageBuilder: (_) => CategoryBudgetsScreen(),
              ),
              AppRoutes.walletOnboarding: (_) => _LanguageAwarePage(
                pageBuilder: (_) => WalletOnboardingScreen(),
              ),
              AppRoutes.notifications: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => NotificationScreen()),
              AppRoutes.communityActivity: (_) => _LanguageAwarePage(
                pageBuilder: (_) => CommunityActivityScreen(),
              ),
              AppRoutes.bankNotificationImport: (_) => _LanguageAwarePage(
                pageBuilder: (_) => BankNotificationImportScreen(),
              ),
              AppRoutes.savingGoals: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => SavingGoalsScreen()),
              AppRoutes.createGoal: (_) =>
                  _LanguageAwarePage(pageBuilder: (_) => GoalFormScreen()),
            },
            onGenerateRoute: (settings) {
              final goalId = settings.arguments as String?;
              if (goalId == null) return null;
              return switch (settings.name) {
                AppRoutes.goalDetails => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => _LanguageAwarePage(
                    pageBuilder: (_) => GoalDetailsScreen(goalId: goalId),
                  ),
                ),
                AppRoutes.editGoal => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => _LanguageAwarePage(
                    pageBuilder: (_) => GoalFormScreen(goalId: goalId),
                  ),
                ),
                _ => null,
              };
            },
          ),
        );
      },
    );
  }
}

/// Rebuilds the current page when the app language changes while preserving
/// the page's State object, route stack, form values, and scroll positions.
class _LanguageAwarePage extends StatelessWidget {
  const _LanguageAwarePage({required this.pageBuilder});

  final WidgetBuilder pageBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) => pageBuilder(context),
    );
  }
}
