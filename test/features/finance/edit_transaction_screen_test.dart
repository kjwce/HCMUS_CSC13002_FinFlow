import 'package:finflow/features/finance/models/transaction_model.dart';
import 'package:finflow/features/finance/presentation/edit_transaction_screen.dart';
import 'package:finflow/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  tearDownAll(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('matches manual entry layout and keeps actions off the title', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EditTransactionScreen(
            transaction: TransactionModel(
              id: 'transaction-1',
              userId: 'user-1',
              name: 'Grab',
              category: 'Transport',
              amount: -150000,
              date: DateTime(2026, 9, 18),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Edit Transaction'), findsOneWidget);
    expect(find.text('PAYMENT METHOD'), findsOneWidget);
    expect(find.text('TRANSACTION DETAILS'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.byKey(const Key('edit_amount_field')), findsOneWidget);
    expect(find.byKey(const Key('edit_save_button')), findsOneWidget);

    final titleRect = tester.getRect(find.text('Edit Transaction'));
    final title = tester.widget<Text>(find.text('Edit Transaction'));
    final menuRect = tester.getRect(find.byIcon(Icons.more_horiz_rounded));
    expect(titleRect.left, lessThan(90));
    expect(title.style?.color, AppColors.deepEmerald);
    expect(title.style?.fontSize, closeTo(22, .1));
    expect(menuRect.center.dx, greaterThan(titleRect.center.dx + 100));
    expect(tester.takeException(), isNull);
  });
}
