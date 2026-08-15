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
import 'features/finance/services/transaction_service.dart';
import 'features/notification_import/services/bank_notification_import_coordinator.dart';

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
    BankNotificationImportCoordinator.instance.start(navigatorKey);

    // Listen for password recovery events.
    Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      try {
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          navigatorKey.currentState?.pushNamed('/new-password');
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
