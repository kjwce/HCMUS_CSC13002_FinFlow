import 'package:finflow/features/finance/presentation/transaction_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  testWidgets('shows transaction search permanently below the header', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TransactionHistoryScreen())),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.widgetWithText(TextField, 'Search transactions'),
      findsOneWidget,
    );
    final periodLabel = tester.widget<Text>(find.text('Period'));
    final dailyLabel = tester.widget<Text>(find.text('Daily'));
    final typeLabel = tester.widget<Text>(find.text('Transaction Type'));
    final allLabel = tester.widget<Text>(find.text('All'));
    final sectionTitle = tester.widget<Text>(find.text('Transactions'));
    expect(periodLabel.style?.fontSize, closeTo(16 * 430 / 393, 0.01));
    expect(periodLabel.style?.fontWeight, FontWeight.w700);
    expect(dailyLabel.style?.fontSize, closeTo(13 * 430 / 393, 0.01));
    expect(typeLabel.style?.fontSize, closeTo(16 * 430 / 393, 0.01));
    expect(allLabel.style?.fontSize, closeTo(14 * 430 / 393, 0.01));
    expect(sectionTitle.style?.fontSize, closeTo(20 * 430 / 393, 0.01));
    expect(find.widgetWithIcon(IconButton, Icons.search_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
