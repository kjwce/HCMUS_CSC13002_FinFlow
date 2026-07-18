import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../finance/models/transaction_category.dart';
import '../models/scan_result_model.dart';

typedef ReceiptFunctionInvoker =
    Future<dynamic> Function(Map<String, dynamic> body);

class ReceiptScanException implements Exception {
  const ReceiptScanException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ReceiptScanException($code): $message';
}

/// Sends a receipt image to the authenticated Supabase Edge Function and
/// validates the structured Gemini response before the UI can display it.
class ReceiptScanService {
  ReceiptScanService._({ReceiptFunctionInvoker? invoker})
    : _invoker = invoker ?? _invokeFunction;

  static final ReceiptScanService instance = ReceiptScanService._();

  factory ReceiptScanService.forTesting({
    required ReceiptFunctionInvoker invoker,
  }) {
    return ReceiptScanService._(invoker: invoker);
  }

  static const _supportedVersion = 1;
  static const _maxImageBytes = 8 * 1024 * 1024;

  final ReceiptFunctionInvoker _invoker;

  Future<ScanResultModel> parseFile(
    XFile file, {
    List<TransactionCategory> categories = TransactionCategory.all,
  }) async {
    final bytes = await file.readAsBytes();
    return parseBytes(
      bytes,
      mimeType: _mimeTypeFor(file.path),
      categories: categories,
    );
  }

  Future<ScanResultModel> parseBytes(
    Uint8List bytes, {
    required String mimeType,
    List<TransactionCategory> categories = TransactionCategory.all,
  }) async {
    if (bytes.isEmpty) {
      throw const ReceiptScanException(
        'EMPTY_IMAGE',
        'Không tìm thấy dữ liệu ảnh hóa đơn.',
      );
    }
    if (bytes.length > _maxImageBytes) {
      throw const ReceiptScanException(
        'IMAGE_TOO_LARGE',
        'Ảnh hóa đơn quá lớn. Vui lòng chụp ảnh rõ hơn với kích thước nhỏ hơn.',
      );
    }

    final response = await _invoker({
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
      'locale': 'vi-VN',
      'categories': categories
          .map((category) => {'key': category.key, 'label': category.label})
          .toList(growable: false),
    });

    return _parseResponse(response);
  }

  ScanResultModel _parseResponse(dynamic response) {
    if (response is! Map || response['success'] != true) {
      throw const ReceiptScanException(
        'INVALID_SCAN_RESPONSE',
        'Dịch vụ quét hóa đơn trả về dữ liệu không hợp lệ.',
      );
    }
    if (response['version'] != _supportedVersion) {
      throw const ReceiptScanException(
        'UNSUPPORTED_SCAN_VERSION',
        'Phiên bản kết quả quét hóa đơn chưa được hỗ trợ.',
      );
    }

    final rawData = response['data'];
    if (rawData is! Map) {
      throw const ReceiptScanException(
        'INVALID_SCAN_RESPONSE',
        'Không đọc được dữ liệu từ hóa đơn.',
      );
    }

    final result = ScanResultModel.fromJson(Map<String, dynamic>.from(rawData));
    if (result.items.isEmpty) {
      throw const ReceiptScanException(
        'NO_ITEMS_FOUND',
        'Không tìm thấy món ăn hoặc dịch vụ nào trên hóa đơn.',
      );
    }
    if (result.items.any(
      (item) => item.name.trim().isEmpty || item.amount <= 0,
    )) {
      throw const ReceiptScanException(
        'INVALID_ITEM',
        'Một số dòng trên hóa đơn chưa có tên hoặc số tiền hợp lệ.',
      );
    }
    return result;
  }

  static Future<dynamic> _invokeFunction(Map<String, dynamic> body) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'parse-receipt',
        body: body,
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final errorData = details is Map && details['error'] is Map
          ? details['error'] as Map
          : null;
      final code = errorData?['code']?.toString();
      final message = errorData?['message']?.toString().trim();
      throw ReceiptScanException(
        code ?? 'RECEIPT_SCAN_UNAVAILABLE',
        message?.isNotEmpty == true
            ? message!
            : 'Dịch vụ quét hóa đơn hiện không khả dụng. Vui lòng thử lại.',
      );
    } catch (_) {
      throw const ReceiptScanException(
        'RECEIPT_SCAN_UNAVAILABLE',
        'Dịch vụ quét hóa đơn hiện không khả dụng. Vui lòng thử lại.',
      );
    }
  }

  static String _mimeTypeFor(String filePath) {
    switch (path.extension(filePath).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}

@visibleForTesting
String receiptMimeTypeForTesting(String filePath) {
  return ReceiptScanService._mimeTypeFor(filePath);
}
