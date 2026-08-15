import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_budget_model.dart';

class CategoryBudgetService extends ChangeNotifier {
  CategoryBudgetService._();
  static final instance = CategoryBudgetService._();

  List<CategoryBudgetModel> _budgets = const [];
  List<CategoryBudgetModel> get budgets => List.unmodifiable(_budgets);

  Future<void> fetchCurrentMonth() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _budgets = const [];
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    final response = await Supabase.instance.client
        .from('budgets')
        .select()
        .eq('user_id', userId)
        .eq('month', now.month)
        .eq('year', now.year)
        .order('limit_amount', ascending: false);
    _budgets = (response as List)
        .map(
          (json) => CategoryBudgetModel.fromJson(json as Map<String, dynamic>),
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> save(String category, int limitAmount) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    if (limitAmount <= 0) throw Exception('Enter a positive budget limit');
    final now = DateTime.now();
    await Supabase.instance.client.from('budgets').upsert({
      'user_id': userId,
      'category': category,
      'limit_amount': limitAmount,
      'month': now.month,
      'year': now.year,
    }, onConflict: 'user_id,category,month,year');
    await fetchCurrentMonth();
  }

  Future<void> delete(String id) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await Supabase.instance.client
        .from('budgets')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
    await fetchCurrentMonth();
  }
}
