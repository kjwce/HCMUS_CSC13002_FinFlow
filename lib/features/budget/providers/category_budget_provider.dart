import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/category_budget_service.dart';

final categoryBudgetServiceProvider = Provider<CategoryBudgetService>((ref) {
  return CategoryBudgetService.instance;
});
