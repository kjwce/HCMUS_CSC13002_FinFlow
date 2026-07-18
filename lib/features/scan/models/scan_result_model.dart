/// A line item extracted from a receipt image.
class ScannedItem {
  const ScannedItem({
    required this.name,
    required this.amount,
    required this.category,
    this.confidence = 1,
    this.warning,
  });

  factory ScannedItem.fromJson(Map<String, dynamic> json) {
    return ScannedItem(
      name: json['name'] is String ? json['name'] as String : '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      category: json['categoryKey'] is String
          ? json['categoryKey'] as String
          : json['category'] is String
          ? json['category'] as String
          : 'Other',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      warning: json['warning'] is String ? json['warning'] as String : null,
    );
  }

  final String name;
  final int amount;
  final String category;
  final double confidence;
  final String? warning;

  ScannedItem copyWith({
    String? name,
    int? amount,
    String? category,
    double? confidence,
    String? warning,
  }) {
    return ScannedItem(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      warning: warning ?? this.warning,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'categoryKey': category,
    'confidence': confidence,
    if (warning != null) 'warning': warning,
  };
}

/// Parsed receipt data shown in the review screen before saving.
class ScanResultModel {
  const ScanResultModel({
    required this.items,
    required this.totalAmount,
    this.merchantName,
    this.receiptDate,
    this.currency = 'VND',
    this.warnings = const [],
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ScanResultModel(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      ScannedItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      totalAmount:
          (json['totalAmount'] as num?)?.toInt() ??
          (json['total_amount'] as num?)?.toInt() ??
          0,
      merchantName: json['merchantName'] is String
          ? json['merchantName'] as String
          : json['merchant_name'] is String
          ? json['merchant_name'] as String
          : null,
      receiptDate: _parseDate(json['receiptDate'] ?? json['receipt_date']),
      currency: json['currency'] is String ? json['currency'] as String : 'VND',
      warnings:
          (json['warnings'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
    );
  }

  final List<ScannedItem> items;
  final int totalAmount;
  final String? merchantName;
  final DateTime? receiptDate;
  final String currency;
  final List<String> warnings;

  int get calculatedTotal => items.fold(0, (sum, item) => sum + item.amount);

  ScanResultModel copyWith({
    List<ScannedItem>? items,
    int? totalAmount,
    String? merchantName,
    DateTime? receiptDate,
    String? currency,
    List<String>? warnings,
  }) {
    return ScanResultModel(
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      merchantName: merchantName ?? this.merchantName,
      receiptDate: receiptDate ?? this.receiptDate,
      currency: currency ?? this.currency,
      warnings: warnings ?? this.warnings,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'totalAmount': totalAmount,
    'merchantName': merchantName,
    'receiptDate': receiptDate?.toIso8601String(),
    'currency': currency,
    'warnings': warnings,
  };

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
