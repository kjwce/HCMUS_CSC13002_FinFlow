import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme_manager.dart';
import 'package:finflow/features/finance/presentation/recurring_screens.dart';
import 'package:finflow/features/finance/models/recurring_model.dart';
import 'package:finflow/features/finance/models/transaction_category.dart';
import 'package:finflow/features/finance/services/recurring_service.dart';
import 'package:finflow/core/widgets/finflow_action_icon.dart';
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

  Future<void> pumpHub(
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
          home: const RecurringControlCenterScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders the unified calendar hub and FAB on a narrow phone', (
    tester,
  ) async {
    await pumpHub(tester, const Size(320, 568));
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    final pageTitle = tester.widget<Text>(find.text('Recurring'));
    expect(pageTitle.style?.fontFamily, 'Manrope');
    expect(pageTitle.style?.fontWeight, FontWeight.w700);
    expect(pageTitle.style?.fontSize, closeTo(22 * 320 / 393, 0.01));
    expect(tester.getTopLeft(find.text('Recurring')).dx, lessThan(90));
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.byKey(const Key('recurring-upcoming-section')), findsOneWidget);
    expect(find.text('All schedules'), findsNothing);
    expect(find.byKey(const Key('recurring-previous-month')), findsOneWidget);
    expect(find.byKey(const Key('recurring-next-month')), findsOneWidget);
    final calendarCard = tester.widget<Container>(
      find.byKey(const Key('recurring-calendar-card')),
    );
    final calendarDecoration = calendarCard.decoration! as BoxDecoration;
    expect(calendarDecoration.color, Colors.white);
    expect(calendarDecoration.boxShadow, isNotEmpty);
    expect(calendarDecoration.boxShadow!.single.blurRadius, 24);
    expect(find.byKey(const Key('recurring-filter-button')), findsOneWidget);
    expect(find.byKey(const Key('recurring-add-fab')), findsOneWidget);
    final todayRing = tester.widget<Container>(
      find.byKey(Key('recurring-date-today-ring-$todayKey')),
    );
    final todayRingDecoration = todayRing.decoration! as BoxDecoration;
    expect(todayRingDecoration.border!.top.color, const Color(0xFFEF6262));
    expect(todayRingDecoration.boxShadow, isNotEmpty);
    final initialSelectionRing = tester.widget<Container>(
      find.byKey(Key('recurring-date-selected-ring-$todayKey')),
    );
    expect(
      (initialSelectionRing.decoration! as BoxDecoration).border!.top.color,
      const Color(0xFF006C53),
    );
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
      find.byKey(
        Key(
          'recurring-date-selected-ring-${occurrence.year}-${occurrence.month}-${occurrence.day}',
        ),
      ),
      findsOneWidget,
    );
    final today = DateTime.now();
    expect(
      find.byKey(
        Key(
          'recurring-date-today-ring-${today.year}-${today.month}-${today.day}',
        ),
      ),
      findsOneWidget,
    );
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
    final upcomingCard = tester.widget<Material>(
      find.byKey(const Key('recurring-upcoming-netflix')),
    );
    expect(upcomingCard.elevation, 4);
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

  testWidgets('popover opens above dates in the last three calendar rows', (
    tester,
  ) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final dayCount = DateTime(now.year, now.month + 1, 0).day;
    final rows = ((month.weekday - 1 + dayCount) / 7).ceil();
    final targetRow = rows - 3;
    final targetDay = List.generate(
      dayCount,
      (index) => index + 1,
    ).firstWhere((day) => (month.weekday - 1 + day - 1) ~/ 7 == targetRow);
    final occurrence = DateTime(now.year, now.month, targetDay);

    await pumpHub(tester, const Size(390, 844));
    RecurringService.instance.debugReplaceSchedules([
      RecurringSchedule(
        id: 'row-placement',
        userId: 'user-1',
        name: 'Row placement',
        category: 'Bills',
        amount: -300000,
        frequency: RecurringFrequency.monthly,
        nextOccurrence: occurrence,
        isActive: true,
        postingMode: RecurringPostingMode.review,
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

    final popover = tester.getRect(
      find.byKey(const Key('recurring-date-popover')),
    );
    final marker = tester.getRect(
      find.byKey(
        Key(
          'recurring-date-marker-${occurrence.year}-${occurrence.month}-${occurrence.day}',
        ),
      ),
    );
    expect(popover.bottom, lessThanOrEqualTo(marker.top));
    expect(find.byKey(const Key('recurring-popover-pointer')), findsOneWidget);
    final surface = tester.widget<Material>(
      find.byKey(const Key('recurring-popover-surface')),
    );
    expect(surface.color, const Color(0xFFE7F8F2));
    expect((surface.shape! as RoundedRectangleBorder).side, BorderSide.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('past dates keep their real labels and stale details advance', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final olderDate = today.subtract(const Duration(days: 2));
    final staleSchedule = RecurringSchedule(
      id: 'stale-daily',
      userId: 'user-1',
      name: 'Daily income',
      category: 'Service',
      amount: 150000,
      frequency: RecurringFrequency.daily,
      nextOccurrence: today.subtract(const Duration(days: 10)),
      isActive: true,
      postingMode: RecurringPostingMode.review,
    );

    await pumpHub(tester, const Size(390, 844));
    RecurringService.instance.debugReplaceSchedules([staleSchedule]);
    addTearDown(
      () => RecurringService.instance.debugReplaceSchedules(const []),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        Key(
          'recurring-date-${yesterday.year}-${yesterday.month}-${yesterday.day}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('recurring-occurrence-card-stale-daily')),
        matching: find.text('Yesterday'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        Key(
          'recurring-date-${olderDate.year}-${olderDate.month}-${olderDate.day}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    expect(
      find.text(
        '${months[olderDate.month - 1].toUpperCase()} ${olderDate.day}',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RecurringScheduleDetailsScreen(scheduleId: 'stale-daily'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final expectedNextDate =
        '${months[today.month - 1]} ${today.day}, ${today.year}';
    expect(find.text(expectedNextDate), findsWidgets);
    expect(find.text('Yesterday'), findsNothing);
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
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('e.g. Netflix'), findsOneWidget);
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

    expect(
      tester
          .widget<Text>(find.text('New Recurring Transaction'))
          .style
          ?.fontSize,
      22,
    );
    expect(
      tester.widget<Text>(find.text('Repeat Schedule')).style?.fontSize,
      18,
    );
    expect(
      tester.widget<Text>(find.text('Transaction Name')).style?.fontSize,
      12.5,
    );
    final transactionNameField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('recurring-name-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(transactionNameField.style?.fontSize, 14);

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

  testWidgets('details and occurrence review use readable typography', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final schedule = RecurringSchedule(
      id: 'readable-review',
      userId: 'user-1',
      name: 'Salary',
      category: 'Salary',
      amount: 150000,
      frequency: RecurringFrequency.daily,
      nextOccurrence: DateTime(2026, 8, 30),
      isActive: true,
      postingMode: RecurringPostingMode.review,
      reminderDays: 1,
    );
    RecurringService.instance.debugReplaceSchedules([schedule]);
    RecurringService.instance.debugReplaceOccurrenceHistory(schedule.id, [
      RecurringOccurrenceRecord(
        id: 'completed',
        scheduleId: schedule.id,
        occurrenceAt: DateTime(2026, 8, 29),
        status: RecurringOccurrenceStatus.completed,
        amount: 150000,
      ),
      RecurringOccurrenceRecord(
        id: 'skipped',
        scheduleId: schedule.id,
        occurrenceAt: DateTime(2026, 8, 28),
        status: RecurringOccurrenceStatus.skipped,
        amount: 150000,
      ),
      RecurringOccurrenceRecord(
        id: 'failed',
        scheduleId: schedule.id,
        occurrenceAt: DateTime(2026, 8, 27),
        status: RecurringOccurrenceStatus.failed,
        amount: 150000,
      ),
    ]);
    addTearDown(() {
      RecurringService.instance.debugReplaceSchedules(const []);
      RecurringService.instance.debugReplaceOccurrenceHistory(
        schedule.id,
        const [],
      );
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RecurringScheduleDetailsScreen(scheduleId: 'readable-review'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widget<Text>(find.text('Schedule')).style?.fontSize, 15);
    expect(
      tester.widget<Text>(find.text('Every day').first).style?.fontSize,
      15,
    );
    expect(tester.widget<Text>(find.text('Completed')).style?.fontSize, 13.5);
    expect(find.text('Skipped'), findsWidgets);
    expect(find.text('Failed'), findsWidgets);
    expect(find.text('1'), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('recurring-details-options-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Edit schedule'), findsOneWidget);
    expect(find.text('Pause schedule'), findsOneWidget);
    expect(find.text('Skip next occurrence'), findsOneWidget);
    expect(find.text('Delete schedule'), findsOneWidget);
    expect(find.byType(FinFlowPencilIcon), findsOneWidget);
    expect(find.byType(FinFlowPauseIcon), findsOneWidget);
    expect(find.byType(FinFlowSkipIcon), findsOneWidget);
    expect(find.byType(FinFlowTrashIcon), findsOneWidget);
    await tester.tapAt(const Offset(8, 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review occurrence'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Amount to receive')).style?.fontSize,
      14,
    );
    expect(tester.widget<Text>(find.text('DUE DATE')).style?.fontSize, 11.5);
    expect(
      tester.widget<Text>(find.text('Aug 30, 2026').last).style?.fontSize,
      14,
    );
    expect(
      tester.widget<Text>(find.text('Review required')).style?.fontSize,
      13.5,
    );
    final safeArea = tester.widget<SafeArea>(
      find.byWidgetPredicate(
        (widget) => widget is SafeArea && widget.minimum.bottom == 8,
      ),
    );
    expect(safeArea.top, isFalse);
    expect(safeArea.minimum.bottom, 8);
    expect(find.byKey(const Key('skip-recurring-occurrence')), findsOneWidget);
    await tester.tap(find.byKey(const Key('skip-recurring-occurrence')));
    await tester.pumpAndSettle();
    expect(find.text('Skip the Aug 30 occurrence?'), findsOneWidget);
    expect(
      find.text(
        'No transaction will be created. The next occurrence will be Aug 31.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('confirm-skip-recurring-occurrence')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies Stitch dark surfaces to all three recurring screens', (
    tester,
  ) async {
    await pumpHub(tester, const Size(390, 844), brightness: Brightness.dark);

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF081C18),
    );
    final calendar = tester.widget<Container>(
      find.byKey(const Key('recurring-calendar-card')),
    );
    final calendarDecoration = calendar.decoration! as BoxDecoration;
    expect(calendarDecoration.color, const Color(0xFF112622));
    expect(calendarDecoration.border!.top.color, const Color(0xFF29483F));
    expect(
      tester
          .widget<Container>(find.byKey(const Key('recurring-calendar-header')))
          .color,
      const Color(0xFF00513E),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          home: const NewRecurringScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF081C18),
    );
    final nameField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('recurring-name-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(nameField.decoration?.fillColor, const Color(0xFF0A241F));
    expect(tester.takeException(), isNull);

    final schedule = RecurringSchedule(
      id: 'dark-details',
      userId: 'user-1',
      name: 'Rent',
      category: 'Rent',
      amount: -5000000,
      frequency: RecurringFrequency.monthly,
      nextOccurrence: DateTime(2026, 8, 18),
      isActive: true,
      postingMode: RecurringPostingMode.review,
      reminderDays: 1,
    );
    RecurringService.instance.debugReplaceSchedules([schedule]);
    addTearDown(
      () => RecurringService.instance.debugReplaceSchedules(const []),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          home: const RecurringScheduleDetailsScreen(
            scheduleId: 'dark-details',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF081C18),
    );
    expect(
      tester.widget<Text>(find.text('Schedule Details')).style?.fontSize,
      closeTo(22 * 390 / 393, 0.01),
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('recurring-details-overview-card')),
              matching: find.text('Recurring expense'),
            ),
          )
          .style
          ?.fontSize,
      14.5,
    );
    final overview = tester.widget<Container>(
      find.byKey(const Key('recurring-details-overview-card')),
    );
    expect(
      (overview.decoration! as BoxDecoration).color,
      const Color(0xFF112622),
    );
    expect(tester.takeException(), isNull);
  });
}
