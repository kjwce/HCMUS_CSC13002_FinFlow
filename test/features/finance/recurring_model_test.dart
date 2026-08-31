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

  test('daily schedule projects every occurrence in a seven-day range', () {
    final dates = schedule(
      frequency: RecurringFrequency.daily,
      nextOccurrence: DateTime(2026, 8, 17),
    ).occurrencesBetween(DateTime(2026, 8, 17), DateTime(2026, 8, 24));

    expect(dates.map((date) => date.day), [17, 18, 19, 20, 21, 22, 23]);
  });

  test('seven-day projection works across a month boundary', () {
    final dates = schedule(
      frequency: RecurringFrequency.daily,
      nextOccurrence: DateTime(2026, 8, 29),
    ).occurrencesBetween(DateTime(2026, 8, 29), DateTime(2026, 9, 5));

    expect(dates, List.generate(7, (index) => DateTime(2026, 8, 29 + index)));
  });

  test('stale daily occurrence advances to the current calendar day', () {
    final next = schedule(
      frequency: RecurringFrequency.daily,
      nextOccurrence: DateTime(2026, 8, 19, 9, 30),
    ).nextOccurrenceOnOrAfter(DateTime(2026, 8, 29, 18));

    expect(next, DateTime(2026, 8, 29, 9, 30));
  });

  test('stale weekly occurrence advances to the next valid weekday', () {
    final next = schedule(
      frequency: RecurringFrequency.weekly,
      nextOccurrence: DateTime(2026, 8, 19, 8),
    ).nextOccurrenceOnOrAfter(DateTime(2026, 8, 29));

    expect(next, DateTime(2026, 9, 2, 8));
  });

  test('stale monthly occurrence advances to the next valid month', () {
    final next = schedule(
      frequency: RecurringFrequency.monthly,
      nextOccurrence: DateTime(2026, 8, 19),
    ).nextOccurrenceOnOrAfter(DateTime(2026, 8, 29));

    expect(next, DateTime(2026, 9, 19));
  });
}
