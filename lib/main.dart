import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/shell/finflow_app.dart';
import 'core/i18n/app_language.dart';
import 'core/services/app_init_notifier.dart';
import 'core/theme/app_theme_manager.dart';
import 'features/auth/services/auth_service.dart';
import 'features/finance/services/goal_service.dart';
import 'features/finance/services/recurring_notification_action_coordinator.dart';
import 'features/finance/services/recurring_reminder_service.dart';
import 'features/finance/services/recurring_service.dart';
import 'features/finance/services/transaction_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Runs the app inside a guarded zone so that any unhandled Error thrown
/// from a Supabase SDK internal microtask is swallowed instead of
/// crashing the process.  All application errors are already caught at
/// their source, so anything reaching this handler is non-fatal.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppThemeManager.instance.init();
      await AppLanguage.instance.init();
      await RecurringReminderService.instance.initialize();
      RecurringReminderService.instance.bindActionHandler(
        (action) =>
            RecurringNotificationActionCoordinator.handle(action, navigatorKey),
      );

      // Render the FinFlow UI immediately — no waiting for network.
      runApp(const ProviderScope(child: FinFlowApp()));

      // Restore the persisted Supabase session before LaunchScreen decides
      // whether to open the dashboard or onboarding.
      unawaited(_initServices());
    },
    (Object error, StackTrace stack) {
      // Every error is already caught at source; this is a safety net for
      // Supabase SDK internal microtask errors. Log and continue.
      debugPrint('⚠️ [zone] $error');
    },
  );
}

Future<void> _initServices() async {
  try {
    await AuthService.instance.init();
    // Local session recovery is complete. LaunchScreen can route now while
    // the remaining network-backed services continue initializing.
    authInitNotifier.value = true;
    // Listen for password recovery events.
    Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      try {
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          navigatorKey.currentState?.pushNamed('/new-password');
        }
        if (authState.event == AuthChangeEvent.signedOut) {
          unawaited(RecurringReminderService.instance.cancelAllRecurring());
        } else if (authState.event == AuthChangeEvent.signedIn) {
          unawaited(_initRecurring());
        }
      } catch (_) {}
    });

    // Pre-fetch data if user already has a session.
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      unawaited(
        Future.wait([
          TransactionService.instance.fetchTransactions(),
          GoalService.instance.fetchGoals(),
          _initRecurring(),
        ]).catchError((Object error) {
          debugPrint('⚠️ Initial finance fetch failed (non-fatal): $error');
          return <void>[];
        }),
      );
    }
  } catch (e) {
    debugPrint('⚠️ Supabase init failed (non-fatal): $e');
    // App continues in "no backend" mode — sign-in will report the error.
  } finally {
    // LaunchScreen must not route until local auth recovery has completed
    // (or definitively failed).
    authInitNotifier.value = true;
  }
}

Future<void> _initRecurring() async {
  await RecurringService.instance.fetch();
  final reminders = RecurringReminderService.instance;
  final schedules = RecurringService.instance.schedules;
  final hasActiveSchedules = schedules.any((schedule) => schedule.isActive);
  // Never open an OS permission screen during startup or immediately after
  // sign-in. Missing permissions disable reminders silently; the user can
  // explicitly enable them later from Notification Settings.
  if (reminders.isEnabled &&
      hasActiveSchedules &&
      !await reminders.hasRequiredPermissions()) {
    await reminders.setEnabled(false);
    return;
  }
  await reminders.syncAll(schedules);
  await reminders.processPendingAction();
}
