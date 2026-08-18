import 'dart:convert';

enum RecurringNotificationActionType { open, review, viewDetails, markPaid }

class RecurringNotificationAction {
  const RecurringNotificationAction({
    required this.scheduleId,
    required this.occurrenceAt,
    required this.postingMode,
    required this.type,
  });

  factory RecurringNotificationAction.fromPayload(
    String payload, {
    String? actionId,
  }) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final type = switch (actionId) {
      'recurring_review' => RecurringNotificationActionType.review,
      'recurring_view_details' => RecurringNotificationActionType.viewDetails,
      'recurring_mark_paid' => RecurringNotificationActionType.markPaid,
      _ => RecurringNotificationActionType.open,
    };
    return RecurringNotificationAction(
      scheduleId: json['schedule_id'] as String,
      occurrenceAt: DateTime.parse(json['occurrence_at'] as String).toLocal(),
      postingMode: json['posting_mode'] as String? ?? 'review',
      type: type,
    );
  }

  final String scheduleId;
  final DateTime occurrenceAt;
  final String postingMode;
  final RecurringNotificationActionType type;

  String toPayload() => jsonEncode({
    'kind': 'recurring',
    'schedule_id': scheduleId,
    'occurrence_at': occurrenceAt.toUtc().toIso8601String(),
    'posting_mode': postingMode,
  });

  Map<String, dynamic> toPendingJson() => {
    'payload': toPayload(),
    'action_id': switch (type) {
      RecurringNotificationActionType.review => 'recurring_review',
      RecurringNotificationActionType.viewDetails => 'recurring_view_details',
      RecurringNotificationActionType.markPaid => 'recurring_mark_paid',
      RecurringNotificationActionType.open => '',
    },
  };
}
