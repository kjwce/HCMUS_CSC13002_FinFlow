import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/shell/finflow_app.dart';
import '../../community/services/notification_service.dart';
import '../models/recurring_notification_action.dart';
import '../presentation/recurring_screens.dart';
import 'recurring_service.dart';

class RecurringNotificationActionCoordinator {
  RecurringNotificationActionCoordinator._();

  static Future<void> handle(
    RecurringNotificationAction action,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    final service = RecurringService.instance;
    if (service.schedules.isEmpty) await service.fetch();
    final schedule = service.findById(action.scheduleId);
    if (schedule == null) return;

    final navigator = await _waitForNavigator(navigatorKey);
    if (navigator == null) return;

    switch (action.type) {
      case RecurringNotificationActionType.review:
        await ReviewOccurrenceSheet.show(
          navigator.overlay?.context ?? navigator.context,
          schedule,
        );
      case RecurringNotificationActionType.markPaid:
        final expected = action.occurrenceAt.toUtc();
        final current = schedule.nextOccurrence.toUtc();
        if (expected.isAtSameMomentAs(current)) {
          await service.recordOccurrence(schedule);
          final context = navigator.overlay?.context;
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${schedule.name} marked as paid')),
            );
          }
        }
      case RecurringNotificationActionType.viewDetails:
      case RecurringNotificationActionType.open:
        await navigator.pushNamed(
          AppRoutes.recurringDetails,
          arguments: schedule.id,
        );
    }

    try {
      await Supabase.instance.client
          .from('recurring_notifications')
          .update({'is_read': true})
          .eq(
            'id',
            'recurring:${schedule.id}:${action.occurrenceAt.toUtc().toIso8601String()}',
          );
      await NotificationService.instance.fetchNotifications();
    } catch (_) {}
  }

  static Future<NavigatorState?> _waitForNavigator(
    GlobalKey<NavigatorState> key,
  ) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      final navigator = key.currentState;
      if (navigator != null) return navigator;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }
}
