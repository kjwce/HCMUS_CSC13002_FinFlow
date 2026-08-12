import '../../../core/i18n/app_language.dart';

class CommunityCommentModel {
  const CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.isAnonymous,
    required this.createdAt,
    this.parentCommentId,
    this.likesCount = 0,
    this.isLikedByMe = false,
    this.authorName,
    this.authorAvatarUrl,
  });

  factory CommunityCommentModel.fromJson(Map<String, dynamic> json) {
    return CommunityCommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      parentCommentId: json['parent_comment_id'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_id': postId,
    'user_id': userId,
    'content': content,
    'is_anonymous': isAnonymous,
    'created_at': createdAt.toIso8601String(),
    'parent_comment_id': parentCommentId,
    'likes_count': likesCount,
  };

  final String id;
  final String postId;
  final String userId;
  final String content;
  final bool isAnonymous;
  final DateTime createdAt;
  final String? parentCommentId;
  final int likesCount;
  final bool isLikedByMe;

  /// Populated client-side by joining against `community_authors`.
  final String? authorName;
  final String? authorAvatarUrl;

  String get displayName => isAnonymous
      ? AppStrings.choose('Anonymous', 'Ẩn danh')
      : (authorName ?? AppStrings.choose('FinFlow user', 'Người dùng FinFlow'));

  CommunityCommentModel copyWith({
    String? authorName,
    String? authorAvatarUrl,
    int? likesCount,
    bool? isLikedByMe,
  }) {
    return CommunityCommentModel(
      id: id,
      postId: postId,
      userId: userId,
      content: content,
      isAnonymous: isAnonymous,
      createdAt: createdAt,
      parentCommentId: parentCommentId,
      likesCount: likesCount ?? this.likesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }
}
