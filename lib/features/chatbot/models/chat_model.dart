class ChatModel {
  const ChatModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.isUser,
    required this.createdAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String,
      isUser: json['is_user'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'message': message,
        'is_user': isUser,
        'created_at': createdAt.toIso8601String(),
      };

  final String id;
  final String userId;
  final String message;
  final bool isUser;
  final DateTime createdAt;
}
