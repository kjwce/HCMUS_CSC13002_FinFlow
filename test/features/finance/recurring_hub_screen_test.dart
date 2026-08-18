import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme_manager.dart';
import 'package:finflow/features/finance/presentation/recurring_screens.dart';
import 'package:finflow/features/finance/models/recurring_model.dart';
import 'package:finflow/features/finance/models/transaction_category.dart';
import 'package:finflow/features/finance/services/recurring_service.dart';
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

  Future<void> pumpHub(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RecurringControlCenterScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders the unified calendar hub and FAB on a narrow phone', (
    tester,
  ) async {
    await pumpHub(tester, const Size(320, 568));

    expect(find.text('Overview'), findsNothing);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.byKey(const Key('recurring-upcoming-section')), findsOneWidget);
    expect(find.text('All schedules'), findsNothing);
    expect(find.byKey(const Key('recurring-previous-month')), findsOneWidget);
    expect(find.byKey(const Key('recurring-next-month')), findsOneWidget);
    expect(find.byKey(const Key('recurring-filter-button')), findsOneWidget);
    expect(find.byKey(const Key('recurring-add-fab')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('recurring-filter-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recurring-filter-dialog')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.byKey(const Key('recurring-filter-expense')));
    await tester.tap(find.byKey(const Key('recurring-filter-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recurring-filter-dialog')), findsNothing);
    expect(find.byKey(const Key('recurring-filter-badge')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('recurring-next-month')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recurring-add-fab')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar uses real occurrences and opens an anchored popover', (
    tester,
  ) async {
    await pumpHub(tester, const Size(390, 844));
    final now = DateTime.now();
    final occurrence = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    RecurringService.instance.debugReplaceSchedules([
      RecurringSchedule(
        id: 'netflix',
        userId: 'user-1',
        name: 'Netflix',
        category: 'Entertainment',
        amount: -300000,
        frequency: RecurringFrequency.weekly,
        nextOccurrence: occurrence,
        isActive: true,
        postingMode: RecurringPostingMode.review,
      ),
      RecurringSchedule(
        id: 'salary',
        userId: 'user-1',
        name: 'Salary',
        category: 'Salary',
        amount: 2000000,
        frequency: RecurringFrequency.monthly,
        nextOccurrence: occurrence.add(const Duration(days: 1)),
        isActive: true,
        postingMode: RecurringPostingMode.automatic,
      ),
    ]);
    addTearDown(
      () => RecurringService.instance.debugReplaceSchedules(const []),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        Key(
          'recurring-date-${occurrence.year}-${occurrence.month}-${occurrence.day}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recurring-date-popover')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('recurring-date-popover')),
        matching: find.text('Netflix'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recurring-upcoming-netflix')), findsOneWidget);
    final expectedCategoryColor = TransactionCategory.resolve(
      'Entertainment',
    ).color;
    final upcomingIcon = tester.widget<Container>(
      find.byKey(const Key('recurring-upcoming-icon-netflix')),
    );
    expect(
      (upcomingIcon.decoration! as BoxDecoration).color,
      expectedCategoryColor.withValues(alpha: .12),
    );
    final dateMarker = tester.widget<Container>(
      find.byKey(
        Key(
          'recurring-date-marker-${occurrence.year}-${occurrence.month}-${occurrence.day}',
        ),
      ),
    );
    expect(
      (dateMarker.decoration! as BoxDecoration).color,
      expectedCategoryColor,
    );
    final firstUpcoming = tester.getRect(
      find.byKey(const Key('recurring-upcoming-netflix')),
    );
    final secondUpcoming = tester.getRect(
      find.byKey(const Key('recurring-upcoming-salary')),
    );
    expect(firstUpcoming.width, closeTo(260, 1));
    expect(secondUpcoming.left, lessThan(390));
    expect(secondUpcoming.right, greaterThan(390));
    expect(
      find.descendant(
        of: find.byKey(const Key('recurring-date-popover')),
        matching: find.text('-300,000 VND'),
      ),
      findsOneWidget,
    );
    final popoverRect = tester.getRect(
      find.byKey(const Key('recurring-date-popover')),
    );
    final occurrenceCardRect = tester.getRect(
      find.byKey(const Key('recurring-occurrence-card-netflix')),
    );
    expect(occurrenceCardRect.top, greaterThanOrEqualTo(popoverRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly form derives its repeat day from first occurrence', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NewRecurringScreen())),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('First occurrence'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Day of month'), findsNothing);
    expect(find.text('Use last day of month'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refined form keeps fields aligned and uses anchored pickers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NewRecurringScreen())),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final category = find.byKey(const Key('recurring-category-field'));
    final name = find.byKey(const Key('recurring-name-field'));
    final amount = find.byKey(const Key('recurring-amount-field'));
    final wallet = find.byKey(const Key('recurring-wallet-field'));
    final fieldWidths = [
      category,
      name,
      amount,
      wallet,
    ].map((finder) => tester.getSize(finder).width).toList();

    expect(
      tester.getTopLeft(category).dy,
      lessThan(tester.getTopLeft(name).dy),
    );
    expect(tester.getTopLeft(name).dy, lessThan(tester.getTopLeft(amount).dy));
    expect(
      tester.getTopLeft(amount).dy,
      lessThan(tester.getTopLeft(wallet).dy),
    );
    for (final width in fieldWidths.skip(1)) {
      expect(width, closeTo(fieldWidths.first, 0.1));
    }

    final expense = tester.widget<AnimatedContainer>(
      find.byKey(const Key('recurring-expense-segment')),
    );
    expect(
      (expense.decoration! as BoxDecoration).color,
      const Color(0xFFDA514F),
    );
    await tester.tap(find.byKey(const Key('recurring-income-segment')));
    await tester.pumpAndSettle();
    final income = tester.widget<AnimatedContainer>(
      find.byKey(const Key('recurring-income-segment')),
    );
    expect(
      (income.decoration! as BoxDecoration).color,
      const Color(0xFF006C53),
    );

    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
