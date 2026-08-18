import 'package:finflow/features/finance/models/recurring_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecurringSchedule schedule({
    required RecurringFrequency frequency,
    required DateTime nextOccurrence,
    bool isActive = true,
    bool useLastDay = false,
  }) => RecurringSchedule(
    id: 'schedule-1',
    userId: 'user-1',
    name: 'Netflix',
    category: 'Entertainment',
    amount: -300000,
    frequency: frequency,
    nextOccurrence: nextOccurrence,
    isActive: isActive,
    useLastDay: useLastDay,
  );

  test('weekly schedule projects every occurrence in the visible month', () {
    final dates = schedule(
      frequency: RecurringFrequency.weekly,
      nextOccurrence: DateTime(2026, 8, 3),
    ).occurrencesInMonth(DateTime(2026, 8));

    expect(dates.map((date) => date.day), [3, 10, 17, 24, 31]);
  });

  test('monthly schedule clamps a missing day to month end', () {
    final dates = schedule(
      frequency: RecurringFrequency.monthly,
      nextOccurrence: DateTime(2026, 1, 31),
    ).occurrencesInMonth(DateTime(2026, 2));

    expect(dates, [DateTime(2026, 2, 28)]);
  });

  test('last-day monthly schedule follows each month end', () {
    final dates = schedule(
      frequency: RecurringFrequency.monthly,
      nextOccurrence: DateTime(2026, 1, 31),
      useLastDay: true,
    ).occurrencesInMonth(DateTime(2026, 4));

    expect(dates, [DateTime(2026, 4, 30)]);
  });

  test('paused schedule does not project additional occurrences', () {
    final dates = schedule(
      frequency: RecurringFrequency.daily,
      nextOccurrence: DateTime(2026, 8, 17),
      isActive: false,
    ).occurrencesInMonth(DateTime(2026, 8));

    expect(dates, [DateTime(2026, 8, 17)]);
  });
}
