import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../community/models/notification_model.dart';
import '../../community/services/notification_service.dart';
import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import 'recurring_reminder_service.dart';
import 'transaction_service.dart';

class RecurringService extends ChangeNotifier {
  RecurringService._();
  static final instance = RecurringService._();

  List<RecurringSchedule> _schedules = const [];
  final Map<String, List<RecurringOccurrenceRecord>> _historyBySchedule = {};
  List<RecurringSchedule> get schedules => List.unmodifiable(_schedules);
  List<RecurringSchedule> get activeSchedules =>
      _schedules.where((item) => item.isActive).toList(growable: false);
  List<RecurringSchedule> get upcoming =>
      upcomingWithin(const Duration(days: 7));
  List<RecurringOccurrence> get upcomingOccurrences =>
      upcomingOccurrencesWithin(const Duration(days: 7));

  @visibleForTesting
  void debugReplaceSchedules(List<RecurringSchedule> schedules) {
    _schedules = List.unmodifiable(schedules);
    notifyListeners();
  }

  @visibleForTesting
  void debugReplaceOccurrenceHistory(
    String scheduleId,
    List<RecurringOccurrenceRecord> history,
  ) {
    _historyBySchedule[scheduleId] = List.unmodifiable(history);
    notifyListeners();
  }

  List<RecurringOccurrenceRecord> occurrenceHistoryFor(String scheduleId) =>
      List.unmodifiable(_historyBySchedule[scheduleId] ?? const []);

  Future<void> fetchOccurrenceHistory(String scheduleId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('recurring_notifications')
          .select('id, schedule_id, occurrence_at, status, amount')
          .eq('user_id', userId)
          .eq('schedule_id', scheduleId)
          .order('occurrence_at', ascending: false)
          .limit(50);
      _historyBySchedule[scheduleId] = (response as List)
          .map(
            (item) => RecurringOccurrenceRecord.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .where((item) => item.status != RecurringOccurrenceStatus.pending)
          .toList(growable: false);
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load recurring occurrence history: $error');
    }
  }

