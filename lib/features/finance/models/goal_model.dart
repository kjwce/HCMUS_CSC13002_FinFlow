class GoalModel {
  const GoalModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.createdAt,
    this.isActive = true,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      targetAmount: json['target_amount'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'target_amount': targetAmount,
        'created_at': createdAt.toIso8601String(),
        'is_active': isActive,
      };

  final String id;
  final String userId;
  final String name;
  final int targetAmount;
  final DateTime createdAt;
  final bool isActive;
}
