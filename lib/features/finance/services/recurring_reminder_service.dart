import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/i18n/app_language.dart';
import '../models/recurring_model.dart';
import '../models/recurring_notification_action.dart';

const _notificationsPreferenceKey = 'finflow_push_notifications';
const _pendingActionPreferenceKey = 'finflow_pending_recurring_action';
const _scheduledReminderKeysPreferenceKey =
    'finflow_scheduled_recurring_reminder_keys';
const _channelId = 'finflow_recurring_reminders';
const _reviewCategory = 'finflow_recurring_review';
const _automaticCategory = 'finflow_recurring_automatic';

@pragma('vm:entry-point')
Future<void> recurringNotificationTapBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  await RecurringReminderService.persistResponse(response);
}

class RecurringReminderService extends ChangeNotifier {
  RecurringReminderService._();

  static final instance = RecurringReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _enabled = true;
  Future<void> Function(RecurringNotificationAction action)? _actionHandler;

  bool get isEnabled => _enabled;

  static int notificationIdFor(String scheduleId, DateTime occurrence) {
    final input = '$scheduleId|${occurrence.toUtc().toIso8601String()}';
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static String historyIdFor(String scheduleId, DateTime occurrence) =>
      'recurring:$scheduleId:${occurrence.toUtc().toIso8601String()}';

  static DateTime reminderTimeFor(RecurringSchedule schedule) {
    final occurrence = schedule.nextOccurrence;
    final hasExplicitTime = occurrence.hour != 0 || occurrence.minute != 0;
    final delivery = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
      hasExplicitTime ? occurrence.hour : 9,
      hasExplicitTime ? occurrence.minute : 0,
    );
    return delivery.subtract(Duration(days: schedule.reminderDays));
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_notificationsPreferenceKey) ?? true;

