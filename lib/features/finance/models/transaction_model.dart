class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      amount: json['amount'] as int,
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  final String id;
  final String userId;
  final String title;
  final String category;
  final int amount;
  final DateTime date;
}
