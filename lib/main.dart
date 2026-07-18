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

      // Signal LaunchScreen to navigate right away (animation delay only).
      authInitNotifier.value = true;

      // Initialise Supabase + auth in the background. If it fails
      // (e.g. project deleted, no internet) the app still works; auth
      // operations will surface the error to the user gracefully.
      _initServices();
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
      await TransactionService.instance.fetchTransactions();
      await GoalService.instance.fetchGoals();
    }
  } catch (e) {
    debugPrint('⚠️ Supabase init failed (non-fatal): $e');
    // App continues in "no backend" mode — sign-in will report the error.
  }
}
