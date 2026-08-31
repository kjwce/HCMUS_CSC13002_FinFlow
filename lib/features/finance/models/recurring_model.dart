enum RecurringFrequency { daily, weekly, monthly }

enum RecurringPostingMode { review, automatic }

enum RecurringOccurrenceStatus { pending, completed, skipped, failed }

class RecurringOccurrenceRecord {
  const RecurringOccurrenceRecord({
    required this.id,
    required this.scheduleId,
    required this.occurrenceAt,
    required this.status,
    required this.amount,
  });

  factory RecurringOccurrenceRecord.fromJson(Map<String, dynamic> json) {
    return RecurringOccurrenceRecord(
      id: json['id'] as String,
      scheduleId: json['schedule_id'] as String,
      occurrenceAt: DateTime.parse(json['occurrence_at'] as String).toLocal(),
      status: RecurringOccurrenceStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => RecurringOccurrenceStatus.pending,
      ),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String scheduleId;
  final DateTime occurrenceAt;
  final RecurringOccurrenceStatus status;
  final int amount;
}

class RecurringSchedule {
  const RecurringSchedule({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.amount,
    required this.frequency,
    required this.nextOccurrence,
    required this.isActive,
    this.walletId,
    this.postingMode = RecurringPostingMode.review,
    this.reminderDays = 1,
    this.useLastDay = false,
  });

  factory RecurringSchedule.fromJson(Map<String, dynamic> json) {
    return RecurringSchedule(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'Other',
      amount: json['amount'] as int,
      frequency: RecurringFrequency.values.firstWhere(
        (value) => value.name == json['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      nextOccurrence: DateTime.parse(
        json['next_occurrence'] as String,
      ).toLocal(),
      isActive: json['is_active'] as bool? ?? true,
      walletId: json['wallet_id'] as String?,
      postingMode: json['posting_mode'] == 'automatic'
          ? RecurringPostingMode.automatic
          : RecurringPostingMode.review,
      reminderDays: (json['reminder_days'] as num?)?.toInt() ?? 1,
      useLastDay: json['use_last_day'] as bool? ?? false,
    );
  }

  final String id;
  final String userId;
  final String name;
  final String category;
  final int amount;
  final RecurringFrequency frequency;
  final DateTime nextOccurrence;
  final bool isActive;
  final String? walletId;
  final RecurringPostingMode postingMode;
  final int reminderDays;
  final bool useLastDay;

  RecurringSchedule copyWith({
    String? name,
    String? category,
    int? amount,
    RecurringFrequency? frequency,
    DateTime? nextOccurrence,
    bool? isActive,
    String? walletId,
    RecurringPostingMode? postingMode,
    int? reminderDays,
    bool? useLastDay,
  }) => RecurringSchedule(
    id: id,
    userId: userId,
    name: name ?? this.name,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    frequency: frequency ?? this.frequency,
    nextOccurrence: nextOccurrence ?? this.nextOccurrence,
    isActive: isActive ?? this.isActive,
    walletId: walletId ?? this.walletId,
    postingMode: postingMode ?? this.postingMode,
    reminderDays: reminderDays ?? this.reminderDays,
    useLastDay: useLastDay ?? this.useLastDay,
  );

  /// Returns the first occurrence whose calendar day is on or after
  /// [reference]. This repairs stale `next_occurrence` values for display,
  /// reminders, and posting without losing the original recurrence anchor
  /// used to render earlier dates in the calendar.
  DateTime nextOccurrenceOnOrAfter(DateTime reference) {
    final referenceDay = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final occurrenceDay = DateTime(
      nextOccurrence.year,
      nextOccurrence.month,
      nextOccurrence.day,
    );
    if (!occurrenceDay.isBefore(referenceDay)) return nextOccurrence;

    switch (frequency) {
      case RecurringFrequency.daily:
        return nextOccurrence.add(
          Duration(days: referenceDay.difference(occurrenceDay).inDays),
        );
      case RecurringFrequency.weekly:
        final elapsedDays = referenceDay.difference(occurrenceDay).inDays;
        final weeksToAdvance = (elapsedDays / 7).ceil();
        return nextOccurrence.add(Duration(days: weeksToAdvance * 7));
      case RecurringFrequency.monthly:
        var cursor = nextOccurrence;
        var guard = 0;
        while (DateTime(
              cursor.year,
              cursor.month,
              cursor.day,
            ).isBefore(referenceDay) &&
            guard++ < 2400) {
          cursor = _nextProjectedDate(cursor);
        }
        return cursor;
    }
  }

  /// Projects the real occurrences represented by this schedule into [month].
  /// Paused schedules keep only their stored next occurrence and do not
  /// generate future dates.
  List<DateTime> occurrencesInMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    var cursor = nextOccurrence;
    if (!isActive) {
      return !cursor.isBefore(start) && cursor.isBefore(end)
          ? [cursor]
          : const [];
    }

    if (cursor.isBefore(start)) {
      switch (frequency) {
        case RecurringFrequency.daily:
          cursor = cursor.add(Duration(days: start.difference(cursor).inDays));
          while (cursor.isBefore(start)) {
            cursor = cursor.add(const Duration(days: 1));
          }
        case RecurringFrequency.weekly:
          final weeks = start.difference(cursor).inDays ~/ 7;
          cursor = cursor.add(Duration(days: weeks * 7));
          while (cursor.isBefore(start)) {
            cursor = cursor.add(const Duration(days: 7));
          }
        case RecurringFrequency.monthly:
          var guard = 0;
          while (cursor.isBefore(start) && guard++ < 2400) {
            cursor = _nextProjectedDate(cursor);
          }
      }
    }

    final result = <DateTime>[];
    var guard = 0;
    while (cursor.isBefore(end) && guard++ < 64) {
      if (!cursor.isBefore(start)) result.add(cursor);
      cursor = _nextProjectedDate(cursor);
    }
    return result;
  }

  /// Projects active occurrences into an arbitrary half-open date range.
  /// The start is included and the end is excluded, matching a seven-day
  /// calendar such as Monday through Sunday.
  List<DateTime> occurrencesBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    if (!isActive || !startInclusive.isBefore(endExclusive)) return const [];

    final result = <DateTime>[];
    var month = DateTime(startInclusive.year, startInclusive.month);
    var guard = 0;
    while (month.isBefore(endExclusive) && guard++ < 120) {
      result.addAll(
        occurrencesInMonth(month).where(
          (date) =>
              !date.isBefore(startInclusive) && date.isBefore(endExclusive),
        ),
      );
      month = DateTime(month.year, month.month + 1);
    }
    result.sort();
    return result;
  }

  DateTime occurrenceAfter(DateTime occurrence) =>
      _nextProjectedDate(occurrence);

  DateTime _nextProjectedDate(DateTime date) => switch (frequency) {
    RecurringFrequency.daily => date.add(const Duration(days: 1)),
    RecurringFrequency.weekly => date.add(const Duration(days: 7)),
    RecurringFrequency.monthly =>
      useLastDay
          ? DateTime(date.year, date.month + 2, 0, date.hour, date.minute)
          : _sameDayInNextMonth(date),
  };

  DateTime _sameDayInNextMonth(DateTime date) {
    final first = DateTime(date.year, date.month + 1);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(
      first.year,
      first.month,
      date.day.clamp(1, lastDay),
      date.hour,
      date.minute,
    );
  }
}

class RecurringOccurrence {
  const RecurringOccurrence({required this.schedule, required this.date});

  final RecurringSchedule schedule;
  final DateTime date;
}
