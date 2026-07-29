import 'dart:async';
import 'dart:typed_data';

import 'package:finflow/features/scan/models/scan_result_model.dart';
import 'package:finflow/features/scan/presentation/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  final imageFile = XFile.fromData(
    Uint8List.fromList([1, 2, 3]),
    mimeType: 'image/jpeg',
    name: 'receipt.jpg',
  );

  final scanResult = ScanResultModel(
    merchantName: 'FinFlow Cafe',
    receiptDate: DateTime(2020, 1, 2),
    currency: 'VND',
    items: const [
      ScannedItem(
        name: 'Cà phê',
        amount: 50000,
        category: 'Food',
        confidence: 0.96,
      ),
      ScannedItem(
        name: 'Massage',
        amount: 100000,
        category: 'Service',
        confidence: 0.91,
      ),
    ],
    totalAmount: 150000,
  );

  Future<void> pumpScanner(
    WidgetTester tester, {
    ReceiptImagePicker? imagePicker,
    ReceiptFileParser? receiptParser,
    Future<void> Function(ScanResultModel result)? onConfirmed,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScanScreen(
                embedded: true,
                imagePicker: imagePicker,
                receiptParser: receiptParser,
                onConfirmed: onConfirmed,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows camera and gallery capture actions', (tester) async {
    await pumpScanner(tester);

    expect(find.byKey(const Key('scan_image_preview')), findsOneWidget);
    expect(find.byKey(const Key('scan_camera_button')), findsOneWidget);
    expect(find.byKey(const Key('scan_gallery_button')), findsOneWidget);
    expect(find.byKey(const Key('scan_animated_line')), findsOneWidget);
    expect(find.byKey(const Key('scan_camera_overlay')), findsOneWidget);
    expect(find.byKey(const Key('scan_viewfinder')), findsOneWidget);
    expect(find.byKey(const Key('scan_flash_button')), findsNothing);
    expect(find.text('Place the receipt inside the frame'), findsOneWidget);
    expect(find.byKey(const Key('scan_analyze_button')), findsNothing);
    expect(find.text('Scan mode is coming soon'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves the green scanning line down the receipt frame', (
    tester,
  ) async {
    await pumpScanner(tester);

    final line = find.byKey(const Key('scan_animated_line'));
    final initialTop = tester.getTopLeft(line).dy;
    await tester.pump(const Duration(milliseconds: 1200));
    final movedTop = tester.getTopLeft(line).dy;

    expect(movedTop, greaterThan(initialTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'picks an image, shows FinFlow progress, and confirms the result',
    (tester) async {
      ImageSource? selectedSource;
      ScanResultModel? confirmedResult;
      final response = Completer<ScanResultModel>();
      await pumpScanner(
        tester,
        imagePicker: (source) async {
          selectedSource = source;
          return imageFile;
        },
        receiptParser: (_) => response.future,
        onConfirmed: (result) async => confirmedResult = result,
      );

      await tester.tap(find.byKey(const Key('scan_gallery_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(selectedSource, ImageSource.gallery);
      expect(find.byKey(const Key('scan_analyze_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('scan_analyze_button')));
      await tester.pump();

      expect(find.byKey(const Key('scan_processing_card')), findsOneWidget);
      expect(find.text('FinFlow đang phân tích hóa đơn...'), findsOneWidget);

      response.complete(scanResult);
      await tester.pumpAndSettle();

      expect(find.text('FinFlow Cafe'), findsOneWidget);
      expect(find.text('Cà phê'), findsOneWidget);
      expect(find.text('Massage'), findsOneWidget);
      expect(find.text('150.000 VND'), findsOneWidget);
      expect(find.text('02/01/2020'), findsOneWidget);
      expect(find.byKey(const Key('scan_total_card')), findsOneWidget);
      expect(find.byKey(const Key('scan_next_step_card')), findsOneWidget);
      expect(find.byKey(const Key('scan_confirm_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('scan_receipt_date_button')));
      await tester.pumpAndSettle();
      final datePicker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      final today = DateTime.now();
      expect(
        DateTime(
          datePicker.lastDate.year,
          datePicker.lastDate.month,
          datePicker.lastDate.day,
        ),
        DateTime(today.year, today.month, today.day),
      );
      final dialogButtons = find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextButton),
      );
      await tester.tap(dialogButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('scan_confirm_button')));
      await tester.pump();
      expect(confirmedResult, same(scanResult));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('allows a scanned item to be reviewed and edited', (
    tester,
  ) async {
    await pumpScanner(
      tester,
      imagePicker: (_) async => imageFile,
      receiptParser: (_) async => scanResult,
    );
    await tester.tap(find.byKey(const Key('scan_gallery_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('scan_analyze_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after receipt review');

    await tester.tap(find.byKey(const Key('scan_item_menu_0')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after item menu');
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after editor opens');

    await tester.enterText(
      find.byKey(const Key('scan_edit_name')),
      'Cà phê sữa',
    );
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'after editing item name');
    await tester.enterText(find.byKey(const Key('scan_edit_amount')), '55000');
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'after editing item amount');
    await tester.tap(find.byKey(const Key('scan_edit_save')));
    await tester.pumpAndSettle();

    expect(find.text('Cà phê sữa'), findsOneWidget);
    expect(find.text('55.000 VND'), findsOneWidget);
    expect(find.text('155.000 VND'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
