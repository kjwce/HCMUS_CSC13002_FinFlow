class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.walletId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      amount: json['amount'] as int,
      date: _parseStoredDate(json),
      walletId: json['wallet_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
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
    final rawDate = DateTime.parse(json['date'] as String);
    final createdAtRaw = json['created_at'];
    if (createdAtRaw is String) {
      final createdAt = DateTime.tryParse(createdAtRaw);
      if (createdAt != null) {
        final instantDelta = rawDate
            .toUtc()
            .difference(createdAt.toUtc())
            .abs();
        if (instantDelta <= const Duration(minutes: 5)) {
          return rawDate.toLocal();
        }
      }
    }
    return rawDate;
  }

  final String id;
  final String userId;
  final String title;
  final String category;
  final int amount;
  final DateTime date;
  final String? walletId;
}
