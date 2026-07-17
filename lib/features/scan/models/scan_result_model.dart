class ScanResultModel {
  const ScanResultModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.imageUrl,
    required this.totalAmount,
    required this.createdAt,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    return ScanResultModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      items: (json['items'] as List?)
              ?.map((e) => ScannedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      imageUrl: json['image_url'] as String? ?? '',
      totalAmount: json['total_amount'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'items': items.map((e) => e.toJson()).toList(),
        'image_url': imageUrl,
        'total_amount': totalAmount,
        'created_at': createdAt.toIso8601String(),
      };

  final String id;
  final String userId;
  final List<ScannedItem> items;
  final String imageUrl;
  final int totalAmount;
  final DateTime createdAt;
}

class ScannedItem {
  const ScannedItem({
    required this.name,
    required this.amount,
    required this.category,
  });

  factory ScannedItem.fromJson(Map<String, dynamic> json) {
    return ScannedItem(
      name: json['name'] as String,
      amount: json['amount'] as int,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'category': category,
      };

  final String name;
  final int amount;
  final String category;
}
