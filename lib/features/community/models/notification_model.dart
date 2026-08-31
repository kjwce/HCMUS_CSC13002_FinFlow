import '../../../core/i18n/app_language.dart';

enum NotificationCategory {
  transaction,
  budget,
  goal,
  recurring,
  community,
  system;

  static NotificationCategory fromStorage(Object? value) {
    final raw = value?.toString();
    return values.where((item) => item.name == raw).firstOrNull ?? community;
  }
}

enum NotificationPriority {
  low,
  normal,
  high,
  critical;

  static NotificationPriority fromStorage(Object? value) {
    final raw = value?.toString();
    return values.where((item) => item.name == raw).firstOrNull ?? normal;
  }
}

enum NotificationSource { app, community, recurring }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.category = NotificationCategory.community,
    this.priority = NotificationPriority.normal,
    this.actionRequired = false,
    this.isArchived = false,
    this.availableAt,
    this.actorId,
    this.postId,
    this.commentId,
    this.actorName,
    this.actorAvatarUrl,
    this.postContent,
    this.source = NotificationSource.app,
    this.sourceId,
    this.scheduleId,
    this.title,
    this.body,
    this.postingMode,
    this.occurrenceAt,
    this.status = 'active',
    this.entityType,
    this.entityId,
    this.routeName,
    this.payload = const {},
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final payload = Map<String, dynamic>.from(
      json['payload'] as Map? ?? const <String, dynamic>{},
    );
    final category = NotificationCategory.fromStorage(json['category']);
    final sourceTable = json['source_table']?.toString();
    final createdAt = _date(json['created_at']) ?? DateTime.now();
    return NotificationModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      actorId: _nullableString(json['actor_id'] ?? payload['actor_id']),
      postId: _nullableString(json['post_id'] ?? payload['post_id']),
      commentId: _nullableString(json['comment_id'] ?? payload['comment_id']),
      type: json['type']?.toString() ?? 'system_info',
      category: category,
      priority: NotificationPriority.fromStorage(json['priority']),
      actionRequired: json['action_required'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      availableAt: _date(json['available_at']) ?? createdAt,
      createdAt: createdAt,
      source: switch (sourceTable) {
        'community_notifications' => NotificationSource.community,
        'recurring_notifications' => NotificationSource.recurring,
        _ =>
          category == NotificationCategory.recurring
              ? NotificationSource.recurring
              : category == NotificationCategory.community
              ? NotificationSource.community
              : NotificationSource.app,
      },
      sourceId: _nullableString(json['source_id']),
      scheduleId: _nullableString(
        json['schedule_id'] ??
            payload['schedule_id'] ??
            (json['entity_type'] == 'recurring_schedule'
                ? json['entity_id']
                : null),
      ),
      title: _nullableString(json['title']),
      body: _nullableString(json['body']),
      postingMode: _nullableString(
        json['posting_mode'] ?? payload['posting_mode'],
      ),
      occurrenceAt: _date(json['occurrence_at'] ?? payload['occurrence_at']),
      status: json['status']?.toString() ?? 'active',
      entityType: _nullableString(json['entity_type']),
      entityId: _nullableString(json['entity_id']),
      routeName: _nullableString(json['route_name']),
      payload: payload,
    );
  }

  factory NotificationModel.fromRecurringJson(Map<String, dynamic> json) {
    return NotificationModel.fromJson({
      ...json,
      'category': 'recurring',
      'source_table': 'recurring_notifications',
      'type': json['posting_mode'] == 'review'
          ? 'recurring_review'
          : 'recurring_automatic',
      'action_required':
          json['posting_mode'] == 'review' && json['status'] == 'pending',
      'available_at': json['scheduled_for'],
      'entity_type': 'recurring_schedule',
      'entity_id': json['schedule_id'],
      'route_name': 'recurring_details',
      'payload': {
        'schedule_id': json['schedule_id'],
        'posting_mode': json['posting_mode'],
        'occurrence_at': json['occurrence_at'],
      },
    });
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'category': category.name,
    'type': type,
    'priority': priority.name,
    'action_required': actionRequired,
    'actor_id': actorId,
    'entity_type': entityType,
    'entity_id': entityId,
    'route_name': routeName,
    'payload': payload,
    'is_read': isRead,
    'is_archived': isArchived,
    'status': status,
    'available_at': (availableAt ?? createdAt).toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  final String id;
  final String userId;
  final NotificationCategory category;
  final NotificationPriority priority;
  final String type;
  final bool actionRequired;
  final bool isRead;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? availableAt;
  final NotificationSource source;
  final String? sourceId;
  final String? actorId;
  final String? postId;
  final String? commentId;
  final String? scheduleId;
  final String? title;
  final String? body;
  final String? postingMode;
  final DateTime? occurrenceAt;
  final String status;
  final String? entityType;
  final String? entityId;
  final String? routeName;
  final Map<String, dynamic> payload;

  final String? actorName;
  final String? actorAvatarUrl;
  final String? postContent;

  bool get isRecurring => category == NotificationCategory.recurring;
  bool get isCommunity => category == NotificationCategory.community;
  bool get isDue => !(availableAt ?? createdAt).isAfter(DateTime.now());
  bool get isVisible => !isArchived && status != 'dismissed' && isDue;

  String get actorDisplayName => isRecurring
      ? (title ?? AppStrings.choose('Recurring reminder', 'Nhắc lịch định kỳ'))
      : actorName ?? AppStrings.choose('FinFlow user', 'Người dùng FinFlow');

  String get localizedTitle {
    final name = AppStrings.choose(
      payload['name']?.toString() ?? 'Budget',
      payload['name_vi']?.toString() ??
          payload['name']?.toString() ??
          'Ngân sách',
    );
    return switch (type) {
      'recurring_review' => AppStrings.choose(
        'Confirm recurring transaction',
        'Xác nhận giao dịch định kỳ',
      ),
      'recurring_auto_success' || 'recurring_automatic' => AppStrings.choose(
        'Transaction posted automatically',
        'Đã tự động ghi giao dịch',
      ),
      'recurring_failed' => AppStrings.choose(
        'Recurring transaction failed',
        'Không thể ghi giao dịch định kỳ',
      ),
      'recurring_insufficient_balance' => AppStrings.choose(
        'Insufficient balance',
        'Không đủ số dư',
      ),
      'budget_threshold' => AppStrings.choose(
        '$name is near its limit',
        'Ngân sách $name sắp đạt giới hạn',
      ),
      'budget_exceeded' => AppStrings.choose(
        '$name exceeded its limit',
        'Ngân sách $name đã vượt hạn mức',
      ),
      'goal_milestone' => AppStrings.choose(
        'Savings goal milestone',
        'Cột mốc mục tiêu tiết kiệm',
      ),
      'transaction_created' => AppStrings.choose(
        'Transaction recorded',
        'Đã ghi giao dịch',
      ),
      'comment' => AppStrings.choose(
        'New comment on a community post',
        'Bình luận mới trong cộng đồng',
      ),
      'comment_reply' => AppStrings.choose(
        'New reply to your comment',
        'Phản hồi mới cho bình luận của bạn',
      ),
      'like' || 'comment_like' => AppStrings.choose(
        'New like in Community',
        'Lượt thích mới trong Cộng đồng',
      ),
      'post' => AppStrings.choose(
        'New Community post',
        'Bài viết Cộng đồng mới',
      ),
      _ => title ?? AppStrings.choose('FinFlow update', 'Cập nhật FinFlow'),
    };
  }

  String get message {
    if (isRecurring) return body ?? payload['summary']?.toString() ?? '';
    if (!isCommunity) return body ?? payload['summary']?.toString() ?? '';
    switch (type) {
      case 'post':
        return AppStrings.choose(
          'shared a new community post: "${postContent ?? ""}"',
          'đã chia sẻ bài viết cộng đồng mới: "${postContent ?? ""}"',
        );
      case 'like':
        return AppStrings.choose(
          'liked your tip on "${postContent ?? "a post"}"',
          'đã thích mẹo của bạn trong "${postContent ?? "một bài viết"}"',
        );
      case 'comment':
        return AppStrings.choose(
          'commented on a community post: "${postContent ?? ""}"',
          'đã bình luận về bài viết cộng đồng: "${postContent ?? ""}"',
        );
      case 'comment_reply':
        return AppStrings.choose(
          'replied to your comment on "${postContent ?? "a post"}"',
          'đã trả lời bình luận của bạn trong "${postContent ?? "một bài viết"}"',
        );
      case 'comment_like':
        return AppStrings.choose(
          'liked your comment on "${postContent ?? "a post"}"',
          'đã thích bình luận của bạn trong "${postContent ?? "một bài viết"}"',
        );
      default:
        return body ??
            AppStrings.choose(
              'interacted with your post',
              'đã tương tác với bài viết của bạn',
            );
    }
  }

  NotificationModel copyWith({
    String? actorName,
    String? actorAvatarUrl,
    String? postContent,
    bool? isRead,
    bool? isArchived,
    bool? actionRequired,
    String? status,
  }) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      category: category,
      priority: priority,
      actionRequired: actionRequired ?? this.actionRequired,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      availableAt: availableAt,
      actorId: actorId,
      postId: postId,
      commentId: commentId,
      actorName: actorName ?? this.actorName,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
      postContent: postContent ?? this.postContent,
      source: source,
      sourceId: sourceId,
      scheduleId: scheduleId,
      title: title,
      body: body,
      postingMode: postingMode,
      occurrenceAt: occurrenceAt,
      status: status ?? this.status,
      entityType: entityType,
      entityId: entityId,
      routeName: routeName,
      payload: payload,
    );
  }
}
