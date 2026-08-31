import 'package:finflow/features/finance/models/transaction_category.dart';
import 'package:finflow/features/finance/presentation/widgets/goal_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all built-in categories render their SVG assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: TransactionCategory.all
                .map((category) => category.buildIcon(size: 24))
                .toList(growable: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(SvgPicture),
      findsNWidgets(TransactionCategory.all.length),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom categories keep the Material icon fallback', (
    tester,
  ) async {
    const category = TransactionCategory(
      key: 'Custom',
      label: 'Custom',
      icon: Icons.coffee,
      color: Colors.brown,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: _CustomCategoryIcon(category))),
      ),
    );

    expect(find.byIcon(Icons.coffee), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('legacy goal categories reuse the new SVG set', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              goalIconWidgetFor('Vehicle', color: Colors.teal, size: 24),
              goalIconWidgetFor('Home', color: Colors.teal, size: 24),
              goalIconWidgetFor('Tech Upgrade', color: Colors.teal, size: 24),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsNWidgets(3));
  });

  testWidgets('all goal category SVG assets are bundled and renderable', (
    tester,
  ) async {
    const names = [
      'emergency_fund',
      'home',
      'vehicle',
      'travel',
      'education',
      'technology',
      'wedding',
      'family',
      'health',
      'business',
      'investment',
      'retirement',
      'shopping',
      'other_goal',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: names
                .map(
                  (name) => SvgPicture.asset(
                    'assets/icons/categories/duotone/goals/$name.svg',
                    width: 24,
                    height: 24,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsNWidgets(names.length));
    expect(tester.takeException(), isNull);
  });
}

class _CustomCategoryIcon extends StatelessWidget {
  const _CustomCategoryIcon(this.category);

  final TransactionCategory category;

  @override
  Widget build(BuildContext context) => category.buildIcon(size: 24);
}
