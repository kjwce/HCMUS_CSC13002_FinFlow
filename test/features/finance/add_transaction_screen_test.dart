import 'package:finflow/features/finance/presentation/add_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAddScreen(
    WidgetTester tester, {
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddTransactionSheet())),
    );
    await tester.pump();
  }

  testWidgets('renders the Stitch manual layout on a narrow phone', (
    tester,
  ) async {
    await pumpAddScreen(tester, size: const Size(320, 568));

    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.text('MANUAL'), findsOneWidget);
    expect(find.text('QUICK'), findsOneWidget);
    expect(find.text('SCAN'), findsOneWidget);
    expect(find.text('NEW INCOME'), findsOneWidget);
    expect(find.text('NEW EXPENSE'), findsOneWidget);
    expect(find.text('Save Transaction'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense selection uses the red amount accent', (tester) async {
    await pumpAddScreen(tester);

    await tester.tap(find.text('NEW EXPENSE'));
    await tester.pumpAndSettle();

    final amount = tester.widget<TextField>(
      find.byKey(const Key('manual_amount_field')),
    );
    expect(amount.style?.color, const Color(0xFFBA1A1A));
  });

  testWidgets('category field opens the vertical selection modal', (
    tester,
  ) async {
    await pumpAddScreen(tester);

    await tester.tap(find.byKey(const Key('manual_category_field')));
    await tester.pumpAndSettle();

    expect(find.text('Select Category'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Apply Selection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source field shows cash and transfer payment methods', (
    tester,
  ) async {
    await pumpAddScreen(tester);

    await tester.tap(find.byKey(const Key('manual_source_field')));
    await tester.pumpAndSettle();

    expect(find.text('Select Payment Method'), findsOneWidget);
    expect(find.text('PAYMENT METHOD'), findsOneWidget);
    expect(find.text('Tiền mặt'), findsOneWidget);
    expect(find.text('Chuyển khoản'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick mode uses the synchronized natural language layout', (
    tester,
  ) async {
    await pumpAddScreen(tester);

    await tester.tap(find.text('QUICK'));
    await tester.pumpAndSettle();

    expect(find.text('Try "Lunch 50k" or tap\nmic'), findsOneWidget);
    expect(find.byKey(const Key('quick_add_text_field')), findsOneWidget);
    expect(find.byKey(const Key('quick_add_voice_button')), findsOneWidget);
    expect(find.text('Interpret & Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan mode embeds the receipt capture UI', (tester) async {
    await pumpAddScreen(tester, size: const Size(320, 568));

    await tester.tap(find.text('SCAN'));
    await tester.pumpAndSettle();

    expect(find.text('Scan mode is coming soon'), findsNothing);
    expect(find.byKey(const Key('scan_camera_button')), findsOneWidget);
    expect(find.byKey(const Key('scan_gallery_button')), findsOneWidget);
    expect(find.text('Phân tích hóa đơn'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
