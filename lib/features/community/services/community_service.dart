import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_comment_model.dart';
import '../models/community_post_model.dart';

/// Service handling community feed CRUD + likes/saves/comments via Supabase.
/// Follows the same singleton ChangeNotifier pattern as GoalService.
class CommunityService extends ChangeNotifier {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  List<CommunityPostModel> _posts = [];
  final Map<String, List<CommunityCommentModel>> _commentsByPost = {};
  bool _isLoading = false;

  List<CommunityPostModel> get posts => List.unmodifiable(_posts);
  List<CommunityPostModel> get likedPosts =>
      List.unmodifiable(_posts.where((p) => p.isLikedByMe));
  List<CommunityPostModel> get savedPosts =>
      List.unmodifiable(_posts.where((p) => p.isSavedByMe));
  bool get isLoading => _isLoading;

  List<CommunityCommentModel> commentsFor(String postId) =>
      List.unmodifiable(_commentsByPost[postId] ?? const []);

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  /// Fetch the feed + which posts the current user has liked/saved.
  Future<void> fetchPosts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final client = Supabase.instance.client;
      final postsRes = await client
          .from('community_posts')
          .select()
          .order('created_at', ascending: false);

      final rawPosts = (postsRes as List)
          .map((p) => CommunityPostModel.fromJson(p as Map<String, dynamic>))
          .toList();

      final userId = _userId;
      Set<String> likedIds = {};
      Set<String> savedIds = {};
      if (userId != null) {
        final likesRes = await client
            .from('community_likes')
            .select('post_id')
            .eq('user_id', userId);
        likedIds = (likesRes as List)
            .map((r) => r['post_id'] as String)
            .toSet();

        final savesRes = await client
            .from('community_saves')
            .select('post_id')
            .eq('user_id', userId);
        savedIds = (savesRes as List)
            .map((r) => r['post_id'] as String)
            .toSet();
      }

      final authorIds = rawPosts.map((p) => p.userId).toSet().toList();
      final authors = await _fetchAuthors(authorIds);

      _posts = rawPosts.map((p) {
        final author = authors[p.userId];
        return p.copyWith(
          authorName: author?['full_name'] as String?,
          authorAvatarUrl: author?['avatar_url'] as String?,
          isLikedByMe: likedIds.contains(p.id),
          isSavedByMe: savedIds.contains(p.id),
        );
      }).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchAuthors(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final res = await Supabase.instance.client
        .from('community_authors')
        .select()
        .inFilter('id', ids);
    return {
      for (final row in (res as List))
        (row as Map<String, dynamic>)['id'] as String: row,
    };
  }

  Future<void> createPost({
    required String content,
    required bool isAnonymous,
    required String category,
    bool isSpoiler = false,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client.from('community_posts').insert({
      'user_id': userId,
      'content': content,
      'is_anonymous': isAnonymous,
      'category': category,
      'is_spoiler': isSpoiler,
    });
    await fetchPosts();
  }

  Future<void> toggleLike(String postId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final post = _posts[index];
    final client = Supabase.instance.client;

    // Optimistic update.
    _posts[index] = post.copyWith(
      isLikedByMe: !post.isLikedByMe,
      likesCount: post.isLikedByMe ? post.likesCount - 1 : post.likesCount + 1,
    );
    notifyListeners();

    try {
      if (post.isLikedByMe) {
        await client
            .from('community_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await client.from('community_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
    } catch (_) {
      // Revert on failure.
      _posts[index] = post;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleSave(String postId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final post = _posts[index];
    final client = Supabase.instance.client;

    // Optimistic update.
    _posts[index] = post.copyWith(isSavedByMe: !post.isSavedByMe);
    notifyListeners();

    try {
      if (post.isSavedByMe) {
        await client
            .from('community_saves')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await client.from('community_saves').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
    } catch (_) {
      // Revert on failure.
      _posts[index] = post;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchComments(String postId) async {
    final client = Supabase.instance.client;
    final res = await client
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    final rawComments = (res as List)
        .map((c) =>
            CommunityCommentModel.fromJson(c as Map<String, dynamic>))
        .toList();

    final authorIds = rawComments.map((c) => c.userId).toSet().toList();
    final authors = await _fetchAuthors(authorIds);

    _commentsByPost[postId] = rawComments.map((c) {
      final author = authors[c.userId];
      return c.copyWith(
        authorName: author?['full_name'] as String?,
        authorAvatarUrl: author?['avatar_url'] as String?,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> addComment({
    required String postId,
    required String content,
    required bool isAnonymous,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client.from('community_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'is_anonymous': isAnonymous,
    });

    // Bump the local counter so the list screen reflects it immediately.
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] =
          _posts[index].copyWith(commentsCount: _posts[index].commentsCount + 1);
    }

    await fetchComments(postId);
  }
}
