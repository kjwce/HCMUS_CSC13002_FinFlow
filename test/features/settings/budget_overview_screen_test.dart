import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/features/settings/presentation/budget_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens a focused edit dialog for an individual budget', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const BudgetOverviewScreen()),
    );
    await tester.pumpAndSettle();

    final pageTitle = tester.widget<Text>(find.text('Budgets'));
    expect(pageTitle.style?.fontFamily, 'Manrope');
    expect(pageTitle.style?.fontWeight, FontWeight.w700);
    expect(pageTitle.style?.fontSize, closeTo(22 * 390 / 393, 0.01));
    expect(tester.getTopLeft(find.text('Budgets')).dx, lessThan(90));
    expect(find.byKey(const Key('budget-overview-card-day')), findsOneWidget);
    expect(find.byKey(const Key('budget-overview-card-week')), findsOneWidget);
    expect(find.byKey(const Key('budget-overview-card-month')), findsOneWidget);
    final dailyCard = tester.widget<Container>(
      find.byKey(const Key('budget-overview-card-day')),
    );
    final dailyDecoration = dailyCard.decoration! as BoxDecoration;
    expect(dailyDecoration.border, isA<Border>());
    expect(dailyDecoration.boxShadow, hasLength(2));
    expect(dailyDecoration.boxShadow!.last.blurRadius, 18);
    await tester.tap(find.byKey(const Key('budget-overview-card-day')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-budget-dialog')), findsOneWidget);
    expect(find.text('Edit daily budget'), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('Current limit'), findsOneWidget);
    expect(find.byKey(const Key('edit-budget-amount-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('edit-budget-amount-field')),
      '12000000',
    );
    await tester.pumpAndSettle();

    expect(find.text('12,000,000'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-edited-budget')),
    );
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('close-edit-budget-dialog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-budget-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
