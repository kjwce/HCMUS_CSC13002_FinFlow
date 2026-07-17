class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
    required this.budgetLimit,
    this.weeklyBudget = 0,
    this.phone,
    this.avatarUrl,
    this.selectedCategory,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      budgetLimit: json['budget_limit'] as int? ?? 0,
      weeklyBudget: json['weekly_budget'] as int? ?? 0,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      selectedCategory: json['selected_category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'created_at': createdAt.toIso8601String(),
    'budget_limit': budgetLimit,
    'weekly_budget': weeklyBudget,
    if (phone != null) 'phone': phone,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (selectedCategory != null) 'selected_category': selectedCategory,
  };

  final String id;
  final String fullName;
  final String email;
  final DateTime createdAt;
  final int budgetLimit;
  final int weeklyBudget;
  final String? phone;
  final String? avatarUrl;
  final String? selectedCategory;
}