    try {
      tz_data.initializeTimeZones();
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (error) {
      debugPrint('Recurring notification timezone fallback: $error');
      tz.setLocalLocation(tz.UTC);
    }

    final reviewAction = DarwinNotificationAction.plain(
      'recurring_review',
      AppStrings.choose('Review', 'Xem lại'),
      options: {DarwinNotificationActionOption.foreground},
    );
    final viewAction = DarwinNotificationAction.plain(
      'recurring_view_details',
      AppStrings.choose('View details', 'Xem chi tiết'),
      options: {DarwinNotificationActionOption.foreground},
    );
    final paidAction = DarwinNotificationAction.plain(
      'recurring_mark_paid',
      AppStrings.choose('Mark as paid', 'Đánh dấu đã trả'),
      options: {DarwinNotificationActionOption.foreground},
    );
    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('ic_notification_finflow'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(_reviewCategory, actions: [reviewAction]),
          DarwinNotificationCategory(
            _automaticCategory,
            actions: [viewAction, paidAction],
          ),
        ],
      ),
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleResponse,
        onDidReceiveBackgroundNotificationResponse:
            recurringNotificationTapBackground,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        await persistResponse(response);
      }
    } catch (error) {
      // Unit tests and unsupported desktop targets do not register the plugin.
      debugPrint('Recurring notification initialization skipped: $error');
    }
    _initialized = true;
  }

  void bindActionHandler(
    Future<void> Function(RecurringNotificationAction action) handler,
  ) {
    _actionHandler = handler;
  }

  Future<void> processPendingAction() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_pendingActionPreferenceKey);
    if (raw == null || _actionHandler == null) return;
    await preferences.remove(_pendingActionPreferenceKey);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final action = RecurringNotificationAction.fromPayload(
        json['payload'] as String,
        actionId: json['action_id'] as String?,
      );
      await _actionHandler!(action);
    } catch (error) {
      debugPrint('Invalid pending recurring action: $error');
    }
  }

  static Future<void> persistResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      if (decoded['kind'] != 'recurring') return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _pendingActionPreferenceKey,
        jsonEncode({'payload': payload, 'action_id': response.actionId ?? ''}),
      );
    } catch (error) {
      debugPrint('Could not persist recurring action: $error');
    }
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    await persistResponse(response);
    await processPendingAction();
  }

  Future<bool> requestPermission() async {
    await initialize();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final androidGranted = await android?.requestNotificationsPermission();
      final iosGranted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final notificationsGranted = androidGranted ?? iosGranted ?? true;
      if (!notificationsGranted) return false;

      // Android 12+ treats exact alarms as separate special access. Recurring
      // reminders need this so AlarmManager can deliver them while the Flutter
      // process is terminated or the device is idle.
      final exactAlarmsGranted = await android?.requestExactAlarmsPermission();
      return exactAlarmsGranted ?? true;
    } catch (error) {
      debugPrint('Could not request notification permission: $error');
      return false;
    }
  }

  Future<bool> setEnabled(
    bool enabled, {
    Iterable<RecurringSchedule> schedules = const [],
  }) async {
    await initialize();
    if (enabled && !await requestPermission()) return false;
    _enabled = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsPreferenceKey, enabled);
    if (enabled) {
      await preferences.remove(_scheduledReminderKeysPreferenceKey);
      await syncAll(schedules);
    } else {
      await cancelAllRecurring();
    }
    notifyListeners();
    return true;
  }

  Future<void> syncAll(Iterable<RecurringSchedule> schedules) async {
    await initialize();
    final active = schedules.where((schedule) => schedule.isActive).toList();
    final activeIds = active.map((schedule) => schedule.id).toSet();
    await _cancelPendingWhere((payload) {
      final action = _tryParsePayload(payload);
      return action != null && !activeIds.contains(action.scheduleId);
    });
    for (final schedule in schedules) {
      await syncSchedule(schedule);
    }
  }

  Future<void> syncSchedule(RecurringSchedule schedule) async {
    await initialize();
    final effectiveSchedule = schedule.isActive
        ? schedule.copyWith(
            nextOccurrence: schedule.nextOccurrenceOnOrAfter(DateTime.now()),
          )
        : schedule;
    await cancelSchedule(effectiveSchedule.id);
    await _syncHistory(effectiveSchedule);
    if (!_enabled || !effectiveSchedule.isActive) return;

    final action = RecurringNotificationAction(
      scheduleId: effectiveSchedule.id,
      occurrenceAt: effectiveSchedule.nextOccurrence,
      postingMode: effectiveSchedule.postingMode.name,
      type: RecurringNotificationActionType.open,
    );
    final id = notificationIdFor(
      effectiveSchedule.id,
      effectiveSchedule.nextOccurrence,
    );
    final reminderAt = reminderTimeFor(effectiveSchedule);
    final now = DateTime.now();
    if (effectiveSchedule.nextOccurrence.isBefore(
      DateTime(now.year, now.month, now.day),
    )) {
      return;
    }

    final details = _detailsFor(effectiveSchedule);
    if (reminderAt.isAfter(now)) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: _titleFor(effectiveSchedule),
          body: _bodyFor(effectiveSchedule),
          scheduledDate: tz.TZDateTime.from(reminderAt, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: action.toPayload(),
        );
        await _rememberScheduledKey(
          historyIdFor(effectiveSchedule.id, effectiveSchedule.nextOccurrence),
        );
      } catch (error) {
        debugPrint('Could not schedule recurring reminder: $error');
      }
      return;
    }

    final key = historyIdFor(
      effectiveSchedule.id,
      effectiveSchedule.nextOccurrence,
    );
    if (await _wasScheduled(key)) return;
    try {
      await _plugin.show(
        id: id,
        title: _titleFor(effectiveSchedule),
        body: _bodyFor(effectiveSchedule),
        notificationDetails: details,
        payload: action.toPayload(),
      );
      await _rememberScheduledKey(key);
    } catch (error) {
      debugPrint('Could not show recurring reminder: $error');
    }
  }

  Future<void> cancelSchedule(String scheduleId) => _cancelPendingWhere(
    (payload) => _tryParsePayload(payload)?.scheduleId == scheduleId,
  );

  Future<void> cancelAllRecurring() async {
    await _cancelPendingWhere((payload) => _tryParsePayload(payload) != null);
    try {
      // Recurring is currently FinFlow's only Flutter-scheduled notification
      // source. This also removes an already-delivered reminder on logout.
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Could not clear recurring notifications: $error');
    }
  }

  Future<void> removeSchedule(String scheduleId) async {
    await cancelSchedule(scheduleId);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('recurring_notifications')
          .delete()
          .eq('user_id', userId)
          .eq('schedule_id', scheduleId)
          .eq('status', 'pending');
    } catch (error) {
      debugPrint('Could not remove future recurring notifications: $error');
    }
  }

  Future<void> markOccurrenceCompleted(RecurringSchedule schedule) async {
    await _setOccurrenceStatus(schedule, 'completed');
  }

  Future<void> markOccurrenceSkipped(RecurringSchedule schedule) async {
    await _setOccurrenceStatus(schedule, 'skipped');
  }

  Future<void> markOccurrenceFailed(RecurringSchedule schedule) async {
    await _setOccurrenceStatus(schedule, 'failed');
  }

  Future<void> _setOccurrenceStatus(
    RecurringSchedule schedule,
    String status,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('recurring_notifications').upsert({
        'id': historyIdFor(schedule.id, schedule.nextOccurrence),
        'user_id': userId,
        'schedule_id': schedule.id,
        'title': _titleFor(schedule),
        'body': _bodyFor(schedule),
        'posting_mode': schedule.postingMode.name,
        'amount': schedule.amount,
        'occurrence_at': schedule.nextOccurrence.toUtc().toIso8601String(),
        'scheduled_for': reminderTimeFor(schedule).toUtc().toIso8601String(),
        'status': status,
        'is_read': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      debugPrint('Could not set recurring occurrence to $status: $error');
    }
  }

  Future<void> _syncHistory(RecurringSchedule schedule) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final client = Supabase.instance.client;
      await client
          .from('recurring_notifications')
          .delete()
          .eq('user_id', userId)
          .eq('schedule_id', schedule.id)
          .eq('status', 'pending')
          .neq('id', historyIdFor(schedule.id, schedule.nextOccurrence));
      if (!schedule.isActive) return;
      await client.from('recurring_notifications').upsert({
        'id': historyIdFor(schedule.id, schedule.nextOccurrence),
        'user_id': userId,
        'schedule_id': schedule.id,
        'title': _titleFor(schedule),
        'body': _bodyFor(schedule),
        'posting_mode': schedule.postingMode.name,
        'amount': schedule.amount,
        'occurrence_at': schedule.nextOccurrence.toUtc().toIso8601String(),
        'scheduled_for': reminderTimeFor(schedule).toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      // Migration 030 may not have been deployed yet. Saving the schedule must
      // still succeed; the migration can then be applied without data loss.
      debugPrint('Could not sync recurring notification history: $error');
    }
  }

  Future<void> _cancelPendingWhere(bool Function(String payload) test) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final payload = request.payload;
        if (payload != null && test(payload)) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (error) {
      debugPrint('Could not inspect recurring notifications: $error');
    }
  }

  RecurringNotificationAction? _tryParsePayload(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      if (json['kind'] != 'recurring') return null;
      return RecurringNotificationAction.fromPayload(payload);
    } catch (_) {
      return null;
    }
  }

  NotificationDetails _detailsFor(RecurringSchedule schedule) {
    final review = schedule.postingMode == RecurringPostingMode.review;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        AppStrings.choose('Recurring reminders', 'Nhắc giao dịch định kỳ'),
        channelDescription: AppStrings.choose(
          'Reminders for recurring income and expenses',
          'Nhắc các khoản thu và chi định kỳ',
        ),
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: review
            ? [
                AndroidNotificationAction(
                  'recurring_review',
                  AppStrings.choose('Review', 'Xem lại'),
                  showsUserInterface: true,
                ),
              ]
            : [
                AndroidNotificationAction(
                  'recurring_view_details',
                  AppStrings.choose('View details', 'Xem chi tiết'),
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'recurring_mark_paid',
                  AppStrings.choose('Mark as paid', 'Đánh dấu đã trả'),
                  showsUserInterface: true,
                ),
              ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: review ? _reviewCategory : _automaticCategory,
      ),
    );
  }

  String _titleFor(RecurringSchedule schedule) =>
      schedule.postingMode == RecurringPostingMode.review
      ? AppStrings.choose(
          'Review recurring transaction',
          'Xác nhận giao dịch định kỳ',
        )
      : AppStrings.choose('Recurring payment due', 'Giao dịch định kỳ đến hạn');

  String _bodyFor(RecurringSchedule schedule) {
    final digits = schedule.amount.abs().toString();
    final amount = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '${schedule.name} · $amount VND';
  }

  Future<bool> _wasScheduled(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_scheduledReminderKeysPreferenceKey) ??
            const [])
        .contains(key);
  }

  Future<void> _rememberScheduledKey(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final keys =
        preferences
            .getStringList(_scheduledReminderKeysPreferenceKey)
            ?.toSet() ??
        <String>{};
    keys.add(key);
    if (keys.length > 200) {
      keys.removeAll(keys.take(keys.length - 200).toList());
    }
    await preferences.setStringList(
      _scheduledReminderKeysPreferenceKey,
      keys.toList(growable: false),
    );
  }
}
