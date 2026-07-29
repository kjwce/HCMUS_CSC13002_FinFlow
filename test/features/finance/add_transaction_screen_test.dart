import 'package:finflow/features/finance/presentation/add_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  Future<void> openManualMode(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add_mode_manual')));
    await tester.pump(const Duration(milliseconds: 190));
    await tester.pumpAndSettle();
  }

  Future<void> openMode(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 190));
    await tester.pump(const Duration(milliseconds: 230));
  }

  testWidgets('over-budget mood asset decodes successfully', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Image.asset('assets/images/over_budget_worried.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the dynamic Stitch mode picker on a narrow phone', (
    tester,
  ) async {
    await pumpAddScreen(tester, size: const Size(320, 568));

    expect(find.text('Add transaction'), findsOneWidget);
    expect(find.text('REMAINING BALANCE'), findsOneWidget);
    expect(find.text('MANUAL ENTRY'), findsOneWidget);
    expect(find.text('VOICE'), findsOneWidget);
    expect(find.text('SCAN'), findsOneWidget);
    expect(find.text('FAST'), findsOneWidget);
    expect(find.byKey(const Key('manual_amount_field')), findsNothing);
    for (final key in const [
      Key('add_mode_manual'),
      Key('add_mode_quick'),
      Key('add_mode_scan'),
    ]) {
      final card = tester.widget<AnimatedContainer>(find.byKey(key));
      expect((card.decoration! as BoxDecoration).color, Colors.white);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected method highlights before horizontal navigation', (
    tester,
  ) async {
    await pumpAddScreen(tester);

    await tester.tap(find.byKey(const Key('add_mode_quick')));
    await tester.pump(const Duration(milliseconds: 100));

    final selectedCard = tester.widget<AnimatedContainer>(
      find.byKey(const Key('add_mode_quick')),
    );
    expect(
      (selectedCard.decoration! as BoxDecoration).color,
      const Color(0xFF00513E),
    );
    expect(find.text('FAST'), findsOneWidget);
    expect(find.byKey(const Key('quick_add_text_field')), findsNothing);

    await tester.pump(const Duration(milliseconds: 90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_add_text_field')), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
  });

  testWidgets('expense selection uses the red amount accent', (tester) async {
    await pumpAddScreen(tester);
    await openManualMode(tester);

    expect(find.text('Manual Entry'), findsOneWidget);
    await tester.tap(find.text('New Expense'));
    await tester.pumpAndSettle();

    final amount = tester.widget<TextField>(
      find.byKey(const Key('manual_amount_field')),
    );
    expect(amount.style?.color, const Color(0xFFBA1A1A));
    expect(amount.decoration?.border, isA<UnderlineInputBorder>());
    expect(amount.decoration?.focusedBorder, isA<UnderlineInputBorder>());
    final name = tester.widget<TextField>(
      find.byKey(const Key('manual_name_field')),
    );
    expect(name.decoration?.border, isA<UnderlineInputBorder>());
    expect(name.decoration?.focusedBorder, isA<UnderlineInputBorder>());
  });

  testWidgets('category field opens the vertical selection modal', (
    tester,
  ) async {
    await pumpAddScreen(tester);
    await openManualMode(tester);

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
    await openManualMode(tester);

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

    await openMode(tester, const Key('add_mode_quick'));

    expect(find.text('Try "Lunch 50k" or tap\nmic'), findsOneWidget);
    expect(find.byKey(const Key('quick_add_text_field')), findsOneWidget);
    expect(find.byKey(const Key('quick_add_voice_button')), findsOneWidget);
    expect(find.text('Interpret & Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan mode embeds the receipt capture UI', (tester) async {
    await pumpAddScreen(tester, size: const Size(320, 568));

    await openMode(tester, const Key('add_mode_scan'));

    expect(find.text('Scan mode is coming soon'), findsNothing);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.byKey(const Key('scan_camera_button')), findsOneWidget);
    expect(find.byKey(const Key('scan_gallery_button')), findsOneWidget);
    expect(find.byKey(const Key('scan_animated_line')), findsOneWidget);
    expect(find.text('Analyze receipt'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
