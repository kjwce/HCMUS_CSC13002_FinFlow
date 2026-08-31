import 'package:finflow/features/settings/models/notification_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips every migration 033 preference', () {
    const preferences = NotificationPreferences(
      masterEnabled: true,
      inAppBannerEnabled: false,
      dailyBudgetEnabled: true,
      dailyBudgetThreshold: 75,
      weeklyBudgetEnabled: false,
      weeklyBudgetThreshold: 80,
      monthlyBudgetEnabled: true,
      monthlyBudgetThreshold: 95,
      savingGoalUpdatesEnabled: false,
      recurringExpenseEnabled: true,
      recurringIncomeEnabled: false,
      recurringFailureEnabled: true,
      communityLikesEnabled: false,
      communityRepliesEnabled: true,
      communityPostsEnabled: false,
      systemEnabled: true,
    );

    final restored = NotificationPreferences.fromJson(preferences.toJson());
    expect(restored.toJson(), preferences.toJson());
  });

  test('uses safe defaults for a new account', () {
    final preferences = NotificationPreferences.fromJson(const {});
    expect(preferences.masterEnabled, isTrue);
    expect(preferences.inAppBannerEnabled, isTrue);
    expect(preferences.dailyBudgetThreshold, 90);
    expect(preferences.communityPostsEnabled, isFalse);
  });
}
