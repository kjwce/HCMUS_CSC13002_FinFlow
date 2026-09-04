import '../../../core/i18n/app_language.dart';

class AdminMemberModel {
  const AdminMemberModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
    required this.isMuted,
    required this.postCount,
    required this.receivedReportCount,
    this.avatarUrl,
    this.muteReason,
    this.mutedAt,
  });

  factory AdminMemberModel.fromJson(
    Map<String, dynamic> json, {
    int postCount = 0,
    int receivedReportCount = 0,
  }) {
    return AdminMemberModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      isMuted: json['is_community_muted'] as bool? ?? false,
      muteReason: json['community_mute_reason'] as String?,
      mutedAt: json['community_muted_at'] == null
          ? null
          : DateTime.parse(json['community_muted_at'] as String).toLocal(),
      postCount: postCount,
      receivedReportCount: receivedReportCount,
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool isMuted;
  final String? muteReason;
  final DateTime? mutedAt;
  final int postCount;
  final int receivedReportCount;

  String get displayName => fullName.trim().isEmpty
      ? AppStrings.choose('FinFlow user', 'Người dùng FinFlow')
      : fullName;
}
