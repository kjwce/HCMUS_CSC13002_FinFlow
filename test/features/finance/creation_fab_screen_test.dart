import 'package:finflow/features/budget/presentation/category_budgets_screen.dart';
import 'package:finflow/core/theme/app_colors.dart';
import 'package:finflow/features/finance/presentation/saving_goals_screen.dart';
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

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: screen)));
    await tester.pumpAndSettle();
  }

  testWidgets('savings goals uses a bottom-right create FAB', (tester) async {
    await pumpScreen(tester, const SavingGoalsScreen());

    final pageTitle = tester.widget<Text>(find.text('Savings Goals'));
    expect(pageTitle.style?.fontFamily, 'Manrope');
    expect(pageTitle.style?.fontWeight, FontWeight.w700);
    expect(pageTitle.style?.fontSize, closeTo(22 * 390 / 393, 0.01));
    expect(tester.getTopLeft(find.text('Savings Goals')).dx, lessThan(90));
    final finder = find.byKey(const Key('create-goal-fab'));
    expect(finder, findsOneWidget);
    expect(find.text('Create New Goal'), findsNothing);
    final rect = tester.getRect(finder);
    expect(rect.center.dx, greaterThan(300));
    expect(rect.center.dy, greaterThan(740));
    expect(tester.takeException(), isNull);
  });

  testWidgets('category budgets uses a bottom-right create FAB', (
    tester,
  ) async {
    await pumpScreen(tester, const CategoryBudgetsScreen());

    final pageTitle = tester.widget<Text>(find.text('Budget by Category'));
    expect(pageTitle.style?.fontFamily, 'Manrope');
    expect(pageTitle.style?.fontWeight, FontWeight.w700);
    expect(pageTitle.style?.fontSize, closeTo(22 * 390 / 393, 0.01));
    expect(tester.getTopLeft(find.text('Budget by Category')).dx, lessThan(90));
    final finder = find.byKey(const Key('add-category-budget-fab'));
    expect(finder, findsOneWidget);
    expect(find.text('Add Category Budget'), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.mintSoft,
    );
    final rect = tester.getRect(finder);
    expect(rect.center.dx, greaterThan(300));
    expect(rect.center.dy, greaterThan(740));
    expect(tester.takeException(), isNull);
  });
}
