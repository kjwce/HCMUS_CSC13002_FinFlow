import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/features/settings/presentation/notification_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues({});
    AppLanguage.instance.setLocale(AppLocale.english);
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
    AppLanguage.instance.setLocale(AppLocale.english);
  });

  testWidgets('shows the requested groups without savings plan alerts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const NotificationPreferencesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notification Preferences'), findsOneWidget);
    expect(find.text('SPENDING & BUDGETS'), findsOneWidget);
    expect(find.text("Approaching today's limit"), findsOneWidget);
    expect(find.text('Saving goal updates'), findsOneWidget);
    expect(find.text('Category budget alerts'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('RECURRING REMINDERS'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('COMMUNITY ACTIVITY'), findsOneWidget);
    expect(find.text('Likes on my content'), findsOneWidget);
    expect(find.textContaining('Savings Plan'), findsNothing);
    expect(find.textContaining('Goal allocation'), findsNothing);
    expect(find.textContaining('AI plan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a polished reminder timing dialog and updates selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const NotificationPreferencesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reminder timing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminder timing'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder-timing-dialog')), findsOneWidget);
    expect(find.text('Choose when FinFlow should remind you'), findsOneWidget);
    expect(find.byKey(const Key('reminder-timing-option-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-timing-option-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-timing-dialog')), findsNothing);
    expect(find.text('3 days before'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lets the user change a budget alert threshold', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const NotificationPreferencesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('90% threshold'));
    await tester.pumpAndSettle();
    expect(find.text('Alert threshold'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '80%'));
    await tester.pumpAndSettle();
    expect(find.text('80% threshold'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
