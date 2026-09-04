import 'admin_post_model.dart';

class AdminReportModel {
  const AdminReportModel({
    required this.id,
    required this.postId,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.description,
    this.reporterName,
  });

  factory AdminReportModel.fromJson(
    Map<String, dynamic> json, {
    String? reporterName,
  }) {
    return AdminReportModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      reporterId: json['reporter_id'] as String,
      reason: json['reason'] as String? ?? 'Khác',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      reporterName: reporterName,
    );
  }

  final String id;
  final String postId;
  final String reporterId;
  final String reason;
  final String? description;
  final String status;
  final DateTime createdAt;
  final String? reporterName;
}

class AdminReportedPostModel {
  const AdminReportedPostModel({required this.post, required this.reports});

  final AdminPostModel post;
  final List<AdminReportModel> reports;

  int get pendingCount =>
      reports.where((report) => report.status == 'pending').length;
}
