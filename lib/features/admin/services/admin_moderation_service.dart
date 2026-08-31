import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_member_model.dart';
import '../models/admin_post_model.dart';
import '../models/admin_report_model.dart';

class AdminModerationService {
  AdminModerationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<bool> isCurrentUserAdmin() async {
    if (currentUser == null) return false;
    final result = await _client.rpc('is_community_admin');
    return result == true;
  }

  Future<bool> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (response.user == null) return false;
    final isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) await signOut();
    return isAdmin;
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<List<AdminPostModel>> fetchPosts() async {
    final rows = await _client
        .from('community_posts')
        .select()
        .order('created_at', ascending: false);
    final rawPosts = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (rawPosts.isEmpty) return const [];

    final postIds = rawPosts.map((row) => row['id'] as String).toList();
    final authorIds = rawPosts
        .map((row) => row['user_id'] as String)
        .toSet()
        .toList();

    final results = await Future.wait<dynamic>([
      _client
          .from('profiles')
          .select('id,full_name,email,avatar_url')
          .inFilter('id', authorIds),
      _client
          .from('community_post_reports')
          .select('post_id')
          .inFilter('post_id', postIds),
      _client
          .from('community_media')
          .select('post_id,url')
          .inFilter('post_id', postIds),
    ]);

    final authors = <String, Map<String, dynamic>>{
      for (final row in results[0] as List)
        (row as Map)['id'] as String: Map<String, dynamic>.from(row),
    };
    final reports = <String, int>{};
    for (final row in results[1] as List) {
      final postId = (row as Map)['post_id'] as String;
      reports[postId] = (reports[postId] ?? 0) + 1;
    }
    final media = <String, List<String>>{};
    for (final row in results[2] as List) {
      final map = row as Map;
      media
          .putIfAbsent(map['post_id'] as String, () => [])
          .add(map['url'] as String);
    }

    return rawPosts.map((row) {
      final id = row['id'] as String;
      return AdminPostModel.fromJson(
        row,
        author: authors[row['user_id'] as String],
        reportCount: reports[id] ?? 0,
        mediaUrls: media[id] ?? const [],
      );
    }).toList();
  }

  Future<void> moderate({
    required String postId,
    required ModerationStatus status,
    String? reason,
  }) async {
    if (status == ModerationStatus.pending) {
      throw ArgumentError('Không thể đưa bài về trạng thái chờ duyệt.');
    }
    await _client.rpc(
      'moderate_community_post',
      params: {
        'target_post_id': postId,
        'new_status': status.name,
        'reason': reason,
      },
    );
  }

  Future<List<AdminReportedPostModel>> fetchReportedPosts() async {
    final results = await Future.wait<dynamic>([
      fetchPosts(),
      _client
          .from('community_post_reports')
          .select()
          .order('created_at', ascending: false),
    ]);
    final posts = <String, AdminPostModel>{
      for (final post in results[0] as List<AdminPostModel>) post.id: post,
    };
    final rawReports = (results[1] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (rawReports.isEmpty) return const [];

    final reporterIds = rawReports
        .map((row) => row['reporter_id'] as String)
        .toSet()
        .toList();
    final profileRows = await _client
        .from('profiles')
        .select('id,full_name')
        .inFilter('id', reporterIds);
    final reporterNames = <String, String>{
      for (final row in profileRows as List)
        (row as Map)['id']
            as String: ((row['full_name'] as String?)?.trim().isNotEmpty == true
            ? row['full_name'] as String
            : 'Người dùng FinFlow'),
    };

    final reportsByPost = <String, List<AdminReportModel>>{};
    for (final row in rawReports) {
      final postId = row['post_id'] as String;
      if (!posts.containsKey(postId)) continue;
      reportsByPost
          .putIfAbsent(postId, () => [])
          .add(
            AdminReportModel.fromJson(
              row,
              reporterName: reporterNames[row['reporter_id'] as String],
            ),
          );
    }

    final reportedPosts = reportsByPost.entries
        .map(
          (entry) => AdminReportedPostModel(
            post: posts[entry.key]!,
            reports: entry.value,
          ),
        )
        .toList();
    reportedPosts.sort((a, b) {
      final aDate = a.reports.first.createdAt;
      final bDate = b.reports.first.createdAt;
      return bDate.compareTo(aDate);
    });
    return reportedPosts;
  }

  Future<void> removeReportedPost({
    required String postId,
    required String reason,
  }) async {
    await _client.rpc(
      'remove_reported_community_post',
      params: {'target_post_id': postId, 'reason': reason.trim()},
    );
  }

  Future<List<AdminMemberModel>> fetchMembers() async {
    final results = await Future.wait<dynamic>([
      _client
          .from('profiles')
          .select(
            'id,full_name,email,avatar_url,created_at,is_community_muted,'
            'community_mute_reason,community_muted_at',
          )
          .order('created_at', ascending: false),
      _client.from('community_posts').select('id,user_id'),
      _client.from('community_post_reports').select('post_id'),
    ]);

    final postCountByUser = <String, int>{};
    final postOwnerById = <String, String>{};
    for (final row in results[1] as List) {
      final map = row as Map;
      final userId = map['user_id'] as String;
      postOwnerById[map['id'] as String] = userId;
      postCountByUser[userId] = (postCountByUser[userId] ?? 0) + 1;
    }
    final reportsByUser = <String, int>{};
    for (final row in results[2] as List) {
      final ownerId = postOwnerById[(row as Map)['post_id'] as String];
      if (ownerId != null) {
        reportsByUser[ownerId] = (reportsByUser[ownerId] ?? 0) + 1;
      }
    }

    return (results[0] as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final userId = map['id'] as String;
      return AdminMemberModel.fromJson(
        map,
        postCount: postCountByUser[userId] ?? 0,
        receivedReportCount: reportsByUser[userId] ?? 0,
      );
    }).toList();
  }

  Future<void> setUserMuted({
    required String userId,
    required bool muted,
    String? reason,
  }) async {
    await _client.rpc(
      'set_community_user_muted',
      params: {'target_user_id': userId, 'muted': muted, 'reason': reason},
    );
  }
}
