enum GoalFundingMethod { manual, automatic }

enum GoalStatus { active, completed, archived }

enum GoalCompletionBehavior { keepAvailable, redirect }

enum ExpenseShortfallPolicy { askEachTime, autoWithdraw }

class GoalModel {
  const GoalModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.createdAt,
    this.category = 'Other',
    this.targetDate,
    this.fundingMethod = GoalFundingMethod.manual,
    this.autoAllocationPercent = 0,
    this.isPrimary = false,
    this.isProtected = false,
    this.withdrawalPriority = 100,
    this.status = GoalStatus.active,
    this.completionBehavior = GoalCompletionBehavior.keepAvailable,
    this.redirectGoalId,
    this.imageUrl,
    this.allocatedAmount = 0,
  });

  factory GoalModel.fromJson(
    Map<String, dynamic> json, {
    int allocatedAmount = 0,
  }) {
    return GoalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      category: json['category'] as String? ?? 'Other',
      targetDate: _parseDate(json['target_date']),
      fundingMethod: json['funding_method'] == 'automatic'
          ? GoalFundingMethod.automatic
          : GoalFundingMethod.manual,
      autoAllocationPercent:
          (json['auto_allocation_percent'] as num?)?.toDouble() ?? 0,
      isPrimary:
          json['is_primary'] as bool? ?? json['is_active'] as bool? ?? false,
      isProtected: json['is_protected'] as bool? ?? false,
      withdrawalPriority: (json['withdrawal_priority'] as num?)?.toInt() ?? 100,
      status: GoalStatus.values.firstWhere(
        (value) => value.name == (json['status'] as String? ?? 'active'),
        orElse: () => GoalStatus.active,
      ),
      completionBehavior: json['completion_behavior'] == 'redirect'
          ? GoalCompletionBehavior.redirect
          : GoalCompletionBehavior.keepAvailable,
      redirectGoalId: json['redirect_goal_id'] as String?,
      imageUrl: json['image_url'] as String?,
      allocatedAmount: allocatedAmount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'target_amount': targetAmount,
    'category': category,
    'target_date': targetDate == null
        ? null
        : '${targetDate!.year.toString().padLeft(4, '0')}-'
              '${targetDate!.month.toString().padLeft(2, '0')}-'
              '${targetDate!.day.toString().padLeft(2, '0')}',
    'funding_method': fundingMethod.name,
    'auto_allocation_percent': fundingMethod == GoalFundingMethod.automatic
        ? autoAllocationPercent
        : 0,
    'is_primary': isPrimary,
    'is_active': isPrimary,
    'is_protected': isProtected,
    'withdrawal_priority': withdrawalPriority,
    'status': status.name,
    'completion_behavior': completionBehavior == GoalCompletionBehavior.redirect
        ? 'redirect'
        : 'keep_available',
    'redirect_goal_id': redirectGoalId,
    'image_url': imageUrl,
    'created_at': createdAt.toIso8601String(),
  };

  GoalModel copyWith({
    String? name,
    int? targetAmount,
    String? category,
    DateTime? targetDate,
    GoalFundingMethod? fundingMethod,
    double? autoAllocationPercent,
    bool? isPrimary,
    bool? isProtected,
    int? withdrawalPriority,
    GoalStatus? status,
    GoalCompletionBehavior? completionBehavior,
    String? redirectGoalId,
    String? imageUrl,
    int? allocatedAmount,
  }) => GoalModel(
    id: id,
    userId: userId,
    name: name ?? this.name,
    targetAmount: targetAmount ?? this.targetAmount,
    createdAt: createdAt,
    category: category ?? this.category,
    targetDate: targetDate ?? this.targetDate,
    fundingMethod: fundingMethod ?? this.fundingMethod,
    autoAllocationPercent: autoAllocationPercent ?? this.autoAllocationPercent,
    isPrimary: isPrimary ?? this.isPrimary,
    isProtected: isProtected ?? this.isProtected,
    withdrawalPriority: withdrawalPriority ?? this.withdrawalPriority,
    status: status ?? this.status,
    completionBehavior: completionBehavior ?? this.completionBehavior,
    redirectGoalId: redirectGoalId ?? this.redirectGoalId,
    imageUrl: imageUrl ?? this.imageUrl,
    allocatedAmount: allocatedAmount ?? this.allocatedAmount,
  );

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  final String id;
  final String userId;
  final String name;
  final int targetAmount;
  final DateTime createdAt;
  final String category;
  final DateTime? targetDate;
  final GoalFundingMethod fundingMethod;
  final double autoAllocationPercent;
  final bool isPrimary;
  final bool isProtected;
  final int withdrawalPriority;
  final GoalStatus status;
  final GoalCompletionBehavior completionBehavior;
  final String? redirectGoalId;
  final String? imageUrl;
  final int allocatedAmount;

  int get remainingAmount =>
      (targetAmount - allocatedAmount).clamp(0, targetAmount);
  double get progress =>
      targetAmount <= 0 ? 0 : (allocatedAmount / targetAmount).clamp(0.0, 1.0);
  bool get isCompleted => status == GoalStatus.completed || progress >= 1;
}

class GoalFundEntry {
  const GoalFundEntry({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.entryType,
    required this.createdAt,
    this.note,
    this.sourceTransactionId,
  });

  factory GoalFundEntry.fromJson(Map<String, dynamic> json) => GoalFundEntry(
    id: json['id'] as String,
    goalId: json['goal_id'] as String,
    amount: (json['amount'] as num).toInt(),
    entryType: json['entry_type'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    note: json['note'] as String?,
    sourceTransactionId: json['source_transaction_id'] as String?,
  );

  final String id;
  final String goalId;
  final int amount;
  final String entryType;
  final DateTime createdAt;
  final String? note;
  final String? sourceTransactionId;
}

class GoalSettings {
  const GoalSettings({
    this.expenseShortfallPolicy = ExpenseShortfallPolicy.askEachTime,
  });

  factory GoalSettings.fromJson(Map<String, dynamic> json) => GoalSettings(
    expenseShortfallPolicy: json['expense_shortfall_policy'] == 'auto_withdraw'
        ? ExpenseShortfallPolicy.autoWithdraw
        : ExpenseShortfallPolicy.askEachTime,
  );

  final ExpenseShortfallPolicy expenseShortfallPolicy;
}
