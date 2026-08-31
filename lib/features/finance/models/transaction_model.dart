class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.amount,
    required this.date,
    this.walletId,
    this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] ?? json['title'];
    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName
          : 'Transaction',
      category: json['category'] as String,
      amount: json['amount'] as int,
      date: _parseStoredDate(json),
      walletId: json['wallet_id'] as String?,
      createdAt: _parseCreatedAt(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'category': category,
    'amount': amount,
    'date': floatingLocalIso(date),
    if (walletId != null) 'wallet_id': walletId,
  };

  static String floatingLocalIso(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    ).toIso8601String();
  }

  static DateTime _parseStoredDate(Map<String, dynamic> json) {
    final stored = DateTime.parse(json['date'] as String);

    // Transaction dates are deliberately written as floating local time by
    // [floatingLocalIso]. Supabase's TIMESTAMPTZ column may append `Z` when it
    // returns that value, but converting that instant again would shift the
    // user-entered wall clock into another calendar day (for example 17:38 in
    // Vietnam becoming 00:38 tomorrow). Rebuild a local DateTime from the
    // stored components so daily filters use the date the user selected.
    return DateTime(
      stored.year,
      stored.month,
      stored.day,
      stored.hour,
      stored.minute,
      stored.second,
      stored.millisecond,
      stored.microsecond,
    );
  }

  static DateTime? _parseCreatedAt(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  final String id;
  final String userId;
  final String name;
  final String category;
  final int amount;
  final DateTime date;
  final String? walletId;
  final DateTime? createdAt;

  /// When the record was actually entered into FinFlow. Older/local records
  /// may not have this field, so their transaction date is the safe fallback.
  DateTime get recordedAt => createdAt ?? date;

  static TransactionModel? latestRecorded(
    Iterable<TransactionModel> transactions,
  ) {
    TransactionModel? latest;
    for (final transaction in transactions) {
      if (latest == null || transaction.recordedAt.isAfter(latest.recordedAt)) {
        latest = transaction;
      }
    }
    return latest;
  }

  /// Most recent transaction by its real transaction date, ignoring entries
  /// dated in the future. This is the correct semantic for "Latest" and
  /// "Recent transactions" surfaces; [latestRecorded] remains available for
  /// audit flows that care about when a record was entered into FinFlow.
  static TransactionModel? latestOccurred(
    Iterable<TransactionModel> transactions, {
    DateTime? asOf,
  }) {
    final cutoff = asOf ?? DateTime.now();
    TransactionModel? latest;
    for (final transaction in transactions) {
      if (transaction.date.isAfter(cutoff)) continue;
      if (latest == null ||
          transaction.date.isAfter(latest.date) ||
          (transaction.date.isAtSameMomentAs(latest.date) &&
              transaction.recordedAt.isAfter(latest.recordedAt))) {
        latest = transaction;
      }
    }
    return latest;
  }
}
