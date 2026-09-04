import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../settings/services/notification_preferences_service.dart';
import '../models/notification_model.dart';
import '../utils/rich_text_formatter.dart';

/// Canonical notification feed backed by migration 033.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final instance = NotificationService._();

  final StreamController<NotificationModel> _incomingController =
      StreamController<NotificationModel>.broadcast();
  List<NotificationModel> _notifications = const [];
  RealtimeChannel? _channel;
  Timer? _dueTimer;
  final Set<String> _presentedIds = {};
  String? _activeUserId;
  bool _isLoading = false;
  bool _feedInitialized = false;
  bool _preferenceListenerAttached = false;

  Stream<NotificationModel> get incoming => _incomingController.stream;
  List<NotificationModel> get notifications => List.unmodifiable(
    _notifications.where((item) => item.isVisible && _allows(item)),
  );
  List<NotificationModel> get unread =>
      notifications.where((item) => !item.isRead).toList(growable: false);
  int get unreadCount => unread.length;
  int get actionRequiredCount =>
      notifications.where((item) => item.actionRequired).length;
  bool get isLoading => _isLoading;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  List<NotificationModel> filtered({
    NotificationCategory? category,
    bool actionRequired = false,
  }) {
    return notifications
        .where((item) {
          if (actionRequired && !item.actionRequired) return false;
          if (category != null && item.category != category) return false;
          return true;
        })
        .toList(growable: false);
  }

  Future<void> startForUser(String userId) async {
    if (_activeUserId != userId) {
      _activeUserId = userId;
      _notifications = const [];
      _presentedIds.clear();
      _feedInitialized = false;
      notifyListeners();
    }
    await NotificationPreferencesService.instance.startForUser(userId);
    if (!_preferenceListenerAttached) {
      NotificationPreferencesService.instance.addListener(
        _onPreferencesChanged,
      );
      _preferenceListenerAttached = true;
    }
    _subscribe(userId);
    await fetchNotifications();
  }

  void _onPreferencesChanged() => notifyListeners();

  void _subscribe(String userId) {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('app-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _handleRealtime(payload, userId),
        )
        .subscribe();
  }

  Future<void> _handleRealtime(
    PostgresChangePayload payload,
    String userId,
  ) async {
    if (_activeUserId != userId) return;
    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['id']?.toString();
      _notifications = _notifications
          .where((item) => item.id != id)
          .toList(growable: false);
      notifyListeners();
      return;
    }
    final row = payload.newRecord;
    if (row.isEmpty) return;
    var notification = NotificationModel.fromJson(row);
    if (notification.isCommunity) {
      notification = await _enrichOne(notification);
    }
    final index = _notifications.indexWhere(
      (item) => item.id == notification.id,
    );
    if (index >= 0) {
      final mutable = [..._notifications];
      mutable[index] = notification;
      _notifications = mutable..sort(_newestFirst);
    } else {
      _notifications = [notification, ..._notifications]..sort(_newestFirst);
      if (payload.eventType == PostgresChangeEvent.insert &&
          notification.isVisible &&
          _allows(notification)) {
        _presentedIds.add(notification.id);
        _incomingController.add(notification);
      }
    }
    _scheduleNextDue();
    notifyListeners();
  }

  Future<void> fetchNotifications({int limit = 100}) async {
    final userId = _userId;
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await Supabase.instance.client
          .from('app_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .neq('status', 'dismissed')
          .order('available_at', ascending: false)
          .limit(limit);
      final parsed = (response as List)
          .map(
            (item) => NotificationModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
      final enriched = await _enrichCommunity(parsed);
      if (_activeUserId == userId && _userId == userId) {
        _notifications = enriched..sort(_newestFirst);
        if (_feedInitialized) {
          for (final notification in _notifications) {
            if (notification.isVisible &&
                !_presentedIds.contains(notification.id) &&
                _allows(notification)) {
              _presentedIds.add(notification.id);
              _incomingController.add(notification);
            }
          }
        } else {
          _presentedIds.addAll(
            _notifications
                .where((item) => item.isVisible)
                .map((item) => item.id),
          );
          _feedInitialized = true;
        }
        _scheduleNextDue();
      }
    } catch (error) {
      debugPrint('fetch app notifications error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId, {bool value = true}) async {
    await _update(notificationId, {'is_read': value});
    _replace(notificationId, (item) => item.copyWith(isRead: value));
  }

  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;
    await Supabase.instance.client
        .from('app_notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
    _notifications = _notifications
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> archive(NotificationModel notification) async {
    _notifications = _notifications
        .where((item) => item.id != notification.id)
        .toList(growable: false);
    notifyListeners();
    try {
      await _update(notification.id, {'is_archived': true});
    } catch (_) {
      _insertLocally(notification);
      rethrow;
    }
  }

  Future<void> restore(NotificationModel notification) async {
    _insertLocally(notification.copyWith(isArchived: false));
    try {
      await _update(notification.id, {'is_archived': false});
    } catch (_) {
      _notifications = _notifications
          .where((item) => item.id != notification.id)
          .toList(growable: false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> resolve(
    String notificationId, {
    String status = 'completed',
  }) async {
    await _update(notificationId, {
      'status': status,
      'action_required': false,
      'is_read': true,
    });
    _replace(
      notificationId,
      (item) =>
          item.copyWith(status: status, actionRequired: false, isRead: true),
    );
  }

  Future<void> resolveRecurringActions(String scheduleId) async {
    final userId = _userId;
    if (userId == null) return;
    await Supabase.instance.client
        .from('app_notifications')
        .update({
          'status': 'dismissed',
          'action_required': false,
          'is_read': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('entity_type', 'recurring_schedule')
        .eq('entity_id', scheduleId)
        .eq('action_required', true);
    _notifications = _notifications
        .map(
          (item) => item.scheduleId == scheduleId && item.actionRequired
              ? item.copyWith(
                  status: 'dismissed',
                  actionRequired: false,
                  isRead: true,
                )
              : item,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<NotificationModel?> create({
    required NotificationCategory category,
    required String type,
    String? title,
    String? body,
    NotificationPriority priority = NotificationPriority.normal,
    bool actionRequired = false,
    String? entityType,
    String? entityId,
    String? routeName,
    Map<String, dynamic> payload = const {},
    String? dedupeKey,
    DateTime? availableAt,
  }) async {
    final userId = _userId;
    if (userId == null) return null;
    if (!_allowsCategory(category, type, payload)) return null;
    try {
      final response = await Supabase.instance.client
          .from('app_notifications')
          .insert({
            'user_id': userId,
            'category': category.name,
            'type': type,
            'title': title,
            'body': body,
            'priority': priority.name,
            'action_required': actionRequired,
            'entity_type': entityType,
            'entity_id': entityId,
            'route_name': routeName,
            'payload': payload,
            'dedupe_key': dedupeKey,
            'available_at': (availableAt ?? DateTime.now())
                .toUtc()
                .toIso8601String(),
          })
          .select()
          .single();
      return NotificationModel.fromJson(response);
    } on PostgrestException catch (error) {
      if (error.code != '23505') {
        debugPrint('create notification error: $error');
      }
      return null;
    }
  }

  Future<void> _update(String id, Map<String, dynamic> values) async {
    final userId = _userId;
    if (userId == null) return;
    await Supabase.instance.client
        .from('app_notifications')
        .update(values)
        .eq('id', id)
        .eq('user_id', userId);
  }

  void _insertLocally(NotificationModel notification) {
    if (_notifications.any((item) => item.id == notification.id)) return;
    _notifications = [..._notifications, notification]..sort(_newestFirst);
    notifyListeners();
  }

  void _replace(
    String id,
    NotificationModel Function(NotificationModel) update,
  ) {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final mutable = [..._notifications];
    mutable[index] = update(mutable[index]);
    _notifications = mutable;
    notifyListeners();
  }

  bool _allows(NotificationModel notification) => _allowsCategory(
    notification.category,
    notification.type,
    notification.payload,
  );

  bool _allowsCategory(
    NotificationCategory category,
    String type,
    Map<String, dynamic> payload,
  ) {
    final preferences = NotificationPreferencesService.instance.value;
    if (!preferences.masterEnabled) return false;
    return switch (category) {
      NotificationCategory.community => switch (type) {
        'like' || 'comment_like' => preferences.communityLikesEnabled,
        'comment' || 'comment_reply' => preferences.communityRepliesEnabled,
        'post' => preferences.communityPostsEnabled,
        _ => true,
      },
      NotificationCategory.recurring =>
        type.contains('fail') || type.contains('insufficient')
            ? preferences.recurringFailureEnabled
            : (payload['amount'] as num? ?? 0) < 0
            ? preferences.recurringExpenseEnabled
            : preferences.recurringIncomeEnabled,
      NotificationCategory.budget => switch (payload['period']) {
        'daily' => preferences.dailyBudgetEnabled,
        'weekly' => preferences.weeklyBudgetEnabled,
        _ => preferences.monthlyBudgetEnabled,
      },
      NotificationCategory.goal => preferences.savingGoalUpdatesEnabled,
      NotificationCategory.system => preferences.systemEnabled,
      NotificationCategory.transaction => true,
    };
  }

  Future<List<NotificationModel>> _enrichCommunity(
    List<NotificationModel> source,
  ) async {
    final community = source.where((item) => item.isCommunity).toList();
    if (community.isEmpty) return source;
    final actorIds = community.map((item) => item.actorId).nonNulls.toSet();
    final postIds = community.map((item) => item.postId).nonNulls.toSet();
    final authors = <String, Map<String, dynamic>>{};
    final previews = <String, String>{};
    if (actorIds.isNotEmpty) {
      try {
        final rows = await Supabase.instance.client
            .from('community_authors')
            .select()
            .inFilter('id', actorIds.toList());
        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          authors[row['id'].toString()] = row;
        }
      } catch (_) {}
    }
    if (postIds.isNotEmpty) {
      try {
        final rows = await Supabase.instance.client
            .from('community_posts')
            .select('id, content')
            .inFilter('id', postIds.toList());
        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final clean = stripFormattingForNotificationPreview(
            row['content']?.toString() ?? '',
          );
          previews[row['id'].toString()] = clean.length > 80
              ? '${clean.substring(0, 80)}…'
              : clean;
        }
      } catch (_) {}
    }
    return source
        .map((item) {
          if (!item.isCommunity) return item;
          final author = authors[item.actorId];
          return item.copyWith(
            actorName: author?['full_name']?.toString(),
            actorAvatarUrl: author?['avatar_url']?.toString(),
            postContent: item.postId == null ? null : previews[item.postId],
          );
        })
        .toList(growable: false);
  }

  Future<NotificationModel> _enrichOne(NotificationModel item) async {
    return (await _enrichCommunity([item])).first;
  }

  static int _newestFirst(NotificationModel a, NotificationModel b) {
    return (b.availableAt ?? b.createdAt).compareTo(
      a.availableAt ?? a.createdAt,
    );
  }

  void _scheduleNextDue() {
    _dueTimer?.cancel();
    final now = DateTime.now();
    final upcoming =
        _notifications
            .where(
              (item) =>
                  !item.isArchived &&
                  item.status != 'dismissed' &&
                  (item.availableAt ?? item.createdAt).isAfter(now),
            )
            .toList(growable: false)
          ..sort(
            (a, b) => (a.availableAt ?? a.createdAt).compareTo(
              b.availableAt ?? b.createdAt,
            ),
          );
    if (upcoming.isEmpty) return;
    final dueAt = upcoming.first.availableAt ?? upcoming.first.createdAt;
    final delay = dueAt.difference(now);
    _dueTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      for (final notification in _notifications) {
        if (notification.isVisible &&
            !_presentedIds.contains(notification.id) &&
            _allows(notification)) {
          _presentedIds.add(notification.id);
          _incomingController.add(notification);
        }
      }
      notifyListeners();
      _scheduleNextDue();
    });
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _dueTimer?.cancel();
    _channel = null;
    _activeUserId = null;
    _notifications = const [];
    _presentedIds.clear();
    _feedInitialized = false;
    NotificationPreferencesService.instance.clear();
    notifyListeners();
  }

  @visibleForTesting
  void debugReplaceNotifications(List<NotificationModel> notifications) {
    _notifications = List.unmodifiable(notifications);
    _feedInitialized = true;
    notifyListeners();
  }

  @visibleForTesting
  void debugEmit(NotificationModel notification) {
    _incomingController.add(notification);
  }
}
