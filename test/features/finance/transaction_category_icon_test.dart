import 'package:finflow/features/finance/models/transaction_category.dart';
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
}

class _CustomCategoryIcon extends StatelessWidget {
  const _CustomCategoryIcon(this.category);

  final TransactionCategory category;

  @override
  Widget build(BuildContext context) => category.buildIcon(size: 24);
}
