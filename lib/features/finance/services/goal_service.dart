import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../community/models/notification_model.dart';
import '../../community/services/notification_service.dart';
import '../models/goal_model.dart';

class GoalService extends ChangeNotifier {
  GoalService._();

  static final GoalService instance = GoalService._();

  List<GoalModel> _goals = const [];
  List<GoalFundEntry> _entries = const [];
  GoalSettings _settings = const GoalSettings();

  List<GoalModel> get goals => List.unmodifiable(_goals);
  List<GoalModel> get activeGoals => _goals
      .where((goal) => goal.status == GoalStatus.active)
      .toList(growable: false);
  List<GoalFundEntry> get entries => List.unmodifiable(_entries);
  GoalSettings get settings => _settings;
  GoalModel? get primaryGoal => _firstWhereOrNull(
    _goals,
    (goal) => goal.isPrimary && goal.status == GoalStatus.active,
  );

  /// Backward-compatible alias. Primary controls presentation only.
  GoalModel? get activeGoal =>
      primaryGoal ??
      _firstWhereOrNull(_goals, (goal) => goal.status == GoalStatus.active);

  @visibleForTesting
  void debugReplaceGoals(
    List<GoalModel> goals, {
    List<GoalFundEntry> entries = const [],
  }) {
    _goals = List.unmodifiable(goals);
    _entries = List.unmodifiable(entries);
    notifyListeners();
  }

  int get totalAllocated =>
      _goals.fold(0, (sum, goal) => sum + goal.allocatedAmount);
  double get assignedAutomaticPercent => _goals
      .where(
        (goal) =>
            goal.fundingMethod == GoalFundingMethod.automatic &&
            (goal.status == GoalStatus.active ||
                (goal.status == GoalStatus.completed &&
                    goal.completionBehavior ==
                        GoalCompletionBehavior.redirect)),
      )
      .fold(0, (sum, goal) => sum + goal.autoAllocationPercent);

  int availableForGoals(int actualBalance) => (actualBalance - totalAllocated)
      .clamp(0, actualBalance < 0 ? 0 : actualBalance);

  double progressRatio(int _) => activeGoal?.progress ?? 0;
  double progressRatioFor(GoalModel goal, int _) => goal.progress;
  int savedAmount(int _) => activeGoal?.allocatedAmount ?? 0;
  int savedAmountFor(GoalModel goal, int _) => goal.allocatedAmount;

  List<GoalFundEntry> entriesFor(String goalId) =>
      _entries.where((entry) => entry.goalId == goalId).toList(growable: false);

  GoalModel? byId(String goalId) =>
      _firstWhereOrNull(_goals, (goal) => goal.id == goalId);

