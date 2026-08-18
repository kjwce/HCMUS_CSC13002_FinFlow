import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import 'recurring_reminder_service.dart';
import 'transaction_service.dart';

class RecurringService extends ChangeNotifier {
  RecurringService._();
  static final instance = RecurringService._();

  List<RecurringSchedule> _schedules = const [];
  List<RecurringSchedule> get schedules => List.unmodifiable(_schedules);
  List<RecurringSchedule> get activeSchedules =>
      _schedules.where((item) => item.isActive).toList(growable: false);
  List<RecurringSchedule> get upcoming =>
      upcomingWithin(const Duration(days: 7));

  @visibleForTesting
  void debugReplaceSchedules(List<RecurringSchedule> schedules) {
    _schedules = List.unmodifiable(schedules);
    notifyListeners();
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
    await TransactionService.instance.add(
      TransactionModel(
        id: 'recurring-${schedule.id}-${DateTime.now().microsecondsSinceEpoch}',
        userId: schedule.userId,
        name: schedule.name,
        category: schedule.category,
        amount: amount ?? schedule.amount,
        date: schedule.nextOccurrence,
        walletId: schedule.walletId,
      ),
    );
    await RecurringReminderService.instance.markOccurrenceCompleted(schedule);
    await save(schedule.copyWith(nextOccurrence: _nextDate(schedule)));
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
