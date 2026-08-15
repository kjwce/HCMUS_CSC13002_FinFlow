class CategoryBudgetModel {
  const CategoryBudgetModel({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.month,
    required this.year,
  });

  factory CategoryBudgetModel.fromJson(Map<String, dynamic> json) =>
      CategoryBudgetModel(
        id: json['id'] as String,
        category: json['category'] as String,
        limitAmount: (json['limit_amount'] as num).toInt(),
        month: (json['month'] as num).toInt(),
        year: (json['year'] as num).toInt(),
      );

  final String id;
  final String category;
  final int limitAmount;
  final int month;
  final int year;
}
