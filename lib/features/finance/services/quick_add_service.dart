import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/app_language.dart';
import '../models/quick_add_draft_model.dart';
import '../models/transaction_category.dart';
import '../models/wallet_model.dart';
import 'wallet_service.dart';

typedef QuickAddFunctionInvoker =
    Future<dynamic> Function(Map<String, dynamic> body);
typedef QuickAddWalletRefresher = Future<void> Function();

class QuickAddException implements Exception {
  const QuickAddException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'QuickAddException($code): $message';
}

/// Calls the parser and turns its untrusted response into a locally validated
/// [QuickAddDraft]. It never saves or navigates.
class QuickAddService {
  QuickAddService._({
    QuickAddFunctionInvoker? invoker,
    List<WalletModel> Function()? wallets,
    List<String> Function()? categoryKeys,
    QuickAddWalletRefresher? refreshWallets,
  }) : _invoker = invoker ?? _invokeFunction,
       _wallets = wallets ?? _activeCurrentUserWallets,
       _categoryKeys = categoryKeys ?? _availableCategoryKeys,
       _refreshWallets = refreshWallets ?? _refreshProductionWallets;

  static final QuickAddService instance = QuickAddService._();

  /// Test-only dependency boundary. Production callers should use [instance].
  factory QuickAddService.forTesting({
    required QuickAddFunctionInvoker invoker,
    required List<WalletModel> Function() wallets,
    List<String> Function()? categoryKeys,
    QuickAddWalletRefresher? refreshWallets,
  }) {
    return QuickAddService._(
      invoker: invoker,
      wallets: wallets,
      categoryKeys: categoryKeys,
      refreshWallets: refreshWallets ?? () async {},
    );
  }

  static const _supportedVersion = 1;
  final QuickAddFunctionInvoker _invoker;
  final List<WalletModel> Function() _wallets;
  final List<String> Function() _categoryKeys;
  final QuickAddWalletRefresher _refreshWallets;

  Future<QuickAddDraft> parse(
    String text, {
    String? locale,
    DateTime? now,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const QuickAddException(
        'INVALID_INPUT',
        'Input must not be empty.',
      );
    }

    final localNow = now ?? DateTime.now();
    final requestLocale = locale ?? _currentLocale;
    var wallets = _wallets().where((wallet) => wallet.isActive).toList();
    if (wallets.isEmpty) {
      try {
        await _refreshWallets();
      } catch (_) {
        // Wallet context improves matching, but must not prevent the Edge
        // Function request. The review screen can collect a missing wallet.
      }
      wallets = _wallets().where((wallet) => wallet.isActive).toList();
    }
    final categoryKeys = _categoryKeys();
    final body = <String, dynamic>{
      'text': trimmedText,
      'currentDate': _dateOnly(localNow),
      'currentDateTime': localNow.toIso8601String(),
      'timezone': localNow.timeZoneName,
      'locale': requestLocale,
      'categories': categoryKeys
          .map((key) => {'key': key, 'label': key})
          .toList(growable: false),
      'wallets': wallets
          .map(
            (wallet) => {
              'id': wallet.id,
              'name': wallet.name,
              'type': wallet.type.name,
              'isActive': wallet.isActive,
            },
          )
          .toList(growable: false),
    };

    dynamic response;
    try {
      response = await _invoker(body);
    } on QuickAddException {
      rethrow;
    } catch (_) {
      throw QuickAddException(
        'PARSER_UNAVAILABLE',
        _isVietnamese(requestLocale)
            ? 'Không thể phân tích giao dịch lúc này.'
            : 'Unable to parse the transaction right now.',
      );
    }

    return _buildDraft(
      response,
      originalText: trimmedText,
      locale: requestLocale,
      wallets: wallets,
      categoryKeys: categoryKeys,
    );
  }

