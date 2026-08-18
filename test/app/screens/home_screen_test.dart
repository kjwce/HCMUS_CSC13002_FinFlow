import 'package:finflow/app/screens/home_screen.dart';
import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme_manager.dart';
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

  setUp(() {
    AppLanguage.instance.setLocale(AppLocale.english);
    AppThemeManager.instance.setMode(ThemeMode.light);
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SafeArea(child: HomeScreen())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders Stitch sections without overflow on a narrow phone', (
    tester,
  ) async {
    await pumpHome(tester, const Size(320, 568));

    expect(find.text('Savings Goals'), findsNothing);
    expect(find.text('Budget by Category'), findsNothing);
    for (final key in const [
      'overview-card-transactions',
      'overview-card-budget',
      'overview-card-goals',
      'overview-card-categories',
      'overview-card-recurring',
      'overview-card-insight',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(find.text('No upcoming payments'), findsOneWidget);
    expect(find.text('No spending yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the transaction section on a large phone', (
    tester,
  ) async {
    await pumpHome(tester, const Size(430, 932));
    await tester.ensureVisible(find.text('Recent Transactions'));
    await tester.pump();

    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps income and expense panels at the same height', (
    tester,
  ) async {
    await pumpHome(tester, const Size(430, 932));

    final income = tester.getSize(
      find.byKey(const Key('cash-flow-income-panel')),
    );
    final expense = tester.getSize(
      find.byKey(const Key('cash-flow-expense-panel')),
    );

    expect(income.height, expense.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers an all-time summary period', (tester) async {
    await pumpHome(tester, const Size(430, 932));

    await tester.tap(find.text('Monthly').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('All time'), findsOneWidget);
    expect(
      find.text('Current balance and all recorded transactions'),
      findsOneWidget,
    );

    await tester.tap(find.text('All time'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses prominent headers and aligned compact bottom cards', (
    tester,
  ) async {
    await pumpHome(tester, const Size(430, 932));

    final transactionsTitle = tester.widget<Text>(find.text('Transactions'));
    final recurring = tester.getSize(
      find.byKey(const Key('overview-card-recurring')),
    );
    final insight = tester.getSize(
      find.byKey(const Key('overview-card-insight')),
    );

    expect(transactionsTitle.style?.fontSize, 14);
    expect(transactionsTitle.style?.fontWeight, FontWeight.w800);
    expect(recurring.height, insight.height);
    expect(recurring.height, 280);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps goals and categories compact without an empty footer', (
    tester,
  ) async {
    await pumpHome(tester, const Size(430, 932));

    final goals = tester.getSize(find.byKey(const Key('overview-card-goals')));
    final categories = tester.getSize(
      find.byKey(const Key('overview-card-categories')),
    );

    expect(goals.height, categories.height);
    expect(goals.height, lessThanOrEqualTo(204));
    expect(tester.takeException(), isNull);
  });

  testWidgets('gives overview cards a prominent floating elevation', (
    tester,
  ) async {
    await pumpHome(tester, const Size(430, 932));

    final transactions = tester.widget<Material>(
      find.byKey(const Key('overview-card-transactions')),
    );

    expect(transactions.elevation, 6);
    expect(transactions.surfaceTintColor, Colors.transparent);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'data-driven Bento cards render in Vietnamese on a narrow phone',
    (tester) async {
      AppLanguage.instance.setLocale(AppLocale.vietnamese);
      await pumpHome(tester, const Size(320, 568));

      expect(find.byKey(const Key('overview-card-budget')), findsOneWidget);
      expect(find.byKey(const Key('overview-card-recurring')), findsOneWidget);
      expect(find.byKey(const Key('overview-card-insight')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
