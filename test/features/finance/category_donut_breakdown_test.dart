import 'package:finflow/features/finance/models/category_donut_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups non-zero categories below one percent for the donut only', () {
    final breakdown = CategoryDonutBreakdown({
      'Salary': 990000,
      'Other': 5000,
      'Car': 5000,
    }, 1000000);

    expect(
      breakdown.detailedEntries.map((entry) => entry.key),
      containsAll(<String>['Salary', 'Other', 'Car']),
    );
    expect(
      breakdown.chartEntries.any(
        (entry) =>
            entry.key == belowOnePercentBucketKey && entry.value == 10000,
      ),
      isTrue,
    );
    expect(
      breakdown.chartEntries.where((entry) => entry.key == 'Other'),
      isEmpty,
    );
    expect(breakdown.percentageLabel(1), '<1%');
    expect(breakdown.percentageLabel(2), '<1%');
  });

  test(
    'keeps the real Other category separate when it reaches one percent',
    () {
      final breakdown = CategoryDonutBreakdown({
        'Salary': 980000,
        'Other': 15000,
        'Car': 5000,
      }, 1000000);

      expect(
        breakdown.chartEntries.any(
          (entry) => entry.key == 'Other' && entry.value == 15000,
        ),
        isTrue,
      );
      expect(
        breakdown.chartEntries.any(
          (entry) =>
              entry.key == belowOnePercentBucketKey && entry.value == 5000,
        ),
        isTrue,
      );
      expect(breakdown.percentageLabel(1), '2%');
      expect(breakdown.percentageLabel(2), '<1%');
    },
  );

  test('does not group a category whose exact share is one percent', () {
    final breakdown = CategoryDonutBreakdown({
      'Salary': 990000,
      'Health': 10000,
    }, 1000000);

    expect(
      breakdown.chartEntries.map((entry) => entry.key),
      contains('Health'),
    );
    expect(
      breakdown.chartEntries.map((entry) => entry.key),
      isNot(contains(belowOnePercentBucketKey)),
    );
    expect(breakdown.percentageLabel(1), '1%');
  });
}
