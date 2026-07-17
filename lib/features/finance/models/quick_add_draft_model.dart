import 'dart:collection';

import 'transaction_model.dart';

enum QuickAddTransactionType { income, expense }

enum QuickAddMissingField { amount, transactionType, name, category, wallet }

/// Temporary, reviewable result of natural-language transaction parsing.
///
/// This model is never persisted directly. [amount] is always an unsigned,
/// positive VND value; [type] determines the eventual transaction sign.
class QuickAddDraft {
  QuickAddDraft({
    required this.originalText,
    required this.type,
    required this.amount,
    required this.name,
    required this.categoryKey,
    required this.walletId,
    required this.walletName,
    required this.date,
    required this.confidence,
    required Set<QuickAddMissingField> missingFields,
    required List<String> warnings,
  }) : missingFields = UnmodifiableSetView(Set.of(missingFields)),
       warnings = List.unmodifiable(warnings) {
    if (amount != null && amount! <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive');
    }
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Must be finite and between 0 and 1',
      );
    }
  }

  final String originalText;
  final QuickAddTransactionType? type;
  final int? amount;
  final String? name;
  final String? categoryKey;
  final String? walletId;
  final String? walletName;
  final DateTime? date;
  final double confidence;
  final Set<QuickAddMissingField> missingFields;
  final List<String> warnings;

  bool get canConfirm => missingFields.isEmpty;

  TransactionModel toTransactionModel({
    required String id,
    required String userId,
    DateTime? defaultDate,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }
    if (!canConfirm ||
        type == null ||
        amount == null ||
        name == null ||
        name!.trim().isEmpty ||
        categoryKey == null ||
        walletId == null) {
      throw StateError('Quick Add draft is incomplete and cannot be confirmed');
    }

    final signedAmount = switch (type!) {
      QuickAddTransactionType.income => amount!.abs(),
      QuickAddTransactionType.expense => -amount!.abs(),
    };

    return TransactionModel(
      id: id,
      userId: userId,
      name: name!.trim(),
      category: categoryKey!,
      amount: signedAmount,
      date: date ?? defaultDate ?? DateTime.now(),
      walletId: walletId,
    );
  }
}
