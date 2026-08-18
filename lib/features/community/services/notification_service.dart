import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';
import '../utils/rich_text_formatter.dart';

/// Service quản lý notification cho community.
/// Singleton + ChangeNotifier để UI cập nhật realtime.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  RealtimeChannel? _communityChannel;
  RealtimeChannel? _recurringChannel;
  String? _activeUserId;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  List<NotificationModel> get unread =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  void subscribe(String userId) {
    _communityChannel?.unsubscribe();
    _recurringChannel?.unsubscribe();
    _communityChannel = Supabase.instance.client
        .channel('community-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final notif = NotificationModel.fromJson(payload.newRecord);
            _enrichAndPrepend(notif);
          },
        )
        .subscribe();
    _recurringChannel = Supabase.instance.client
        .channel('recurring-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'recurring_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => fetchNotifications(),
        )
        .subscribe();
  }

  void startForUser(String userId) {
    if (_activeUserId != userId) {
      _activeUserId = userId;
      _notifications = [];
      notifyListeners();
    }
    subscribe(userId);
    fetchNotifications();
  }

  void unsubscribe() {
    _communityChannel?.unsubscribe();
    _recurringChannel?.unsubscribe();
    _communityChannel = null;
    _recurringChannel = null;
    _activeUserId = null;
    _notifications = [];
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Fetch
  // ---------------------------------------------------------------------------

  Future<void> fetchNotifications() async {
    final userId = _userId;
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      List communityRows = const [];
      List recurringRows = const [];
      try {
        communityRows = await Supabase.instance.client
            .from('community_notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      } catch (error) {
        debugPrint('fetch community notifications error: $error');
      }
      try {
        recurringRows = await Supabase.instance.client
            .from('recurring_notifications')
            .select()
            .eq('user_id', userId)
            .lte('scheduled_for', DateTime.now().toUtc().toIso8601String())
            .neq('status', 'dismissed')
            .order('scheduled_for', ascending: false);
      } catch (error) {
        debugPrint('fetch recurring notifications error: $error');
      }
      final raw = communityRows
          .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
          .toList();
      final recurring = recurringRows
          .map(
            (n) =>
                NotificationModel.fromRecurringJson(n as Map<String, dynamic>),
          )
          .toList();

      _activeUserId ??= userId;
      if (_activeUserId == userId && _userId == userId) {
        await _enrichAll(raw);
        _notifications = [..._notifications, ...recurring]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint('fetchNotifications error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Mark as read
  // ---------------------------------------------------------------------------

  Future<void> markAsRead(String notificationId) async {
    final notification = _notifications
        .where((item) => item.id == notificationId)
        .firstOrNull;
    final table = notification?.isRecurring == true
        ? 'recurring_notifications'
        : 'community_notifications';
    await Supabase.instance.client
        .from(table)
        .update({'is_read': true})
        .eq('id', notificationId);

    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;

    await Future.wait([
      Supabase.instance.client
          .from('community_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false),
      Supabase.instance.client
          .from('recurring_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false),
    ]);

    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _enrichAll(List<NotificationModel> raw) async {
    final actorIds = raw
        .map((n) => n.actorId)
        .whereType<String>()
        .toSet()
        .toList();
    final postIds = raw
        .where((n) => n.postId != null)
        .map((n) => n.postId!)
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> authors = {};
    Map<String, String> postPreviews = {};

    try {
      final authorRes = await Supabase.instance.client
          .from('community_authors')
          .select()
          .inFilter('id', actorIds);
      authors = {
        for (final row in (authorRes as List))
          (row as Map<String, dynamic>)['id'] as String: row,
      };
    } catch (_) {}

    if (postIds.isNotEmpty) {
      try {
        final postRes = await Supabase.instance.client
            .from('community_posts')
            .select('id, content')
            .inFilter('id', postIds);
        for (final row in (postRes as List)) {
          final r = row as Map<String, dynamic>;
          final text = stripFormattingForNotificationPreview(
            r['content'] as String? ?? '',
          );
          postPreviews[r['id'] as String] = text.length > 60
              ? '${text.substring(0, 60)}…'
              : text;
        }
      } catch (_) {}
    }

    _notifications = raw
        .map(
          (n) => n.copyWith(
            actorName: authors[n.actorId]?['full_name'] as String?,
            actorAvatarUrl: authors[n.actorId]?['avatar_url'] as String?,
            postContent: n.postId != null ? postPreviews[n.postId!] : null,
          ),
        )
        .toList();
    notifyListeners();
  }

  void _enrichAndPrepend(NotificationModel notif) async {
    // Fetch actor + post info for the new notification
    Map<String, Map<String, dynamic>> authors = {};
    String? preview;

    try {
      final authorRes = await Supabase.instance.client
          .from('community_authors')
          .select()
          .eq('id', notif.actorId!)
          .single();
      authors[notif.actorId!] = Map<String, dynamic>.from(authorRes);
    } catch (_) {}

    if (notif.postId != null) {
      try {
        final postRes = await Supabase.instance.client
            .from('community_posts')
            .select('content')
            .eq('id', notif.postId!)
            .single();
        final text = stripFormattingForNotificationPreview(
          postRes['content'] as String? ?? '',
        );
        preview = text.length > 60 ? '${text.substring(0, 60)}…' : text;
      } catch (_) {}
    }

    final enriched = notif.copyWith(
      actorName: authors[notif.actorId]?['full_name'] as String?,
      actorAvatarUrl: authors[notif.actorId]?['avatar_url'] as String?,
      postContent: preview,
    );

    _notifications.insert(0, enriched);
    notifyListeners();
  }
}
