import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/shell/finflow_app.dart';
import 'features/auth/services/auth_service.dart';
import 'features/finance/services/goal_service.dart';
import 'features/finance/services/transaction_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase + AuthService (which handles auth state)
  await AuthService.instance.init();

  // Listen for password recovery event to navigate to new-password screen
  Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
    if (authState.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.pushNamed('/new-password');
    }
  });

  // Initial fetch of transactions if user already logged in
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    try {
      await TransactionService.instance.fetchTransactions();
      await GoalService.instance.fetchGoals();
    } catch (_) {
      // Silently fail — user may not have data yet
    }
  }

  runApp(
    const ProviderScope(
      child: FinFlowApp(),
    ),
  );
}
