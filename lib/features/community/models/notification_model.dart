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
  final String type; // 'post', 'like', 'comment'
  final bool isRead;
  final DateTime createdAt;

  /// Populated client-side
  final String? actorName;
  final String? actorAvatarUrl;
  final String? postContent;

  String get actorDisplayName => actorName ?? 'FinFlow user';

  String get message {
    switch (type) {
      case 'post':
        return 'shared a new community post: "${postContent ?? ""}"';
      case 'like':
        return 'liked your tip on "${postContent ?? "a post"}"';
      case 'comment':
        return 'commented on a community post: "${postContent ?? ""}"';
      default:
        return 'interacted with your post';
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