  QuickAddDraft _buildDraft(
    dynamic response, {
    required String originalText,
    required String locale,
    required List<WalletModel> wallets,
    required List<String> categoryKeys,
  }) {
    if (response is! Map) return _invalidResponse(locale);
    final map = Map<String, dynamic>.from(response);
    if (map['success'] != true) {
      final rawError = map['error'];
      final code = rawError is Map && rawError['code'] is String
          ? rawError['code'] as String
          : 'PARSER_FAILED';
      throw QuickAddException(
        code,
        _isVietnamese(locale)
            ? 'Không thể phân tích giao dịch.'
            : 'Unable to parse the transaction.',
      );
    }
    if (map['version'] != _supportedVersion) {
      throw QuickAddException(
        'UNSUPPORTED_VERSION',
        _isVietnamese(locale)
            ? 'Phiên bản kết quả Quick Add không được hỗ trợ.'
            : 'The Quick Add response version is not supported.',
      );
    }
    final rawData = map['data'];
    if (rawData is! Map) return _invalidResponse(locale);
    final data = Map<String, dynamic>.from(rawData);
    const expectedKeys = {
      'type',
      'amount',
      'name',
      'categoryKey',
      'walletName',
      'date',
      'confidence',
      'warnings',
    };
    if (!expectedKeys.every(data.containsKey)) return _invalidResponse(locale);

    final rawType = data['type'];
    if (rawType != null && rawType != 'income' && rawType != 'expense') {
      return _invalidResponse(locale);
    }
    final rawAmount = data['amount'];
    if (rawAmount != null && (rawAmount is! int || rawAmount <= 0)) {
      return _invalidResponse(locale);
    }
    final name = _nullableNonEmptyString(data['name'], locale);
    final walletHint = _nullableNonEmptyString(data['walletName'], locale);
    final rawCategory = data['categoryKey'];
    if (rawCategory != null && rawCategory is! String) {
      return _invalidResponse(locale);
    }
    final rawConfidence = data['confidence'];
    if (rawConfidence is! num ||
        !rawConfidence.isFinite ||
        rawConfidence < 0 ||
        rawConfidence > 1) {
      return _invalidResponse(locale);
    }
    final rawWarnings = data['warnings'];
    if (rawWarnings is! List || rawWarnings.any((item) => item is! String)) {
      return _invalidResponse(locale);
    }

    DateTime? date;
    var invalidDate = false;
    final rawDate = data['date'];
    if (rawDate != null) {
      if (rawDate is! String) return _invalidResponse(locale);
      date = DateTime.tryParse(rawDate);
      invalidDate = date == null;
    }

    final warnings = rawWarnings.cast<String>().toList();
    final missing = <QuickAddMissingField>{};
    final type = switch (rawType) {
      'income' => QuickAddTransactionType.income,
      'expense' => QuickAddTransactionType.expense,
      _ => null,
    };
    if (rawAmount == null) {
      missing.add(QuickAddMissingField.amount);
      warnings.add(_warning(locale, 'amount'));
    }
    if (type == null) {
      missing.add(QuickAddMissingField.transactionType);
      warnings.add(_warning(locale, 'type'));
    }
    if (name == null) {
      missing.add(QuickAddMissingField.name);
      warnings.add(_warning(locale, 'name'));
    }

    String? category = rawCategory as String?;
    if (category == null || !categoryKeys.contains(category)) {
      if (categoryKeys.contains('Other')) {
        category = 'Other';
        warnings.add(_warning(locale, 'categoryFallback'));
      } else {
        category = null;
        missing.add(QuickAddMissingField.category);
        warnings.add(_warning(locale, 'categoryMissing'));
      }
    }

    final wallet = walletHint == null
        ? _defaultCashWallet(wallets)
        : _resolveWallet(walletHint, wallets);
    if (wallet == null) {
      missing.add(QuickAddMissingField.wallet);
      warnings.add(
        walletHint == null
            ? _warning(locale, 'walletMissing')
            : _walletNotFoundWarning(locale, walletHint),
      );
    }
    if (invalidDate) warnings.add(_warning(locale, 'date'));

    if (_looksLikeTransfer(originalText)) {
      missing.add(QuickAddMissingField.transactionType);
      warnings.add(_warning(locale, 'transfer'));
      return QuickAddDraft(
        originalText: originalText,
        type: null,
        amount: rawAmount as int?,
        name: name,
        categoryKey: category,
        walletId: wallet?.id,
        walletName: wallet?.name ?? walletHint,
        date: date,
        confidence: rawConfidence.toDouble(),
        missingFields: missing,
        warnings: _unique(warnings),
      );
    }

    return QuickAddDraft(
      originalText: originalText,
      type: type,
      amount: rawAmount as int?,
      name: name,
      categoryKey: category,
      walletId: wallet?.id,
      walletName: wallet?.name ?? walletHint,
      date: date,
      confidence: rawConfidence.toDouble(),
      missingFields: missing,
      warnings: _unique(warnings),
    );
  }

