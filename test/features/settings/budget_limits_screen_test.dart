import 'package:finflow/features/settings/presentation/budget_limits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses manual amount typography and renders weekly icon', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: BudgetLimitsScreen()));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(3));
    for (final field in fields) {
      expect(field.style?.fontFamily, 'Manrope');
      expect(field.style?.fontWeight, FontWeight.w700);
      expect(field.style?.fontSize, 44);
    }
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