  List<RecurringSchedule> upcomingWithin(Duration window) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(window);
    return activeSchedules
        .where(
          (item) =>
              !item.nextOccurrence.isBefore(today) &&
              item.nextOccurrence.isBefore(end),
        )
        .toList(growable: false);
  }

  List<RecurringOccurrence> upcomingOccurrencesWithin(
    Duration window, {
    DateTime? from,
  }) {
    final now = from ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(window);
    final occurrences = <RecurringOccurrence>[
      for (final schedule in activeSchedules)
        for (final date in schedule.occurrencesBetween(start, end))
          RecurringOccurrence(schedule: schedule, date: date),
    ];
    occurrences.sort((a, b) => a.date.compareTo(b.date));
    return occurrences;
  }

  Future<void> fetch() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _schedules = const [];
      notifyListeners();
      return;
    }
    final response = await Supabase.instance.client
        .from('recurring_schedules')
        .select()
        .eq('user_id', userId)
        .order('next_occurrence');
    _schedules = (response as List)
        .map((item) => RecurringSchedule.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> save(RecurringSchedule schedule) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await Supabase.instance.client.from('recurring_schedules').upsert({
      'id': schedule.id,
      'user_id': userId,
      'name': schedule.name,
      'category': schedule.category,
      'amount': schedule.amount,
      'frequency': schedule.frequency.name,
      'next_occurrence': schedule.nextOccurrence.toIso8601String(),
      'is_active': schedule.isActive,
      'wallet_id': schedule.walletId,
      'posting_mode': schedule.postingMode.name,
      'reminder_days': schedule.reminderDays,
      'use_last_day': schedule.useLastDay,
    });
    await fetch();
    final saved = _schedules
        .where((item) => item.id == schedule.id)
        .firstOrNull;
    if (saved != null) {
      if (RecurringReminderService.instance.isEnabled &&
          !await RecurringReminderService.instance.requestPermission()) {
        await RecurringReminderService.instance.setEnabled(false);
      }
      await RecurringReminderService.instance.syncSchedule(saved);
    }
  }

  Future<void> delete(String id) async {
    await RecurringReminderService.instance.removeSchedule(id);
    await Supabase.instance.client
        .from('recurring_schedules')
        .delete()
        .eq('id', id);
    await fetch();
  }

  Future<void> toggle(RecurringSchedule schedule) =>
      save(schedule.copyWith(isActive: !schedule.isActive));

  Future<void> recordOccurrence(
    RecurringSchedule schedule, {
    int? amount,
  }) async {
    final effectiveOccurrence = schedule.nextOccurrenceOnOrAfter(
      DateTime.now(),
    );
    final effectiveSchedule = schedule.copyWith(
      nextOccurrence: effectiveOccurrence,
    );
    final actualAmount = amount ?? schedule.amount;
    try {
      await TransactionService.instance.add(
        TransactionModel(
          id: 'recurring-${schedule.id}-${DateTime.now().microsecondsSinceEpoch}',
          userId: schedule.userId,
          name: schedule.name,
          category: schedule.category,
          amount: actualAmount,
          date: effectiveOccurrence,
          walletId: schedule.walletId,
        ),
      );
      await RecurringReminderService.instance.markOccurrenceCompleted(
        effectiveSchedule,
      );
      await save(
        schedule.copyWith(nextOccurrence: _nextDate(effectiveSchedule)),
      );
      await NotificationService.instance.create(
        category: NotificationCategory.recurring,
        type: 'recurring_auto_success',
        entityType: 'recurring_schedule',
        entityId: schedule.id,
        routeName: 'recurring_details',
        dedupeKey:
            'recurring:${schedule.id}:${effectiveOccurrence.toIso8601String()}:success',
        payload: {
          'schedule_id': schedule.id,
          'name': schedule.name,
          'category': schedule.category,
          'amount': actualAmount,
          'occurrence_at': effectiveOccurrence.toIso8601String(),
        },
        body: '${schedule.name} · ${actualAmount.abs()} VND',
      );
      await fetchOccurrenceHistory(schedule.id);
    } catch (error) {
      await RecurringReminderService.instance.markOccurrenceFailed(
        effectiveSchedule.copyWith(amount: actualAmount),
      );
      await NotificationService.instance.create(
        category: NotificationCategory.recurring,
        type: 'recurring_failed',
        priority: NotificationPriority.high,
        actionRequired: true,
        entityType: 'recurring_schedule',
        entityId: schedule.id,
        routeName: 'recurring_details',
        dedupeKey:
            'recurring:${schedule.id}:${effectiveOccurrence.toIso8601String()}:failed',
        payload: {
          'schedule_id': schedule.id,
          'name': schedule.name,
          'category': schedule.category,
          'amount': actualAmount,
          'occurrence_at': effectiveOccurrence.toIso8601String(),
        },
        body: '${schedule.name} · ${actualAmount.abs()} VND',
      );
      await fetchOccurrenceHistory(schedule.id);
      rethrow;
    }
  }

  /// Skips the current due occurrence without creating a transaction, then
  /// advances the schedule so it cannot repeatedly ask for the same date.
  Future<void> skipOccurrence(RecurringSchedule schedule) async {
    final effectiveOccurrence = schedule.nextOccurrenceOnOrAfter(
      DateTime.now(),
    );
    final effectiveSchedule = schedule.copyWith(
      nextOccurrence: effectiveOccurrence,
    );
    await RecurringReminderService.instance.markOccurrenceSkipped(
      effectiveSchedule,
    );
    await NotificationService.instance.resolveRecurringActions(schedule.id);
    await save(schedule.copyWith(nextOccurrence: _nextDate(effectiveSchedule)));
    await NotificationService.instance.create(
      category: NotificationCategory.recurring,
      type: 'recurring_skipped',
      entityType: 'recurring_schedule',
      entityId: schedule.id,
      routeName: 'recurring_details',
      dedupeKey:
          'recurring:${schedule.id}:${effectiveOccurrence.toIso8601String()}:skipped',
      payload: {
        'schedule_id': schedule.id,
        'name': schedule.name,
        'category': schedule.category,
        'amount': schedule.amount,
        'occurrence_at': effectiveOccurrence.toIso8601String(),
      },
      body: '${schedule.name} · ${schedule.amount.abs()} VND',
    );
    await fetchOccurrenceHistory(schedule.id);
  }

  RecurringSchedule? findById(String id) {
    for (final schedule in _schedules) {
      if (schedule.id == id) return schedule;
    }
    return null;
  }

  DateTime _nextDate(RecurringSchedule schedule) {
    final date = schedule.nextOccurrence;
    return switch (schedule.frequency) {
      RecurringFrequency.daily => date.add(const Duration(days: 1)),
      RecurringFrequency.weekly => date.add(const Duration(days: 7)),
      RecurringFrequency.monthly =>
        schedule.useLastDay ? _lastDayNextMonth(date) : _sameDayNextMonth(date),
    };
  }

  DateTime _lastDayNextMonth(DateTime date) {
    final next = DateTime(date.year, date.month + 2, 0);
    return DateTime(next.year, next.month, next.day, date.hour, date.minute);
  }

  DateTime _sameDayNextMonth(DateTime date) {
    final firstOfNextMonth = DateTime(date.year, date.month + 1, 1);
    final lastDay = DateTime(
      firstOfNextMonth.year,
      firstOfNextMonth.month + 1,
      0,
    ).day;
    return DateTime(
      firstOfNextMonth.year,
      firstOfNextMonth.month,
      date.day.clamp(1, lastDay),
      date.hour,
      date.minute,
    );
  }
}
