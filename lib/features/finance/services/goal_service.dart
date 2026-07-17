import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/goal_model.dart';
import '../models/transaction_model.dart';

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
    if (totalBalance <= 0) return 0.0;
    return (totalBalance / goal.targetAmount).clamp(0.0, 1.0);
  }

  /// The raw saved amount = totalBalance (lifetime net balance).
  int savedAmount(int totalBalance) {
    final goal = activeGoal;
    if (goal == null) return 0;
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
