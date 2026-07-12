class CommunityPostModel {
  const CommunityPostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.isAnonymous,
    required this.category,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    this.isSpoiler = false,
    this.authorName,
    this.authorAvatarUrl,
    this.isLikedByMe = false,
    this.isSavedByMe = false,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    return CommunityPostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      category: json['category'] as String? ?? 'General',
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSpoiler: json['is_spoiler'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'content': content,
        'is_anonymous': isAnonymous,
        'category': category,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'created_at': createdAt.toIso8601String(),
        'is_spoiler': isSpoiler,
      };

  final String id;
  final String userId;
  final String content;
  final bool isAnonymous;
  final String category;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final bool isSpoiler;

  /// Populated client-side by joining against `community_authors`.
  final String? authorName;
  final String? authorAvatarUrl;

  /// Populated client-side from the current user's likes/saves.
  final bool isLikedByMe;
  final bool isSavedByMe;

  String get displayName =>
      isAnonymous ? 'Anonymous' : (authorName ?? 'FinFlow user');

  CommunityPostModel copyWith({
    String? authorName,
    String? authorAvatarUrl,
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
    bool? isSavedByMe,
  }) {
    return CommunityPostModel(
      id: id,
      userId: userId,
      content: content,
      isAnonymous: isAnonymous,
      category: category,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
    );
  }
}
