class NotificationPreferences {
  const NotificationPreferences({
    this.masterEnabled = true,
    this.inAppBannerEnabled = true,
    this.dailyBudgetEnabled = true,
    this.dailyBudgetThreshold = 90,
    this.weeklyBudgetEnabled = true,
    this.weeklyBudgetThreshold = 80,
    this.monthlyBudgetEnabled = true,
    this.monthlyBudgetThreshold = 85,
    this.savingGoalUpdatesEnabled = true,
    this.recurringExpenseEnabled = true,
    this.recurringIncomeEnabled = true,
    this.recurringFailureEnabled = true,
    this.communityLikesEnabled = true,
    this.communityRepliesEnabled = true,
    this.communityPostsEnabled = false,
    this.systemEnabled = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      masterEnabled: json['master_enabled'] as bool? ?? true,
      inAppBannerEnabled: json['in_app_banner_enabled'] as bool? ?? true,
      dailyBudgetEnabled: json['daily_budget_enabled'] as bool? ?? true,
      dailyBudgetThreshold:
          (json['daily_budget_threshold'] as num?)?.toInt() ?? 90,
      weeklyBudgetEnabled: json['weekly_budget_enabled'] as bool? ?? true,
      weeklyBudgetThreshold:
          (json['weekly_budget_threshold'] as num?)?.toInt() ?? 80,
      monthlyBudgetEnabled: json['monthly_budget_enabled'] as bool? ?? true,
      monthlyBudgetThreshold:
          (json['monthly_budget_threshold'] as num?)?.toInt() ?? 85,
      savingGoalUpdatesEnabled:
          json['saving_goal_updates_enabled'] as bool? ?? true,
      recurringExpenseEnabled:
          json['recurring_expense_enabled'] as bool? ?? true,
      recurringIncomeEnabled: json['recurring_income_enabled'] as bool? ?? true,
      recurringFailureEnabled:
          json['recurring_failure_enabled'] as bool? ?? true,
      communityLikesEnabled: json['community_likes_enabled'] as bool? ?? true,
      communityRepliesEnabled:
          json['community_replies_enabled'] as bool? ?? true,
      communityPostsEnabled: json['community_posts_enabled'] as bool? ?? false,
      systemEnabled: json['system_enabled'] as bool? ?? true,
    );
  }

  final bool masterEnabled;
  final bool inAppBannerEnabled;
  final bool dailyBudgetEnabled;
  final int dailyBudgetThreshold;
  final bool weeklyBudgetEnabled;
  final int weeklyBudgetThreshold;
  final bool monthlyBudgetEnabled;
  final int monthlyBudgetThreshold;
  final bool savingGoalUpdatesEnabled;
  final bool recurringExpenseEnabled;
  final bool recurringIncomeEnabled;
  final bool recurringFailureEnabled;
  final bool communityLikesEnabled;
  final bool communityRepliesEnabled;
  final bool communityPostsEnabled;
  final bool systemEnabled;

  Map<String, dynamic> toJson() => {
    'master_enabled': masterEnabled,
    'in_app_banner_enabled': inAppBannerEnabled,
    'daily_budget_enabled': dailyBudgetEnabled,
    'daily_budget_threshold': dailyBudgetThreshold,
    'weekly_budget_enabled': weeklyBudgetEnabled,
    'weekly_budget_threshold': weeklyBudgetThreshold,
    'monthly_budget_enabled': monthlyBudgetEnabled,
    'monthly_budget_threshold': monthlyBudgetThreshold,
    'saving_goal_updates_enabled': savingGoalUpdatesEnabled,
    'recurring_expense_enabled': recurringExpenseEnabled,
    'recurring_income_enabled': recurringIncomeEnabled,
    'recurring_failure_enabled': recurringFailureEnabled,
    'community_likes_enabled': communityLikesEnabled,
    'community_replies_enabled': communityRepliesEnabled,
    'community_posts_enabled': communityPostsEnabled,
    'system_enabled': systemEnabled,
  };

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? inAppBannerEnabled,
    bool? dailyBudgetEnabled,
    int? dailyBudgetThreshold,
    bool? weeklyBudgetEnabled,
    int? weeklyBudgetThreshold,
    bool? monthlyBudgetEnabled,
    int? monthlyBudgetThreshold,
    bool? savingGoalUpdatesEnabled,
    bool? recurringExpenseEnabled,
    bool? recurringIncomeEnabled,
    bool? recurringFailureEnabled,
    bool? communityLikesEnabled,
    bool? communityRepliesEnabled,
    bool? communityPostsEnabled,
    bool? systemEnabled,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      inAppBannerEnabled: inAppBannerEnabled ?? this.inAppBannerEnabled,
      dailyBudgetEnabled: dailyBudgetEnabled ?? this.dailyBudgetEnabled,
      dailyBudgetThreshold: dailyBudgetThreshold ?? this.dailyBudgetThreshold,
      weeklyBudgetEnabled: weeklyBudgetEnabled ?? this.weeklyBudgetEnabled,
      weeklyBudgetThreshold:
          weeklyBudgetThreshold ?? this.weeklyBudgetThreshold,
      monthlyBudgetEnabled: monthlyBudgetEnabled ?? this.monthlyBudgetEnabled,
      monthlyBudgetThreshold:
          monthlyBudgetThreshold ?? this.monthlyBudgetThreshold,
      savingGoalUpdatesEnabled:
          savingGoalUpdatesEnabled ?? this.savingGoalUpdatesEnabled,
      recurringExpenseEnabled:
          recurringExpenseEnabled ?? this.recurringExpenseEnabled,
      recurringIncomeEnabled:
          recurringIncomeEnabled ?? this.recurringIncomeEnabled,
      recurringFailureEnabled:
          recurringFailureEnabled ?? this.recurringFailureEnabled,
      communityLikesEnabled:
          communityLikesEnabled ?? this.communityLikesEnabled,
      communityRepliesEnabled:
          communityRepliesEnabled ?? this.communityRepliesEnabled,
      communityPostsEnabled:
          communityPostsEnabled ?? this.communityPostsEnabled,
      systemEnabled: systemEnabled ?? this.systemEnabled,
    );
  }
}
