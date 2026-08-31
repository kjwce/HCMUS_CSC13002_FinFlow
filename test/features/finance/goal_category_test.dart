import 'package:finflow/features/finance/models/goal_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a dedicated fourteen-item goal catalogue', () {
    expect(GoalCategory.all, hasLength(14));
    expect(GoalCategory.all.first.key, 'Emergency Fund');
    expect(GoalCategory.all.last.key, 'Other Goal');
    expect(
      GoalCategory.all.every(
        (category) => category.assetPath.contains('/duotone/goals/'),
      ),
      isTrue,
    );
  });

  test('maps categories saved by the old goal form', () {
    expect(GoalCategory.canonicalKey('Car'), 'Vehicle');
    expect(GoalCategory.canonicalKey('Food'), 'Family');
    expect(GoalCategory.canonicalKey('Tech Upgrade'), 'Technology');
    expect(GoalCategory.canonicalKey('Fitness'), 'Health');
    expect(GoalCategory.canonicalKey('Something custom'), 'Other Goal');
  });
}
