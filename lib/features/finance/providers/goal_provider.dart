import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/goal_service.dart';

/// Expose the GoalService singleton as a Riverpod provider.
final goalServiceProvider = Provider<GoalService>((ref) {
  return GoalService.instance;
});
