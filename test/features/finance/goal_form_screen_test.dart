import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/features/finance/presentation/goal_form_screen.dart';
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

  testWidgets('uses an anchored category menu and aligned input heights', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const GoalFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View all categories'), findsNothing);
    expect(find.text('Choose Category'), findsNothing);

    final fieldHeights = <String, double>{
      for (final key in const [
        'goal-category-field',
        'goal-name-field',
        'goal-target-amount-field',
        'goal-target-date-field',
        'goal-initial-allocation-field',
      ])
        key: tester.getSize(find.byKey(Key(key))).height,
    };
    expect(
      fieldHeights.values,
      everyElement(closeTo(fieldHeights.values.first, 0.1)),
      reason: '$fieldHeights',
    );

    await tester.tap(find.byKey(const Key('goal-category-field')));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.ensureVisible(find.text('Technology').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Technology').last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('goal-category-field')),
        matching: find.text('Technology'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
