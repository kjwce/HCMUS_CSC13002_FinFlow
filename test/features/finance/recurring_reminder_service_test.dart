import 'package:finflow/features/finance/models/recurring_model.dart';
import 'package:finflow/features/finance/models/recurring_notification_action.dart';
import 'package:finflow/features/finance/services/recurring_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecurringSchedule schedule({
    required String id,
    required DateTime occurrence,
    int reminderDays = 1,
  }) => RecurringSchedule(
    id: id,
    userId: 'user-1',
    name: 'Netflix',
    category: 'Entertainment',
    amount: -260000,
    frequency: RecurringFrequency.monthly,
    nextOccurrence: occurrence,
    isActive: true,
    reminderDays: reminderDays,
  );

  test('payload round-trips and maps quick actions', () {
    final occurrence = DateTime(2026, 8, 17, 9);
    final original = RecurringNotificationAction(
      scheduleId: 'schedule-1',
      occurrenceAt: occurrence,
      postingMode: 'review',
      type: RecurringNotificationActionType.open,
    );

    final parsed = RecurringNotificationAction.fromPayload(
      original.toPayload(),
      actionId: 'recurring_review',
    );

    expect(parsed.scheduleId, 'schedule-1');
    expect(parsed.occurrenceAt, occurrence);
    expect(parsed.postingMode, 'review');
    expect(parsed.type, RecurringNotificationActionType.review);
  });

  test('notification id is stable per schedule occurrence', () {
    final occurrence = DateTime.utc(2026, 8, 17);
    final first = RecurringReminderService.notificationIdFor(
      'schedule-1',
      occurrence,
    );

    expect(
      RecurringReminderService.notificationIdFor('schedule-1', occurrence),
      first,
    );
    expect(
      RecurringReminderService.notificationIdFor(
        'schedule-1',
        occurrence.add(const Duration(days: 1)),
      ),
      isNot(first),
    );
  });

  test('date-only occurrence is delivered at 9 AM minus reminder days', () {
    final result = RecurringReminderService.reminderTimeFor(
      schedule(
        id: 'schedule-1',
        occurrence: DateTime(2026, 8, 20),
        reminderDays: 2,
      ),
    );

    expect(result, DateTime(2026, 8, 18, 9));
  });

  test('explicit occurrence time is preserved', () {
    final result = RecurringReminderService.reminderTimeFor(
      schedule(
        id: 'schedule-1',
        occurrence: DateTime(2026, 8, 20, 18, 30),
        reminderDays: 1,
      ),
    );

    expect(result, DateTime(2026, 8, 19, 18, 30));
  });
}
