import 'dart:async';

import 'package:finflow/features/finance/models/quick_add_draft_model.dart';
import 'package:finflow/features/finance/presentation/add_transaction_sheet.dart';
import 'package:finflow/features/finance/presentation/quick_add_review_sheet.dart';
import 'package:finflow/features/finance/presentation/widgets/quick_add_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QuickAddDraft draft({
    QuickAddTransactionType? type = QuickAddTransactionType.expense,
    int? amount = 50000,
    String? name = 'Lunch',
    String? category = 'Food',
    String? walletId = 'wallet-momo',
    String? walletName = 'MoMo',
    DateTime? date,
    double confidence = 0.95,
    Set<QuickAddMissingField> missing = const {},
    List<String> warnings = const [],
    String originalText = 'Ăn trưa 50k bằng MoMo hôm qua',
  }) {
    return QuickAddDraft(
      originalText: originalText,
      type: type,
      amount: amount,
      name: name,
      categoryKey: category,
      walletId: walletId,
      walletName: walletName,
      date: date,
      confidence: confidence,
      missingFields: missing,
      warnings: warnings,
    );
  }

  Future<void> showReview(
    WidgetTester tester,
    QuickAddDraft value, {
    Future<void> Function()? onConfirm,
    ValueChanged<QuickAddReviewAction?>? onClosed,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await QuickAddReviewSheet.show(
                    context,
                    draft: value,
                    onConfirm: onConfirm ?? () async {},
                  );
                  onClosed?.call(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('Quick Add Stitch review binding', () {
    testWidgets('expense shows negative preview and enabled Confirm', (
      tester,
    ) async {
      await showReview(tester, draft());
      expect(find.text('-50,000 VND'), findsOneWidget);
      expect(find.text('EXPENSE'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('quick_add_confirm')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('income shows positive preview and enabled Confirm', (
      tester,
    ) async {
      await showReview(
        tester,
        draft(type: QuickAddTransactionType.income, category: 'Salary'),
      );
      expect(find.text('+50,000 VND'), findsOneWidget);
      expect(find.text('INCOME'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('quick_add_confirm')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('missing amount shows warning and disables Confirm', (
      tester,
    ) async {
      await showReview(
        tester,
        draft(
          amount: null,
          missing: const {QuickAddMissingField.amount},
          warnings: const ['The transaction amount could not be determined.'],
        ),
      );
      expect(find.text('Amount missing'), findsOneWidget);
      expect(
        find.text('The transaction amount could not be determined.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('quick_add_confirm')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('quick_add_edit_details')),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('missing type displays unknown and disables Confirm', (
      tester,
    ) async {
      await showReview(
        tester,
        draft(
          type: null,
          missing: const {QuickAddMissingField.transactionType},
        ),
      );
      expect(find.text('UNKNOWN'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('quick_add_confirm')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('missing wallet preserves parser hint and disables Confirm', (
      tester,
    ) async {
      await showReview(
        tester,
        draft(
          walletId: null,
          walletName: 'Unknown Wallet',
          missing: const {QuickAddMissingField.wallet},
          warnings: const ['Could not find the Unknown Wallet account.'],
        ),
      );
      expect(find.text('Unknown Wallet'), findsOneWidget);
      expect(
        find.text('Could not find the Unknown Wallet account.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('quick_add_confirm')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('Other fallback keeps transaction name and warning', (
      tester,
    ) async {
      await showReview(
        tester,
        draft(
          name: 'Cinema night',
          category: 'Other',
          warnings: const ['No matching category was found. Other was used.'],
        ),
      );
      expect(find.text('Cinema night'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(
        find.text('No matching category was found. Other was used.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'unsupported transfer warns, disables Confirm, and never saves',
      (tester) async {
        var saveCount = 0;
        await showReview(
          tester,
          draft(
            type: null,
            missing: const {QuickAddMissingField.transactionType},
            warnings: const [
              'Transfers between accounts are not supported yet.',
            ],
          ),
          onConfirm: () async => saveCount++,
        );
        expect(
          find.text('Transfers between accounts are not supported yet.'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('quick_add_confirm')));
        await tester.pump();
        expect(saveCount, 0);
      },
    );

    testWidgets('close review does not save', (tester) async {
      var saveCount = 0;
      await showReview(tester, draft(), onConfirm: () async => saveCount++);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(saveCount, 0);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('expense Confirm converts and invokes save exactly once', (
      tester,
    ) async {
      final value = draft();
      final pendingSave = Completer<void>();
      var saveCount = 0;
      var savedAmount = 0;
      await showReview(
        tester,
        value,
        onConfirm: () async {
          saveCount++;
          savedAmount = value
              .toTransactionModel(id: 't_1', userId: 'user-1')
              .amount;
          await pendingSave.future;
        },
      );
      await tester.tap(find.byKey(const Key('quick_add_confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick_add_confirm')));
      await tester.pump();
      expect(saveCount, 1);
      pendingSave.complete();
      await tester.pumpAndSettle();
      expect(saveCount, 1);
      expect(savedAmount, -50000);
    });

    testWidgets('income Confirm converts to positive amount', (tester) async {
      final value = draft(type: QuickAddTransactionType.income);
      var savedAmount = 0;
      await showReview(
        tester,
        value,
        onConfirm: () async {
          savedAmount = value
              .toTransactionModel(id: 't_1', userId: 'user-1')
              .amount;
        },
      );
      await tester.tap(find.byKey(const Key('quick_add_confirm')));
      await tester.pumpAndSettle();
      expect(savedAmount, 50000);
    });

    testWidgets('Confirm failure keeps review open and shows safe error', (
      tester,
    ) async {
      await showReview(
        tester,
        draft(),
        onConfirm: () async => throw Exception('secret provider detail'),
      );
      await tester.tap(find.byKey(const Key('quick_add_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Quick Add Result'), findsOneWidget);
      expect(
        find.text('Could not save the transaction. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('secret provider detail'), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('quick_add_confirm')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('Edit Details returns action without direct save', (
      tester,
    ) async {
      var saveCount = 0;
      QuickAddReviewAction? result;
      await showReview(
        tester,
        draft(),
        onConfirm: () async => saveCount++,
        onClosed: (value) => result = value,
      );
      await tester.tap(find.byKey(const Key('quick_add_edit_details')));
      await tester.pumpAndSettle();
      expect(result, QuickAddReviewAction.editDetails);
      expect(saveCount, 0);
    });
  });

  group('Quick Add input and Add Transaction reuse', () {
    testWidgets('loading Quick Add preserves text and disables both controls', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Lunch 50k');
      addTearDown(controller.dispose);
      var submitCount = 0;
      var voiceCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickAddCard(
              controller: controller,
              isLoading: true,
              onSubmit: (_) => submitCount++,
              onVoiceTap: () => voiceCount++,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('quick_add_submit_button')));
      await tester.tap(find.byKey(const Key('quick_add_voice_button')));
      expect(submitCount, 0);
      expect(voiceCount, 0);
      expect(controller.text, 'Lunch 50k');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('recording state shows stop control and disables submit', (
      tester,
    ) async {
      var voiceTaps = 0;
      var submitCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickAddCard(
              isRecording: true,
              onVoiceTap: () => voiceTaps++,
              onSubmit: (_) => submitCount++,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick_add_voice_button')));
      await tester.tap(find.byKey(const Key('quick_add_submit_button')));
      expect(voiceTaps, 1);
      expect(submitCount, 0);
    });

    testWidgets('transcribing state prevents duplicate microphone upload', (
      tester,
    ) async {
      var voiceTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickAddCard(
              isVoiceProcessing: true,
              onVoiceTap: () => voiceTaps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('quick_add_voice_button')));
      expect(voiceTaps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AddTransactionSheet prefills Quick Add values', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: _noTextScaling,
            home: Scaffold(
              body: AddTransactionSheet(
                initialIsExpense: true,
                initialAmount: 50000,
                initialName: 'Lunch',
                initialCategoryKey: 'Food',
                initialDate: DateTime(2025, 1, 2),
                fromQuickAdd: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('New expense'), findsOneWidget);
      expect(find.text('From Quick Add'), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller?.text, '50,000');
      expect(fields[1].controller?.text, 'Lunch');
    });

    testWidgets('user edits are not overwritten after Add sheet rebuild', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: _noTextScaling,
            home: Scaffold(
              body: const AddTransactionSheet(
                initialAmount: 50000,
                initialName: 'Initial name',
              ),
            ),
          ),
        ),
      );
      final nameField = find.byType(TextField).at(1);
      await tester.enterText(nameField, 'User edited name');
      await tester.pump();
      expect(
        tester.widget<TextField>(nameField).controller?.text,
        'User edited name',
      );
    });

    testWidgets('manual Add Transaction defaults remain unchanged', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: _noTextScaling,
            home: const Scaffold(body: AddTransactionSheet()),
          ),
        ),
      );
      expect(find.text('New income'), findsOneWidget);
      expect(find.text('From Quick Add'), findsNothing);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller?.text, isEmpty);
      expect(fields[1].controller?.text, isEmpty);
    });
  });
}

Widget _noTextScaling(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(size: const Size(393, 852), textScaler: TextScaler.noScaling),
    child: child!,
  );
}