  String? _nullableNonEmptyString(dynamic value, String locale) {
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) _invalidResponse(locale);
    return value.trim();
  }

  Never _invalidResponse(String locale) {
    throw QuickAddException(
      'INVALID_RESPONSE',
      _isVietnamese(locale)
          ? 'Kết quả phân tích không hợp lệ.'
          : 'The parser returned an invalid response.',
    );
  }

  static Future<dynamic> _invokeFunction(Map<String, dynamic> body) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'parse-natural-language-transaction',
        body: body,
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final rawError = details is Map ? details['error'] : null;
      final code = rawError is Map && rawError['code'] is String
          ? rawError['code'] as String
          : 'PARSER_UNAVAILABLE';
      final locale = body['locale']?.toString() ?? _currentLocale;
      throw QuickAddException(code, _functionErrorMessage(code, locale));
    }
  }

  static String _functionErrorMessage(String code, String locale) {
    final vi = _isVietnamese(locale);
    return switch (code) {
      'GEMINI_TIMEOUT' =>
        vi
            ? 'Dịch vụ phân tích phản hồi quá chậm. Vui lòng thử lại.'
            : 'The parsing service took too long. Please try again.',
      'GEMINI_RATE_LIMITED' =>
        vi
            ? 'Dịch vụ phân tích đang quá tải. Vui lòng thử lại sau.'
            : 'The parsing service is busy. Please try again later.',
      'UNAUTHORIZED' =>
        vi
            ? 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.'
            : 'Your session is invalid. Please sign in again.',
      _ =>
        vi
            ? 'Không thể phân tích giao dịch lúc này.'
            : 'Unable to parse the transaction right now.',
    };
  }

  static List<WalletModel> _activeCurrentUserWallets() => WalletService
      .instance
      .currentUserWallets
      .where((wallet) => wallet.isActive)
      .toList(growable: false);

  static Future<void> _refreshProductionWallets() =>
      WalletService.instance.fetchWallets();

  static List<String> _availableCategoryKeys() => [
    ...TransactionCategory.all.map((category) => category.key),
    ...CustomCategoryStore.instance.items.map((category) => category.name),
  ];

  static WalletModel? _resolveWallet(String hint, List<WalletModel> wallets) {
    final normalizedHint = _normalizeWalletText(hint);
    for (final wallet in wallets) {
      if (_normalizeWalletText(wallet.name) == normalizedHint) return wallet;
    }
    const cashAliases = {'tien mat', 'cash', 'cash account', 'vi tien mat'};
    if (cashAliases.contains(normalizedHint)) {
      for (final wallet in wallets) {
        if (wallet.type == WalletType.cash) return wallet;
      }
    }

    return null;
  }

  static WalletModel? _defaultCashWallet(List<WalletModel> wallets) {
    for (final wallet in wallets) {
      if (wallet.type == WalletType.cash) return wallet;
    }
    return null;
  }

  static String _normalizeWalletText(String value) {
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final lower = value.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final index = source.indexOf(char);
      buffer.write(index < 0 ? char : target[index]);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _looksLikeTransfer(String text) {
    final value = _normalizeWalletText(text);
    return (value.contains('chuyen') &&
            value.contains(' tu ') &&
            value.contains(' sang ')) ||
        (value.contains('transfer') &&
            value.contains(' from ') &&
            value.contains(' to '));
  }

  static List<String> _unique(List<String> values) =>
      values.toSet().toList(growable: false);

  static String get _currentLocale =>
      AppLanguage.instance.locale == AppLocale.vietnamese ? 'vi-VN' : 'en-US';

  static bool _isVietnamese(String locale) =>
      locale.toLowerCase().startsWith('vi');

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _walletNotFoundWarning(String locale, String wallet) =>
      _isVietnamese(locale)
      ? 'Không tìm thấy tài khoản $wallet.'
      : 'Could not find the $wallet account.';

  static String _warning(String locale, String key) {
    final vi = _isVietnamese(locale);
    return switch (key) {
      'amount' =>
        vi
            ? 'Không xác định được số tiền giao dịch.'
            : 'The transaction amount could not be determined.',
      'type' =>
        vi
            ? 'Không xác định được loại giao dịch.'
            : 'The transaction type could not be determined.',
      'name' =>
        vi
            ? 'Không xác định được tên giao dịch.'
            : 'The transaction name could not be determined.',
      'categoryFallback' =>
        vi
            ? 'Không xác định được danh mục phù hợp. Đã sử dụng Other.'
            : 'No matching category was found. Other was used.',
      'categoryMissing' =>
        vi
            ? 'Không xác định được danh mục giao dịch.'
            : 'The transaction category could not be determined.',
      'walletMissing' =>
        vi
            ? 'Không xác định được tài khoản.'
            : 'The account could not be determined.',
      'date' =>
        vi
            ? 'Không xác định được ngày giao dịch.'
            : 'The transaction date could not be determined.',
      'transfer' =>
        vi
            ? 'Chuyển tiền giữa các tài khoản chưa được hỗ trợ.'
            : 'Transfers between accounts are not supported yet.',
      _ =>
        vi
            ? 'Thông tin giao dịch chưa đầy đủ.'
            : 'Transaction details are incomplete.',
    };
  }
}