  Future<void> fetchGoals() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _goals = const [];
      _entries = const [];
      notifyListeners();
      return;
    }

    final results = await Future.wait<dynamic>([
      Supabase.instance.client
          .from('goals')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false),
      Supabase.instance.client
          .from('goal_fund_entries')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false),
      Supabase.instance.client
          .from('goal_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle(),
    ]);

    _entries = (results[1] as List)
        .map((json) => GoalFundEntry.fromJson(json as Map<String, dynamic>))
        .toList(growable: false);
    final totals = <String, int>{};
    for (final entry in _entries) {
      totals.update(
        entry.goalId,
        (amount) => amount + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    _goals = (results[0] as List)
        .map(
          (json) => GoalModel.fromJson(
            json as Map<String, dynamic>,
            allocatedAmount: (totals[json['id']] ?? 0).clamp(0, 1 << 62),
          ),
        )
        .toList(growable: false);
    final settingsJson = results[2];
    if (settingsJson is Map<String, dynamic>) {
      _settings = GoalSettings.fromJson(settingsJson);
    } else {
      // Keep the persisted database default aligned with the UI default. The
      // transaction RPC reads this row to decide whether protected goals may
      // be selected manually; a missing row must not fall through to auto mode.
      await Supabase.instance.client.from('goal_settings').upsert({
        'user_id': userId,
        'expense_shortfall_policy': 'ask_each_time',
        'imported_transaction_policy': 'auto_withdraw',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _settings = const GoalSettings();
    }
    notifyListeners();
  }

  Future<void> setGoal(GoalModel goal) async {
    final userId = _requireUserId();
    await _clearPrimaryIfNeeded(goal.isPrimary, exceptGoalId: goal.id);
    await Supabase.instance.client.from('goals').insert({
      ...goal.toJson(),
      'user_id': userId,
    });
    if (goal.allocatedAmount > 0) {
      await allocate(goal.id, goal.allocatedAmount, entryType: 'initial');
    } else {
      await fetchGoals();
    }
  }

  Future<void> updateGoal(GoalModel goal) async {
    final userId = _requireUserId();
    if (goal.targetAmount < goal.allocatedAmount) {
      throw Exception('Target cannot be lower than the current balance');
    }
    await _clearPrimaryIfNeeded(goal.isPrimary, exceptGoalId: goal.id);
    final json = goal.toJson()..remove('created_at');
    await Supabase.instance.client
        .from('goals')
        .update(json)
        .eq('id', goal.id)
        .eq('user_id', userId);
    await fetchGoals();
  }

  Future<bool> allocate(
    String goalId,
    int amount, {
    String? note,
    String entryType = 'manual_allocation',
    String? sourceTransactionId,
  }) async {
    if (amount <= 0) throw Exception('Enter an amount greater than zero');
    final before = byId(goalId);
    final wasCompleted = before?.isCompleted ?? false;
    final previousProgress = before?.progress ?? 0;
    await Supabase.instance.client.rpc(
      'allocate_goal_funds',
      params: {
        'p_goal_id': goalId,
        'p_amount': amount,
        'p_note': note,
        'p_entry_type': entryType,
        'p_source_transaction_id': sourceTransactionId,
      },
    );
    await fetchGoals();
    final updated = byId(goalId);
    if (updated != null) {
      final crossed = const [25, 50, 75, 100]
          .where(
            (milestone) =>
                previousProgress * 100 < milestone &&
                updated.progress * 100 >= milestone,
          )
          .lastOrNull;
      if (crossed != null) {
        await NotificationService.instance.create(
          category: NotificationCategory.goal,
          type: 'goal_milestone',
          entityType: 'saving_goal',
          entityId: updated.id,
          routeName: 'goal_details',
          dedupeKey: 'goal:${updated.id}:milestone:$crossed',
          payload: {
            'goal_id': updated.id,
            'name': updated.name,
            'category': updated.category,
            'percent': crossed,
            'allocated_amount': updated.allocatedAmount,
            'target_amount': updated.targetAmount,
            'entry_type': entryType,
          },
          body:
              '${updated.name} · ${updated.allocatedAmount}/${updated.targetAmount} VND',
        );
      }
    }
    return !wasCompleted && (byId(goalId)?.isCompleted ?? false);
  }

  Future<void> withdraw(String goalId, int amount, {String? note}) async {
    if (amount <= 0) throw Exception('Enter an amount greater than zero');
    await Supabase.instance.client.rpc(
      'withdraw_goal_funds',
      params: {'p_goal_id': goalId, 'p_amount': amount, 'p_note': note},
    );
    await fetchGoals();
  }

  Future<void> saveSettings(ExpenseShortfallPolicy policy) async {
    final userId = _requireUserId();
    await Supabase.instance.client.from('goal_settings').upsert({
      'user_id': userId,
      'expense_shortfall_policy': policy == ExpenseShortfallPolicy.autoWithdraw
          ? 'auto_withdraw'
          : 'ask_each_time',
      'imported_transaction_policy': 'auto_withdraw',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await fetchGoals();
  }

  Future<void> reorderWithdrawalPriority(List<String> goalIds) async {
    final userId = _requireUserId();
    for (var index = 0; index < goalIds.length; index++) {
      await Supabase.instance.client
          .from('goals')
          .update({'withdrawal_priority': index + 1})
          .eq('id', goalIds[index])
          .eq('user_id', userId);
    }
    await fetchGoals();
  }

  Future<void> activateGoal(String goalId) async {
    final goal = byId(goalId);
    if (goal == null) return;
    await updateGoal(goal.copyWith(isPrimary: true));
  }

  Future<void> deleteGoal(String goalId) async {
    final userId = _requireUserId();
    await Supabase.instance.client
        .from('goals')
        .delete()
        .eq('id', goalId)
        .eq('user_id', userId);
    await fetchGoals();
  }

  Future<void> _clearPrimaryIfNeeded(
    bool makePrimary, {
    required String exceptGoalId,
  }) async {
    if (!makePrimary) return;
    final userId = _requireUserId();
    await Supabase.instance.client
        .from('goals')
        .update({'is_primary': false, 'is_active': false})
        .eq('user_id', userId)
        .neq('id', exceptGoalId);
  }

  String _requireUserId() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    return userId;
  }

  static T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
    for (final value in values) {
      if (test(value)) return value;
    }
    return null;
  }
}
