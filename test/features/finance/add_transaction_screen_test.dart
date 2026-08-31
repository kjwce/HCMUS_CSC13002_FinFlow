import 'dart:typed_data';

import 'package:finflow/core/theme/app_colors.dart';
import 'package:finflow/features/scan/models/scan_result_model.dart';
import 'package:finflow/features/finance/presentation/add_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAddScreen(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    AddTransactionSheet screen = const AddTransactionSheet(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: screen)));
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
    expect(find.text('RECENT TRANSACTIONS'), findsOneWidget);
    expect(find.text('Tap to reuse'), findsOneWidget);
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

  testWidgets('uses larger high-contrast typography on the mode picker', (
    tester,
  ) async {
    await pumpAddScreen(tester);

    final header = tester.widget<Text>(find.text('Add transaction'));
    final prompt = tester.widget<Text>(
      find.text('What did you spend money on today?'),
    );
    final section = tester.widget<Text>(find.text('CHOOSE INPUT METHOD'));
    final habit = tester.widget<Text>(
      find.text("You're building a healthy money habit. Keep it up!"),
    );

    expect(header.style?.fontSize, 22);
    expect(header.style?.fontWeight, FontWeight.w700);
    expect(prompt.style?.fontSize, 15);
    expect(prompt.style?.fontWeight, FontWeight.w600);
    expect(section.style?.fontSize, 12.5);
    expect(section.style?.fontWeight, FontWeight.w800);
    expect(section.style?.color, const Color(0xFF30463E));
    expect(habit.style?.fontSize, 13);
    expect(habit.style?.fontWeight, FontWeight.w700);
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
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.byKey(const Key('quick_add_text_field')), findsOneWidget);
    expect(find.text('Add a Transaction by\nVoice'), findsOneWidget);
  });

  testWidgets('expense selection uses the red amount accent', (tester) async {
    await pumpAddScreen(tester);
    await openManualMode(tester);

    expect(find.text('Manual Entry'), findsOneWidget);
    final manualTitle = tester.widget<Text>(find.text('Manual Entry'));
    expect(tester.getTopLeft(find.text('Manual Entry')).dx, lessThan(90));
    expect(manualTitle.style?.color, AppColors.deepEmerald);
    expect(manualTitle.style?.fontSize, closeTo(22, .1));
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();

    final amount = tester.widget<TextField>(
      find.byKey(const Key('manual_amount_field')),
    );
    expect(amount.style?.color, const Color(0xFFBA1A1A));
    // The redesigned manual entry uses a borderless amount field.
    expect(amount.decoration?.border, isA<InputBorder>());
    final name = tester.widget<TextField>(
      find.byKey(const Key('manual_name_field')),
    );
    expect(name.decoration?.border, isNotNull);
  });

  testWidgets(
    'category field opens an anchored dropdown and applies directly',
    (tester) async {
      await pumpAddScreen(tester);
      await openManualMode(tester);

      await tester.tap(find.byKey(const Key('manual_category_field')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Salary'), findsWidgets);
      expect(find.text('Food'), findsNothing);
      expect(find.text('Apply Selection'), findsNothing);
      expect(
        find.byKey(const Key('manual_category_option_Bonus')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('manual_category_option_Bonus')));
      await tester.pumpAndSettle();

      expect(find.text('Bonus'), findsOneWidget);
      expect(
        find.byKey(const Key('manual_category_option_Bonus')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source field shows cash and transfer payment methods', (
    tester,
  ) async {
    await pumpAddScreen(tester);
    await openManualMode(tester);

    await tester.tap(find.byKey(const Key('manual_source_field')));
    await tester.pumpAndSettle();

    expect(find.text('Select Payment Method'), findsOneWidget);
    // 'PAYMENT METHOD' appears twice: the manual-entry section title and the
    // picker sheet section header.
    expect(find.text('PAYMENT METHOD'), findsNWidgets(2));
    expect(find.text('Cash'), findsWidgets);
    expect(find.text('Transfer'), findsWidgets);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick mode uses the synchronized natural language layout', (
    tester,
  ) async {
    await pumpAddScreen(tester);

    await openMode(tester, const Key('add_mode_quick'));

    expect(find.textContaining('Voice'), findsWidgets);
    expect(find.byKey(const Key('quick_add_text_field')), findsOneWidget);
    expect(find.byKey(const Key('quick_add_voice_button')), findsOneWidget);
    expect(find.textContaining('Interpret'), findsWidgets);
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
    expect(find.byKey(const Key('scan_flash_button')), findsNothing);
    expect(find.text('Analyze receipt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed receipt prefills an expense in manual entry', (
    tester,
  ) async {
    final imageFile = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
      name: 'receipt.jpg',
    );
    final receiptDate = DateTime(2026, 7, 28);
    final scanResult = ScanResultModel(
      merchantName: 'FinFlow Cafe',
      receiptDate: receiptDate,
      items: const [
        ScannedItem(name: 'Cà phê', amount: 50000, category: 'Food'),
        ScannedItem(name: 'Massage', amount: 100000, category: 'Service'),
      ],
      totalAmount: 160000,
    );
    await pumpAddScreen(
      tester,
      screen: AddTransactionSheet(
        scanImagePicker: (_) async => imageFile,
        scanReceiptParser: (_) async => scanResult,
      ),
    );
    await openMode(tester, const Key('add_mode_scan'));

    await tester.tap(find.byKey(const Key('scan_gallery_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('scan_analyze_button')));
    await tester.pumpAndSettle();

    expect(find.text('Continue with 160.000 VND'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('scan_confirm_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.text('Manual Entry'), findsOneWidget);
    final amountField = tester.widget<TextField>(
      find.byKey(const Key('manual_amount_field')),
    );
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('manual_name_field')),
    );
    expect(amountField.controller?.text, '160,000');
    expect(amountField.style?.color, const Color(0xFFBA1A1A));
    expect(nameField.controller?.text, 'FinFlow Cafe');
    expect(find.text('Service'), findsOneWidget);
    expect(find.text('07/28/2026'), findsOneWidget);
    expect(find.text('Save Transaction'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
