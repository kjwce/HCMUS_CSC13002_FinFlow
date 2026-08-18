import '../../../core/i18n/app_language.dart';

enum NotificationSource { community, recurring }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    this.actorId,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.postId,
    this.commentId,
    this.actorName,
    this.actorAvatarUrl,
    this.postContent,
    this.source = NotificationSource.community,
    this.scheduleId,
    this.title,
    this.body,
    this.postingMode,
    this.occurrenceAt,
    this.status,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      actorId: json['actor_id'] as String,
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      type: json['type'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory NotificationModel.fromRecurringJson(Map<String, dynamic> json) {
    final scheduledFor = DateTime.parse(json['scheduled_for'] as String);
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['posting_mode'] == 'review'
          ? 'recurring_review'
          : 'recurring_automatic',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: scheduledFor,
      source: NotificationSource.recurring,
      scheduleId: json['schedule_id'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      postingMode: json['posting_mode'] as String?,
      occurrenceAt: DateTime.parse(json['occurrence_at'] as String).toLocal(),
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    if (actorId != null) 'actor_id': actorId,
    'post_id': postId,
    'comment_id': commentId,
    'type': type,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };

  final String id;
  final String userId;
  final String? actorId;
  final String? postId;
  final String? commentId;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final NotificationSource source;
  final String? scheduleId;
  final String? title;
  final String? body;
  final String? postingMode;
  final DateTime? occurrenceAt;
  final String? status;

  bool get isRecurring => source == NotificationSource.recurring;

  /// Populated client-side
  final String? actorName;
  final String? actorAvatarUrl;
  final String? postContent;

  String get actorDisplayName => isRecurring
      ? (title ?? AppStrings.choose('Recurring reminder', 'Nhắc lịch định kỳ'))
      : actorName ?? AppStrings.choose('FinFlow user', 'Người dùng FinFlow');

  String get message {
    if (isRecurring) return body ?? '';
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
        return AppStrings.choose(
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
  }) {
    return NotificationModel(
      id: id,
      userId: userId,
      actorId: actorId,
      postId: postId,
      commentId: commentId,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actorName: actorName ?? this.actorName,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
      postContent: postContent ?? this.postContent,
      source: source,
      scheduleId: scheduleId,
      title: title,
      body: body,
      postingMode: postingMode,
      occurrenceAt: occurrenceAt,
      status: status,
    );
  }
}
