import 'package:finflow/features/finance/models/quick_add_draft_model.dart';
import 'package:finflow/features/finance/models/wallet_model.dart';
import 'package:finflow/features/finance/services/quick_add_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const momo = WalletModel(
    id: 'wallet-momo',
    userId: 'user-1',
    name: 'MoMo',
    shortName: 'MOMO',
    logoAssetPath: '',
    brandColor: Colors.pink,
    type: WalletType.ewallet,
    initialBalance: 0,
  );
  const mb = WalletModel(
    id: 'wallet-mb',
    userId: 'user-1',
    name: 'MB Bank',
    shortName: 'MB',
    logoAssetPath: '',
    brandColor: Colors.blue,
    type: WalletType.bank,
    initialBalance: 0,
  );
  const cash = WalletModel(
    id: 'wallet-cash',
    userId: 'user-1',
    name: 'Tiền mặt',
    shortName: 'CASH',
    logoAssetPath: '',
    brandColor: Colors.green,
    type: WalletType.cash,
    initialBalance: 0,
  );
  const inactive = WalletModel(
    id: 'wallet-inactive',
    userId: 'user-1',
    name: 'Old Wallet',
    shortName: 'OLD',
    logoAssetPath: '',
    brandColor: Colors.grey,
    type: WalletType.bank,
    initialBalance: 0,
    isActive: false,
  );

  Map<String, dynamic> response({
    dynamic type = 'expense',
    dynamic amount = 50000,
    dynamic name = 'Lunch',
    dynamic categoryKey = 'Food',
    dynamic walletName = 'MoMo',
    dynamic date = '2026-07-11T12:00:00',
    dynamic confidence = 0.95,
    dynamic warnings = const <String>[],
    dynamic version = 1,
  }) => {
    'success': true,
    'version': version,
    'data': {
      'type': type,
      'amount': amount,
      'name': name,
      'categoryKey': categoryKey,
      'walletName': walletName,
      'date': date,
      'confidence': confidence,
      'warnings': warnings,
    },
  };

  QuickAddService service(
    dynamic result, {
    List<WalletModel> wallets = const [momo, mb, cash, inactive],
    List<String> categories = const ['Food', 'Salary', 'Other'],
  }) => QuickAddService.forTesting(
    invoker: (_) async => result,
    wallets: () => wallets,
    categoryKeys: () => categories,
  );

  Future<QuickAddDraft> parse(
    dynamic result, {
    String text = 'Lunch 50k with MoMo',
    List<WalletModel> wallets = const [momo, mb, cash, inactive],
    List<String> categories = const ['Food', 'Salary', 'Other'],
  }) => service(
    result,
    wallets: wallets,
    categories: categories,
  ).parse(text, locale: 'en-US', now: DateTime(2026, 7, 12));

  group('provider response validation', () {
    test('valid expense response produces positive draft amount', () async {
      final draft = await parse(response());
      expect(draft.type, QuickAddTransactionType.expense);
      expect(draft.amount, 50000);
      expect(draft.categoryKey, 'Food');
      expect(draft.walletId, momo.id);
      expect(draft.canConfirm, isTrue);
    });

    test('valid income response retains Salary category', () async {
      final draft = await parse(
        response(type: 'income', name: 'Salary', categoryKey: 'Salary'),
      );
      expect(draft.type, QuickAddTransactionType.income);
      expect(draft.amount, 50000);
      expect(draft.categoryKey, 'Salary');
    });

    test('negative provider amount is rejected', () {
      expect(
        () => parse(response(amount: -50000)),
        throwsA(isA<QuickAddException>()),
      );
    });

    test('decimal provider amount is rejected', () {
      expect(
        () => parse(response(amount: 50.5)),
        throwsA(isA<QuickAddException>()),
      );
    });

    test('string provider amount is rejected', () {
      expect(
        () => parse(response(amount: '50000')),
        throwsA(isA<QuickAddException>()),
      );
    });

    test('missing amount is represented in draft', () async {
      final draft = await parse(response(amount: null));
      expect(draft.amount, isNull);
      expect(draft.missingFields, contains(QuickAddMissingField.amount));
    });

    test('missing transaction type is represented in draft', () async {
      final draft = await parse(response(type: null));
      expect(
        draft.missingFields,
        contains(QuickAddMissingField.transactionType),
      );
    });

    test('missing name is represented in draft', () async {
      final draft = await parse(response(name: null));
      expect(draft.missingFields, contains(QuickAddMissingField.name));
    });

    test('unsupported response version is rejected', () {
      expect(
        () => parse(response(version: 2)),
        throwsA(
          isA<QuickAddException>().having(
            (error) => error.code,
            'code',
            'UNSUPPORTED_VERSION',
          ),
        ),
      );
    });

    test('invalid response shape is rejected', () {
      expect(
        () => parse({'success': true, 'version': 1, 'data': 'invalid'}),
        throwsA(isA<QuickAddException>()),
      );
    });

    test('backend error exposes stable code but not raw message', () {
      expect(
        () => parse({
          'success': false,
          'version': 1,
          'error': {'code': 'GEMINI_UNAVAILABLE', 'message': 'provider secret'},
        }),
        throwsA(
          isA<QuickAddException>()
              .having((error) => error.code, 'code', 'GEMINI_UNAVAILABLE')
              .having(
                (error) => error.message,
                'message',
                isNot(contains('provider secret')),
              ),
        ),
      );
    });
  });

  group('local category, wallet, and date validation', () {
    test('invalid category falls back to Other and keeps name', () async {
      final draft = await parse(
        response(name: 'Cinema', categoryKey: 'Entertainment'),
      );
      expect(draft.categoryKey, 'Other');
      expect(draft.name, 'Cinema');
      expect(draft.warnings, isNotEmpty);
    });

    test('invalid category is missing when Other is unavailable', () async {
      final draft = await parse(
        response(categoryKey: 'Invalid'),
        categories: const ['Food', 'Salary'],
      );
      expect(draft.categoryKey, isNull);
      expect(draft.missingFields, contains(QuickAddMissingField.category));
    });

    test('wallet resolves by exact name', () async {
      final draft = await parse(response(walletName: 'MoMo'));
      expect(draft.walletId, momo.id);
      expect(draft.walletName, momo.name);
    });

    test('wallet resolves by short name', () async {
      final draft = await parse(response(walletName: 'MB'));
      expect(draft.walletId, mb.id);
      expect(draft.walletName, mb.name);
    });

    test('wallet resolves by common cash alias', () async {
      final draft = await parse(response(walletName: 'cash'));
      expect(draft.walletId, cash.id);
      expect(draft.walletName, cash.name);
    });

    test('inactive wallet cannot be resolved', () async {
      final draft = await parse(response(walletName: 'Old Wallet'));
      expect(draft.walletId, isNull);
      expect(draft.missingFields, contains(QuickAddMissingField.wallet));
    });

    test('unknown wallet preserves hint and adds warning', () async {
      final draft = await parse(response(walletName: 'Unknown Bank'));
      expect(draft.walletId, isNull);
      expect(draft.walletName, 'Unknown Bank');
      expect(draft.missingFields, contains(QuickAddMissingField.wallet));
      expect(draft.warnings, isNotEmpty);
    });

    test('no wallet mentioned defaults to the active cash wallet', () async {
      final draft = await parse(response(walletName: null));
      expect(draft.walletId, cash.id);
      expect(draft.walletName, cash.name);
      expect(draft.missingFields, isNot(contains(QuickAddMissingField.wallet)));
    });

    test(
      'missing wallet stays missing without an active cash wallet',
      () async {
        final draft = await parse(
          response(walletName: null),
          wallets: const [momo, mb, inactive],
        );
        expect(draft.walletId, isNull);
        expect(draft.walletName, isNull);
        expect(draft.missingFields, contains(QuickAddMissingField.wallet));
      },
    );

    test('valid ISO date is parsed', () async {
      final draft = await parse(response(date: '2026-07-10T12:30:00'));
      expect(draft.date, DateTime(2026, 7, 10, 12, 30));
    });

    test('invalid date becomes null with warning and is not missing', () async {
      final draft = await parse(response(date: 'not-a-date'));
      expect(draft.date, isNull);
      expect(draft.warnings, isNotEmpty);
      expect(draft.missingFields, isNot(contains(QuickAddMissingField.amount)));
    });

    test('null date remains null for form-compatible defaulting', () async {
      final draft = await parse(response(date: null));
      expect(draft.date, isNull);
      expect(draft.canConfirm, isTrue);
    });
  });

  group('transfer and conversion', () {
    test('unsupported transfer cannot be directly confirmed', () async {
      final draft = await parse(
        response(type: 'expense', walletName: 'MoMo'),
        text: 'Chuyển 500k từ MoMo sang MB',
      );
      expect(draft.type, isNull);
      expect(draft.canConfirm, isFalse);
      expect(
        draft.missingFields,
        contains(QuickAddMissingField.transactionType),
      );
      expect(draft.warnings, isNotEmpty);
    });

    test('income conversion produces positive amount', () async {
      final draft = await parse(response(type: 'income'));
      final transaction = draft.toTransactionModel(id: 't-1', userId: 'user-1');
      expect(transaction.amount, 50000);
    });

    test('expense conversion produces negative amount', () async {
      final draft = await parse(response(type: 'expense'));
      final transaction = draft.toTransactionModel(id: 't-1', userId: 'user-1');
      expect(transaction.amount, -50000);
    });

    test('conversion uses supplied default date', () async {
      final draft = await parse(response(date: null));
      final fallback = DateTime(2026, 7, 12, 8);
      final transaction = draft.toTransactionModel(
        id: 't-1',
        userId: 'user-1',
        defaultDate: fallback,
      );
      expect(transaction.date, fallback);
    });

    test('incomplete draft cannot convert', () async {
      final draft = await parse(response(amount: null));
      expect(
        () => draft.toTransactionModel(id: 't-1', userId: 'user-1'),
        throwsStateError,
      );
    });
  });

  test('request contains local context and active wallet payload', () async {
    Map<String, dynamic>? captured;
    final quickAdd = QuickAddService.forTesting(
      invoker: (body) async {
        captured = body;
        return response();
      },
      wallets: () => const [momo, inactive],
      categoryKeys: () => const ['Food', 'Other'],
    );
    await quickAdd.parse(
      'Lunch',
      locale: 'en-US',
      now: DateTime(2026, 7, 12, 9, 30),
    );
    expect(captured?['currentDate'], '2026-07-12');
    expect(captured?['locale'], 'en-US');
    expect((captured?['wallets'] as List), hasLength(1));
    expect((captured?['categories'] as List), hasLength(2));
  });
}
