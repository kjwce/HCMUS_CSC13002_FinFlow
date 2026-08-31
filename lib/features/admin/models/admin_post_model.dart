import '../../../core/i18n/app_language.dart';

enum ModerationStatus { pending, approved, rejected, removed }

class AdminPostModel {
  const AdminPostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.category,
    required this.isAnonymous,
    required this.createdAt,
    required this.status,
    required this.likesCount,
    required this.commentsCount,
    required this.reportCount,
    this.authorName,
    this.authorEmail,
    this.authorAvatarUrl,
    this.rejectionReason,
    this.reviewedAt,
    this.removalReason,
    this.removedAt,
    this.mediaUrls = const [],
  });

  factory AdminPostModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? author,
    int reportCount = 0,
    List<String> mediaUrls = const [],
  }) {
    return AdminPostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: ModerationStatus.values.firstWhere(
        (value) => value.name == json['moderation_status'],
        orElse: () => ModerationStatus.pending,
      ),
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      reportCount: reportCount,
      authorName: author?['full_name'] as String?,
      authorEmail: author?['email'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      removalReason: json['removal_reason'] as String?,
      removedAt: json['removed_at'] == null
          ? null
          : DateTime.parse(json['removed_at'] as String),
      mediaUrls: mediaUrls,
    );
  }

  final String id;
  final String userId;
  final String content;
  final String category;
  final bool isAnonymous;
  final DateTime createdAt;
  final ModerationStatus status;
  final int likesCount;
  final int commentsCount;
  final int reportCount;
  final String? authorName;
  final String? authorEmail;
  final String? authorAvatarUrl;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? removalReason;
  final DateTime? removedAt;
  final List<String> mediaUrls;

  String get displayAuthor => isAnonymous
      ? AppStrings.choose('Anonymous', 'Ẩn danh')
      : (authorName?.trim().isNotEmpty == true
            ? authorName!
            : AppStrings.choose('FinFlow user', 'Người dùng FinFlow'));
}
