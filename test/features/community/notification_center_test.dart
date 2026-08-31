import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/core/widgets/in_app_notification_host.dart';
import 'package:finflow/features/community/models/notification_model.dart';
import 'package:finflow/features/community/presentation/notification_screen.dart';
import 'package:finflow/features/community/services/notification_service.dart';
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
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  setUp(() {
    AppLanguage.instance.setLocale(AppLocale.english);
    NotificationService.instance.debugReplaceNotifications(const []);
  });

  tearDown(() {
    AppLanguage.instance.setLocale(AppLocale.english);
    NotificationService.instance.debugReplaceNotifications(const []);
  });

  NotificationModel item({
    required String id,
    required NotificationCategory category,
    required String type,
    bool actionRequired = false,
  }) {
    return NotificationModel(
      id: id,
      userId: 'user-1',
      category: category,
      type: type,
      actionRequired: actionRequired,
      isRead: false,
      createdAt: DateTime.now(),
      title: type,
      body: 'Notification body',
      payload: const {'name': 'Netflix', 'amount': -260000},
    );
  }

  testWidgets('filters real feed items and localizes the center', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    NotificationService.instance.debugReplaceNotifications([
      item(
        id: 'recurring-1',
        category: NotificationCategory.recurring,
        type: 'recurring_review',
        actionRequired: true,
      ),
      item(
        id: 'budget-1',
        category: NotificationCategory.budget,
        type: 'budget_threshold',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Needs action'), findsWidgets);
    expect(find.text('Recurring'), findsOneWidget);

    await tester.tap(find.text('Needs action').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirm recurring transaction'), findsOneWidget);
    expect(find.textContaining('near its limit'), findsNothing);

    AppLanguage.instance.setLocale(AppLocale.vietnamese);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Định kỳ'), findsOneWidget);
  });

  testWidgets('shows a compact floating notification above current content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: InAppNotificationHost(
          navigatorKey: navigatorKey,
          child: const Scaffold(body: Center(child: Text('Dashboard body'))),
        ),
      ),
    );

    NotificationService.instance.debugEmit(
      item(
        id: 'floating-1',
        category: NotificationCategory.recurring,
        type: 'recurring_review',
        actionRequired: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Dashboard body'), findsOneWidget);
    expect(find.text('Confirm recurring transaction'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe reveals delete action without removing notification', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    NotificationService.instance.debugReplaceNotifications([
      item(
        id: 'swipe-1',
        category: NotificationCategory.recurring,
        type: 'recurring_review',
        actionRequired: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('notification-swipe-1'));
    await tester.drag(card, const Offset(-110, 0));
    await tester.pumpAndSettle();

    final animatedCard = tester.widget<AnimatedContainer>(
      find.descendant(of: card, matching: find.byType(AnimatedContainer)).first,
    );
    expect(animatedCard.transform?.storage[12], -78);
    expect(NotificationService.instance.notifications, hasLength(1));
    expect(find.text('Confirm recurring transaction'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
