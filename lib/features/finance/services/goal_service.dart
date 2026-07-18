import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/goal_model.dart';

/// Service handling saving-goal CRUD via Supabase.
/// Follows the same pattern as TransactionService.
class GoalService extends ChangeNotifier {
  GoalService._();

  static final GoalService instance = GoalService._();
  List<GoalModel> _goals = [];

  List<GoalModel> get goals => List.unmodifiable(_goals);

  /// The currently active goal (if any).
  GoalModel? get activeGoal {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      return _goals.firstWhere((g) => g.userId == userId && g.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Compute progress toward the active goal.
  /// [totalBalance] = lifetime income - lifetime expense (from TransactionService).
  double progressRatio(int totalBalance) {
    final goal = activeGoal;
    if (goal == null) return 0.0;
    return progressRatioFor(goal, totalBalance);
  }

  /// Compute progress for any goal in the user's goal list.
  double progressRatioFor(GoalModel goal, int totalBalance) {
    if (totalBalance <= 0) return 0.0;
    return (totalBalance / goal.targetAmount).clamp(0.0, 1.0);
  }

  /// The raw saved amount = totalBalance (lifetime net balance).
  int savedAmount(int totalBalance) {
    final goal = activeGoal;
    if (goal == null) return 0;
    return savedAmountFor(goal, totalBalance);
  }

  /// The current saved amount used by an individual goal card.
  ///
  /// Goals currently share the app's lifetime net balance, preserving the
  /// existing saving-goal calculation while allowing all goals to be listed.
  int savedAmountFor(GoalModel goal, int totalBalance) {
    return totalBalance < 0 ? 0 : totalBalance;
  }

  Future<void> fetchGoals() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _goals = [];
      notifyListeners();
      return;
    }
    final res = await Supabase.instance.client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    _goals = (res as List)
        .map((g) => GoalModel.fromJson(g as Map<String, dynamic>))
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> setGoal(GoalModel goal) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Deactivate any existing active goal
    final current = activeGoal;
    if (current != null) {
      await Supabase.instance.client
          .from('goals')
          .update({'is_active': false})
          .eq('id', current.id)
          .eq('user_id', userId);
    }

    // Insert new goal
    await Supabase.instance.client.from('goals').insert(goal.toJson());
    await fetchGoals();
  }

  /// Update the editable fields of an existing goal.
  Future<void> updateGoal(GoalModel goal) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('goals')
        .update({'name': goal.name, 'target_amount': goal.targetAmount})
        .eq('id', goal.id)
        .eq('user_id', userId);
    await fetchGoals();
  }

  /// Make [goalId] the goal highlighted on Home without deleting other goals.
  Future<void> activateGoal(String goalId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('goals')
        .update({'is_active': false})
        .eq('user_id', userId);
    await Supabase.instance.client
        .from('goals')
        .update({'is_active': true})
        .eq('id', goalId)
        .eq('user_id', userId);
    await fetchGoals();
  }

  Future<void> deleteGoal(String goalId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('goals')
        .delete()
        .eq('id', goalId)
        .eq('user_id', userId);
    await fetchGoals();
  }
}
