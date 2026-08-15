import 'package:supabase_flutter/supabase_flutter.dart';

import '../../finance/models/quick_add_draft_model.dart';
import '../../finance/models/transaction_category.dart';
import '../../finance/models/wallet_model.dart';
import '../../finance/services/wallet_service.dart';
import '../models/bank_notification_models.dart';

typedef BankNotificationFunctionInvoker =
    Future<dynamic> Function(Map<String, dynamic> body);

class BankNotificationImportException implements Exception {
  const BankNotificationImportException(this.code);

  final String code;
}

class BankNotificationImportService {
  BankNotificationImportService._({
    BankNotificationFunctionInvoker? invoker,
    List<WalletModel> Function()? wallets,
  }) : _invoker = invoker ?? _invokeFunction,
       _wallets = wallets ?? (() => WalletService.instance.currentUserWallets);

  static final instance = BankNotificationImportService._();

  factory BankNotificationImportService.forTesting({
    required BankNotificationFunctionInvoker invoker,
    required List<WalletModel> Function() wallets,
  }) => BankNotificationImportService._(invoker: invoker, wallets: wallets);

  final BankNotificationFunctionInvoker _invoker;
  final List<WalletModel> Function() _wallets;

  Future<BankNotificationParseResult> parse(
    BankNotificationEnvelope notification,
  ) async {
    var wallets = _wallets();
    if (wallets.isEmpty) {
      await WalletService.instance.fetchWallets();
      wallets = _wallets();
    }
    final transferWallet = wallets
        .where((wallet) => wallet.isActive)
        .where((wallet) => wallet.type == WalletType.transfer)
        .firstOrNull;
    if (transferWallet == null) {
      throw const BankNotificationImportException('TRANSFER_WALLET_MISSING');
    }

    final categories = [
      ...TransactionCategory.all.map((category) => category.key),
      ...CustomCategoryStore.instance.items.map((category) => category.name),
    ];
    final response = await _invoker({
      'packageName': notification.packageName,
      'title': _redact(notification.title),
      'text': _redact(notification.text),
      'postedAt': notification.postedAt.toIso8601String(),
      'currentDateTime': DateTime.now().toIso8601String(),
      'categories': categories,
    });
    if (response is! Map || response['success'] != true) {
      throw const BankNotificationImportException('INVALID_RESPONSE');
    }
    final data = response['data'];
    if (data is! Map) {
      throw const BankNotificationImportException('INVALID_RESPONSE');
    }
    if (data['isTransaction'] != true) {
      return const BankNotificationParseResult.ignored();
    }

    final type = switch (data['type']) {
      'income' => QuickAddTransactionType.income,
      'expense' => QuickAddTransactionType.expense,
      _ => null,
    };
    final amount = data['amount'];
    final confidence = data['confidence'];
    if (type == null ||
        amount is! int ||
        amount <= 0 ||
        confidence is! num ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1) {
      throw const BankNotificationImportException('INVALID_RESPONSE');
    }

    final rawCategory = data['categoryKey'];
    final category = rawCategory is String && categories.contains(rawCategory)
        ? rawCategory
        : (categories.contains('Other') ? 'Other' : null);
    final rawName = data['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'Bank transaction';
    final rawDate = data['date'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final warnings = <String>[
      if (data['warnings'] is List)
        ...(data['warnings'] as List).whereType<String>(),
      if (confidence < 0.85)
        'AI chưa hoàn toàn chắc chắn. Vui lòng kiểm tra kỹ trước khi lưu.',
    ];
    final missing = <QuickAddMissingField>{
      if (category == null) QuickAddMissingField.category,
    };
    return BankNotificationParseResult.transaction(
      QuickAddDraft(
        originalText: '${notification.title}\n${notification.text}'.trim(),
        type: type,
        amount: amount,
        name: name,
        categoryKey: category,
        walletId: transferWallet.id,
        walletName: transferWallet.name,
        date: date ?? notification.postedAt,
        confidence: confidence.toDouble(),
        missingFields: missing,
        warnings: warnings.toSet().toList(growable: false),
      ),
    );
  }

  static String _redact(String value) {
    return value.replaceAllMapped(
      RegExp(
        r'((?:tk|tài khoản|tai khoan|account|card|thẻ|the)\s*[:\-]?\s*)(\d{8,19})',
        caseSensitive: false,
      ),
      (match) =>
          '${match.group(1)}***${match.group(2)!.substring(match.group(2)!.length - 4)}',
    );
  }

  static Future<dynamic> _invokeFunction(Map<String, dynamic> body) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'parse-bank-notification',
        body: body,
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final rawError = details is Map ? details['error'] : null;
      final code = rawError is Map && rawError['code'] is String
          ? rawError['code'] as String
          : 'PARSER_UNAVAILABLE';
      throw BankNotificationImportException(code);
    }
  }
}
