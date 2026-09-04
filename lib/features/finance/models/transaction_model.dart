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
    'date': databaseIso(date),
    if (walletId != null) 'wallet_id': walletId,
  };

  /// PostgreSQL stores transaction dates as TIMESTAMPTZ, so send an absolute
  /// UTC instant and convert it back to the device timezone when reading.
  static String databaseIso(DateTime value) => value.toUtc().toIso8601String();

  /// Returns [calendarDate] with the time-of-day from [timeSource]. Date
  /// pickers return midnight, which must not silently replace the actual time.
  static DateTime withCalendarDate(
    DateTime calendarDate,
    DateTime timeSource,
  ) => DateTime(
    calendarDate.year,
    calendarDate.month,
    calendarDate.day,
    timeSource.hour,
    timeSource.minute,
    timeSource.second,
    timeSource.millisecond,
    timeSource.microsecond,
  );

  static DateTime _parseStoredDate(Map<String, dynamic> json) {
    final stored = DateTime.parse(json['date'] as String);

    return stored.toLocal();
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

  TransactionModel copyWith({DateTime? date}) => TransactionModel(
    id: id,
    userId: userId,
    name: name,
    category: category,
    amount: amount,
    date: date ?? this.date,
    walletId: walletId,
    createdAt: createdAt,
  );

  /// The transaction form does not allow future dates. Old builds could still
  /// persist one because of incorrect timezone handling, so use the record's
  /// creation time as the safest repair value.
  TransactionModel repairInvalidFutureDate(
    DateTime now, {
    Duration clockTolerance = const Duration(minutes: 5),
  }) {
    if (!date.isAfter(now.add(clockTolerance))) return this;
    final recorded = createdAt;
    final repairedDate = recorded != null && !recorded.isAfter(now)
        ? recorded
        : now;
    return copyWith(date: repairedDate);
  }

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
