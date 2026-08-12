import '../../../core/i18n/app_language.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.postId,
    this.commentId,
    this.actorName,
    this.actorAvatarUrl,
    this.postContent,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'actor_id': actorId,
    'post_id': postId,
    'comment_id': commentId,
    'type': type,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };

  final String id;
  final String userId;
  final String actorId;
  final String? postId;
  final String? commentId;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  /// Populated client-side
  final String? actorName;
  final String? actorAvatarUrl;
  final String? postContent;

  String get actorDisplayName =>
      actorName ?? AppStrings.choose('FinFlow user', 'Người dùng FinFlow');

  String get message {
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
    );
  }
}
