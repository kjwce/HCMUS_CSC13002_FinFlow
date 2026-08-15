import 'package:finflow/features/finance/models/wallet_model.dart';
import 'package:finflow/features/notification_import/models/bank_notification_models.dart';
import 'package:finflow/features/notification_import/services/bank_notification_import_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const transferWallet = WalletModel(
    id: 'wallet-transfer',
    userId: 'user-1',
    name: 'Transfer',
    logoAssetPath: '',
    brandColor: Colors.blue,
    type: WalletType.transfer,
    initialBalance: 0,
  );
  final notification = BankNotificationEnvelope(
    id: 'notification-1',
    packageName: 'com.VCB',
    title: 'VCB Digibank',
    text: 'TK 123456789012 ghi no 600.000 VND',
    postedAt: DateTime(2026, 7, 29, 10, 30),
  );

  test('builds a reviewable transfer-wallet draft', () async {
    Map<String, dynamic>? request;
    final service = BankNotificationImportService.forTesting(
      wallets: () => const [transferWallet],
      invoker: (body) async {
        request = body;
        return {
          'success': true,
          'version': 1,
          'data': {
            'isTransaction': true,
            'type': 'expense',
            'amount': 600000,
            'name': 'Thanh toán QR',
            'categoryKey': 'Shopping',
            'date': '2026-07-29T10:30:00',
            'confidence': 0.96,
            'warnings': <String>[],
          },
        };
      },
    );

    final result = await service.parse(notification);

    expect(result.isTransaction, isTrue);
    expect(result.draft?.walletId, transferWallet.id);
    expect(result.draft?.amount, 600000);
    expect(result.draft?.canConfirm, isTrue);
    expect(request?['text'], contains('***9012'));
    expect(request?['text'], isNot(contains('123456789012')));
  });

  test('ignores a non-transaction response', () async {
    final service = BankNotificationImportService.forTesting(
      wallets: () => const [transferWallet],
      invoker: (_) async => {
        'success': true,
        'version': 1,
        'data': {'isTransaction': false},
      },
    );

    final result = await service.parse(notification);

    expect(result.isTransaction, isFalse);
    expect(result.draft, isNull);
  });

  test('rejects invalid amount instead of guessing', () async {
    final service = BankNotificationImportService.forTesting(
      wallets: () => const [transferWallet],
      invoker: (_) async => {
        'success': true,
        'version': 1,
        'data': {
          'isTransaction': true,
          'type': 'expense',
          'amount': -600000,
          'name': 'Payment',
          'categoryKey': 'Other',
          'date': null,
          'confidence': 0.9,
          'warnings': <String>[],
        },
      },
    );

    expect(
      () => service.parse(notification),
      throwsA(isA<BankNotificationImportException>()),
    );
  });
}
