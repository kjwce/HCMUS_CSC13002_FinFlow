import 'package:finflow/app/screens/home_screen.dart';
import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('formats compact overview money without regex replacement markers', () {
    expect(formatOverviewCompactMoney(4100000), '4.1M');
    expect(formatOverviewCompactMoney(1000000), '1M');
    expect(formatOverviewCompactMoney(450000), '450K');
  });

  test('matches each rolling seven-day date with its actual weekday', () {
    final friday = DateTime(2025, 8, 29);
    final days = List.generate(7, (index) => friday.add(Duration(days: index)));

    expect(
      days
          .map(
            (day) =>
                overviewCompactWeekdayLabel(day, locale: AppLocale.english),
          )
          .toList(),
      ['F', 'Sa', 'Su', 'M', 'T', 'W', 'T'],
    );
    expect(
      overviewCompactWeekdayLabel(friday, locale: AppLocale.vietnamese),
      'T6',
    );
  });

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

  Future<void> pumpHome(
    WidgetTester tester,
    Size size, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const Scaffold(body: SafeArea(child: HomeScreen())),
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

  testWidgets('uses the Stitch dark surfaces across the Home dashboard', (
    tester,
  ) async {
    await pumpHome(tester, const Size(430, 932), brightness: Brightness.dark);

    const expectedSurfaces = <String, Color>{
      'overview-card-transactions': Color(0xFF111A2C),
      'overview-card-budget': Color(0xFF241B11),
      'overview-card-goals': Color(0xFF1C162A),
      'overview-card-categories': Color(0xFF122421),
      'overview-card-recurring': Color(0xFF151726),
      'overview-card-insight': Color(0xFF102923),
    };
    for (final entry in expectedSurfaces.entries) {
      expect(
        tester.widget<Material>(find.byKey(Key(entry.key))).color,
        entry.value,
      );
    }

    final hero = tester.widget<Container>(
      find.byKey(const Key('home-balance-card')),
    );
    final decoration = hero.decoration! as BoxDecoration;
    expect((decoration.gradient! as LinearGradient).colors, const [
      Color(0xFF00513E),
      Color(0xFF00785D),
    ]);
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

  testWidgets('uses a large bold white total balance label', (tester) async {
    await pumpHome(tester, const Size(430, 932));

    final label = tester.widget<Text>(
      find.byKey(const Key('home-total-balance-label')),
    );
    expect(label.style?.fontSize, greaterThanOrEqualTo(18));
    expect(label.style?.fontWeight, FontWeight.w900);
    expect(label.style?.color, Colors.white);
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
    final budgetEyebrow = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('overview-card-budget')),
        matching: find.text('WEEKLY BUDGET'),
      ),
    );
    final budgetValue = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('overview-card-budget')),
        matching: find.text('No limit set'),
      ),
    );
    final recurring = tester.getSize(
      find.byKey(const Key('overview-card-recurring')),
    );
    final insight = tester.getSize(
      find.byKey(const Key('overview-card-insight')),
    );

    expect(transactionsTitle.style?.fontSize, 17);
    expect(transactionsTitle.style?.fontWeight, FontWeight.w800);
    expect(budgetEyebrow.style?.fontSize, 11);
    expect(budgetEyebrow.style?.fontWeight, FontWeight.w700);
    expect(budgetValue.style?.fontSize, 20);
    expect(recurring.height, insight.height);
    expect(recurring.height, 288);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses Phosphor SVG headers and an outlined Goals icon', (
    tester,
  ) async {
    await pumpHome(tester, const Size(430, 932));

    for (final title in const ['Budget', 'Categories', 'Insight']) {
      expect(find.byKey(Key('bento-header-icon-$title')), findsOneWidget);
    }
    expect(find.byType(SvgPicture), findsAtLeastNWidgets(3));
    expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(6));
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
    expect(goals.height, lessThanOrEqualTo(212));
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
