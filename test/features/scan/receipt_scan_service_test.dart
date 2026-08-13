import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:finflow/features/scan/services/receipt_scan_service.dart';

void main() {
  Map<String, dynamic> validResponse({
    dynamic items = const [
      {
        'name': 'Phở',
        'amount': 50000,
        'categoryKey': 'Food',
        'confidence': 0.95,
        'warning': null,
      },
      {
        'name': 'Massage',
        'amount': 100000,
        'categoryKey': 'Service',
        'confidence': 0.9,
        'warning': null,
      },
    ],
    bool success = true,
    int version = 1,
    dynamic data,
  }) => {
    'success': success,
    'version': version,
    'data':
        data ??
        {
          'merchantName': 'FinFlow Test Receipt',
          'receiptDate': '2026-07-16',
          'currency': 'VND',
          'items': items,
          'totalAmount': 150000,
          'warnings': <String>[],
        },
  };

  test('parses a Vietnamese and English receipt response', () async {
    Map<String, dynamic>? request;
    final service = ReceiptScanService.forTesting(
      invoker: (body) async {
        request = body;
        return validResponse();
      },
    );

    final result = await service.parseBytes(
      Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
    );

    expect(result.items, hasLength(2));
    expect(result.items.first.name, 'Phở');
    expect(result.items.last.category, 'Service');
    expect(result.calculatedTotal, 150000);
    expect(result.merchantName, 'FinFlow Test Receipt');
    expect(result.receiptDate, DateTime(2026, 7, 16));
    expect(request?['mimeType'], 'image/jpeg');
    expect(request?['imageBase64'], 'AQID');
    expect(request?['locale'], 'en-US');
    final categories = request?['categories'] as List<dynamic>;
    expect(
      categories.any(
        (category) =>
            category is Map &&
            category['key'] == 'Service' &&
            category['label'] == 'Service',
      ),
      isTrue,
    );
  });

  test('rejects empty image data before invoking Supabase', () async {
    var invoked = false;
    final service = ReceiptScanService.forTesting(
      invoker: (_) async {
        invoked = true;
        return validResponse();
      },
    );

    await expectLater(
      service.parseBytes(Uint8List(0), mimeType: 'image/png'),
      throwsA(
        isA<ReceiptScanException>().having(
          (error) => error.code,
          'code',
          'EMPTY_IMAGE',
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test('rejects images larger than 8 MB before invoking Supabase', () async {
    var invoked = false;
    final service = ReceiptScanService.forTesting(
      invoker: (_) async {
        invoked = true;
        return validResponse();
      },
    );

    await expectLater(
      service.parseBytes(
        Uint8List(8 * 1024 * 1024 + 1),
        mimeType: 'image/jpeg',
      ),
      throwsA(
        isA<ReceiptScanException>().having(
          (error) => error.code,
          'code',
          'IMAGE_TOO_LARGE',
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test('rejects an unsuccessful or malformed response', () async {
    final service = ReceiptScanService.forTesting(
      invoker: (_) async => {'success': false, 'version': 1},
    );

    await expectLater(
      service.parseBytes(Uint8List.fromList([1]), mimeType: 'image/png'),
      throwsA(
        isA<ReceiptScanException>().having(
          (error) => error.code,
          'code',
          'INVALID_SCAN_RESPONSE',
        ),
      ),
    );
  });

  test('rejects an unsupported response version', () async {
    final service = ReceiptScanService.forTesting(
      invoker: (_) async => validResponse(version: 2),
    );

    await expectLater(
      service.parseBytes(Uint8List.fromList([1]), mimeType: 'image/png'),
      throwsA(
        isA<ReceiptScanException>().having(
          (error) => error.code,
          'code',
          'UNSUPPORTED_SCAN_VERSION',
        ),
      ),
    );
  });

  test('rejects a response without receipt data', () async {
    final service = ReceiptScanService.forTesting(
      invoker: (_) async => validResponse(data: 'not-a-map'),
    );

    await expectLater(
      service.parseBytes(Uint8List.fromList([1]), mimeType: 'image/png'),
      throwsA(
        isA<ReceiptScanException>().having(
          (error) => error.code,
          'code',
          'INVALID_SCAN_RESPONSE',
        ),
      ),
    );
  });

  test('rejects an empty item list', () async {
    final service = ReceiptScanService.forTesting(
      invoker: (_) async => validResponse(items: const []),
    );

    await expectLater(
      service.parseBytes(Uint8List.fromList([1]), mimeType: 'image/png'),
      throwsA(
        isA<ReceiptScanException>().having(
          (error) => error.code,
          'code',
          'NO_ITEMS_FOUND',
        ),
      ),
    );
  });

  test('rejects a receipt item without a valid name or amount', () async {
    final service = ReceiptScanService.forTesting(
      invoker: (_) async => validResponse(
        items: const [
          {'name': '', 'amount': 0, 'categoryKey': 'Other', 'confidence': 0},
        ],
      ),
    );

    await expectLater(
      service.parseBytes(Uint8List.fromList([1]), mimeType: 'image/png'),
      throwsA(
        isA<ReceiptScanException>().having(
          (error) => error.code,
          'code',
          'INVALID_ITEM',
        ),
      ),
    );
  });

  test('detects supported image mime types', () {
    expect(receiptMimeTypeForTesting('receipt.JPG'), 'image/jpeg');
    expect(receiptMimeTypeForTesting('receipt.png'), 'image/png');
    expect(receiptMimeTypeForTesting('receipt.webp'), 'image/webp');
    expect(receiptMimeTypeForTesting('receipt.heic'), 'image/heic');
    expect(receiptMimeTypeForTesting('receipt.heif'), 'image/heif');
    expect(receiptMimeTypeForTesting('receipt.unknown'), 'image/jpeg');
  });
}
