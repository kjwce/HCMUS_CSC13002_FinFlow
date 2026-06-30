class CommunityPostModel {
  const CommunityPostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.isAnonymous,
    required this.createdAt,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    return CommunityPostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'content': content,
        'is_anonymous': isAnonymous,
        'created_at': createdAt.toIso8601String(),
      };

  final String id;
  final String userId;
  final String content;
  final bool isAnonymous;
  final DateTime createdAt;
}
