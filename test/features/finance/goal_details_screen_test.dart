import 'package:finflow/core/theme/app_colors.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/core/widgets/finflow_action_icon.dart';
import 'package:finflow/features/finance/models/goal_model.dart';
import 'package:finflow/features/finance/presentation/goal_details_screen.dart';
import 'package:finflow/features/finance/services/goal_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('goal details uses the unified left title and action menu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final goal = GoalModel(
      id: 'goal-1',
      userId: 'user-1',
      name: 'New Car',
      targetAmount: 500000000,
      createdAt: DateTime(2026, 8, 1),
      category: 'Vehicle',
      allocatedAmount: 35000000,
    );
    GoalService.instance.debugReplaceGoals([goal]);
    addTearDown(() => GoalService.instance.debugReplaceGoals(const []));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GoalDetailsScreen(goalId: 'goal-1'),
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Goal Details'));
    expect(title.style?.color, AppColors.deepEmerald);
    expect(title.style?.fontSize, 22);
    expect(tester.getTopLeft(find.text('Goal Details')).dx, lessThan(90));
    expect(find.byType(FinFlowPencilIcon), findsNothing);

    await tester.tap(find.byKey(const Key('goal-details-options-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Edit goal'), findsOneWidget);
    expect(find.text('Set as primary'), findsOneWidget);
    expect(find.text('Delete goal'), findsOneWidget);
    expect(find.byType(FinFlowPencilIcon), findsOneWidget);
    expect(find.byType(FinFlowPrimaryIcon), findsOneWidget);
    expect(find.byType(FinFlowTrashIcon), findsOneWidget);
    expect(find.byType(PopupMenuDivider), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
