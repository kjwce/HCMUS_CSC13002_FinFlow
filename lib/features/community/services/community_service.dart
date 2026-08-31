import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_comment_model.dart';
import '../models/community_post_model.dart';
import '../models/community_report_model.dart';

/// Service handling community feed CRUD + likes/saves/comments via Supabase.
/// Supports realtime updates via Supabase Realtime channels.
class CommunityService extends ChangeNotifier {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  List<CommunityPostModel> _posts = [];
  final Map<String, List<CommunityCommentModel>> _commentsByPost = {};
  final Set<String> _commentCacheReady = {};
  bool _isLoading = false;

  List<CommunityPostModel> get posts => List.unmodifiable(_posts);
  List<CommunityPostModel> get likedPosts =>
      List.unmodifiable(_posts.where((p) => p.isLikedByMe));
  List<CommunityPostModel> get savedPosts =>
      List.unmodifiable(_posts.where((p) => p.isSavedByMe));
  List<CommunityPostModel> get myPosts {
    final userId = _userId;
    if (userId == null) return const [];
    return List.unmodifiable(_posts.where((post) => post.userId == userId));
  }

  List<CommunityPostModel> postsForTopic(String topic) => topic == 'All'
      ? posts
      : List.unmodifiable(_posts.where((post) => post.category == topic));
  bool get isLoading => _isLoading;

  List<CommunityCommentModel> commentsFor(String postId) =>
      List.unmodifiable(_commentsByPost[postId] ?? const []);

  bool hasCachedCommentsFor(String postId) =>
      _commentCacheReady.contains(postId);

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Realtime subscriptions
  // ---------------------------------------------------------------------------
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _likesChannel;
  final Map<String, RealtimeChannel> _commentsChannels = {};

  /// Khởi động realtime — gọi 1 lần khi vào community screen.
  /// - Post mới: INSERT → thêm vào đầu danh sách
  /// - Like thay đổi: update likesCount local
  /// - Không gọi fetchPosts() toàn bộ để tránh giật UI
  void subscribeToRealtime() {
    // Lắng nghe post MỚI (INSERT) — thêm vào đầu list
    _postsChannel ??= Supabase.instance.client
        .channel('community-feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_posts',
          callback: (payload) {
            if (payload.newRecord['moderation_status'] != 'approved') return;
            final newPost = CommunityPostModel.fromJson(payload.newRecord);
            _fetchAuthors([newPost.userId]).then((authors) {
              final author = authors[newPost.userId];
              final postWithAuthor = newPost.copyWith(
                authorName: author?['full_name'] as String?,
                authorAvatarUrl: author?['avatar_url'] as String?,
              );
              _posts.insert(0, postWithAuthor);
              notifyListeners();
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'community_posts',
          callback: (payload) {
            final postId = payload.newRecord['id'] as String?;
            final moderationStatus =
                payload.newRecord['moderation_status'] as String?;
            final commentsCount = payload.newRecord['comments_count'] as int?;
            final likesCount = payload.newRecord['likes_count'] as int?;
            if (postId == null) return;
            final index = _posts.indexWhere((post) => post.id == postId);
            if (moderationStatus != null && moderationStatus != 'approved') {
              if (index >= 0) {
                _posts.removeAt(index);
                notifyListeners();
              }
              return;
            }
            if (index < 0) {
              fetchPosts();
              return;
            }
            _posts[index] = _posts[index].copyWith(
              commentsCount: commentsCount ?? _posts[index].commentsCount,
              likesCount: likesCount ?? _posts[index].likesCount,
            );
            notifyListeners();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'community_posts',
          callback: (payload) {
            final postId = payload.oldRecord['id'] as String?;
            if (postId == null) return;
            final removed = _posts.any((post) => post.id == postId);
            if (!removed) return;
            _posts.removeWhere((post) => post.id == postId);
            _commentsByPost.remove(postId);
            _commentCacheReady.remove(postId);
            notifyListeners();
          },
        )
        .subscribe();

    // Lắng nghe like thay đổi — chỉ update likesCount của post đó
    _likesChannel ??= Supabase.instance.client
        .channel('community-likes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_likes',
          callback: (payload) {
            final postId =
                (payload.newRecord['post_id'] ?? payload.oldRecord['post_id'])
                    as String?;
            if (postId == null) return;
            final index = _posts.indexWhere((p) => p.id == postId);
            if (index == -1) return;
            _fetchSinglePost(postId).then((updatedPost) {
              if (updatedPost != null && index < _posts.length) {
                _posts[index] = _posts[index].copyWith(
                  likesCount: updatedPost.likesCount,
                );
                notifyListeners();
              }
            });
          },
        )
        .subscribe();
  }

  /// Lắng nghe comment mới cho 1 post cụ thể.
  void subscribeToComments(String postId) {
    _commentsChannels[postId]?.unsubscribe();
    _commentsChannels[postId] = Supabase.instance.client
        .channel('comments-$postId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (_) {
            fetchComments(postId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_comment_likes',
          callback: (payload) {
            final commentId =
                (payload.newRecord['comment_id'] ??
                        payload.oldRecord['comment_id'])
                    as String?;
            final comments = _commentsByPost[postId];
            if (commentId == null ||
                comments == null ||
                !comments.any((comment) => comment.id == commentId)) {
              return;
            }
            fetchComments(postId);
          },
        )
        .subscribe();
  }

  void unsubscribeFromComments(String postId) {
    _commentsChannels[postId]?.unsubscribe();
    _commentsChannels.remove(postId);
  }

  /// Dọn dẹp khi không cần realtime nữa.
  void disposeRealtime() {
    _postsChannel?.unsubscribe();
    _postsChannel = null;
    _likesChannel?.unsubscribe();
    _likesChannel = null;
    for (final channel in _commentsChannels.values) {
      channel.unsubscribe();
    }
    _commentsChannels.clear();
  }

  // ---------------------------------------------------------------------------
  // Fetch posts
  // ---------------------------------------------------------------------------
  Future<void> fetchPosts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final client = Supabase.instance.client;
      final postsRes = await client
          .from('community_posts')
          .select()
          .eq('moderation_status', 'approved')
          .order('created_at', ascending: false);

      final rawPosts = (postsRes as List)
          .map((p) => CommunityPostModel.fromJson(p as Map<String, dynamic>))
          .toList();

      final userId = _userId;
      Set<String> likedIds = {};
      Set<String> savedIds = {};
      if (userId != null) {
        try {
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
        } catch (_) {
          // Nếu bảng likes/saves chưa có thì coi như rỗng
        }
      }

      final authorIds = rawPosts.map((p) => p.userId).toSet().toList();
      final authors = await _fetchAuthors(authorIds);
      final mediaByPost = <String, List<String>>{};
      if (rawPosts.isNotEmpty) {
        try {
          final mediaRows = await client
              .from('community_media')
              .select('post_id,url,created_at')
              .inFilter('post_id', rawPosts.map((p) => p.id).toList())
              .order('created_at', ascending: true);
          for (final row in mediaRows as List) {
            final postId = row['post_id'] as String;
            final url = row['url'] as String;
            mediaByPost.putIfAbsent(postId, () => []).add(url);
          }
        } catch (_) {
          // Media remains optional when the table is unavailable.
        }
      }

      _posts = rawPosts.map((p) {
        final author = authors[p.userId];
        return p.copyWith(
          authorName: author?['full_name'] as String?,
          authorAvatarUrl: author?['avatar_url'] as String?,
          isLikedByMe: likedIds.contains(p.id),
          isSavedByMe: savedIds.contains(p.id),
          mediaUrls: mediaByPost[p.id] ?? const [],
        );
      }).toList();
      await _prefetchComments(_posts.map((post) => post.id).toList());
    } catch (e) {
      debugPrint('fetchPosts error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchAuthors(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    try {
      final res = await Supabase.instance.client
          .from('community_authors')
          .select()
          .inFilter('id', ids);
      return {
        for (final row in (res as List))
          (row as Map<String, dynamic>)['id'] as String: row,
      };
    } catch (_) {
      return {};
    }
  }

  Future<CommunityPostModel?> _fetchSinglePost(String postId) async {
    try {
      final res = await Supabase.instance.client
          .from('community_posts')
          .select()
          .eq('id', postId)
          .single();
      return CommunityPostModel.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD posts
  // ---------------------------------------------------------------------------
  Future<String> createPost({
    required String content,
    required bool isAnonymous,
    required String category,
    bool isSpoiler = false,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    try {
      final row = await Supabase.instance.client
          .from('community_posts')
          .insert({
            'user_id': userId,
            'content': content,
            'is_anonymous': isAnonymous,
            'category': category,
            'is_spoiler': isSpoiler,
          })
          .select('id')
          .single();
      // Realtime sẽ tự thêm post mới vào danh sách
      return row['id'] as String;
    } on PostgrestException catch (error) {
      if (error.message.contains('COMMUNITY_USER_MUTED')) {
        throw const CommunityPostingMutedException();
      }
      rethrow;
    }
  }

  Future<void> addPostImage({required String postId, required XFile image}) =>
      addPostImages(postId: postId, images: [image]);

  Future<void> addPostImages({
    required String postId,
    required List<XFile> images,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');
    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      final storagePath =
          '$userId/$postId/'
          '${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
      final bytes = await image.readAsBytes();
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => image.mimeType ?? 'image/jpeg',
      };
      await Supabase.instance.client.storage
          .from('community-media')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      final url = Supabase.instance.client.storage
          .from('community-media')
          .getPublicUrl(storagePath);
      await Supabase.instance.client.from('community_media').insert({
        'post_id': postId,
        'user_id': userId,
        'url': url,
        'media_type': 'image',
      });
    }
  }

  Future<void> editPost({
    required String postId,
    required String content,
    required String category,
    bool isSpoiler = false,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('community_posts')
        .update({
          'content': content,
          'category': category,
          'is_spoiler': isSpoiler,
        })
        .eq('id', postId)
        .eq('user_id', userId);

    // Cập nhật local
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(
        content: content,
        category: category,
        isSpoiler: isSpoiler,
      );
      notifyListeners();
    }
  }

  Future<void> deletePost(String postId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    final index = _posts.indexWhere((post) => post.id == postId);
    final removedPost = index < 0 ? null : _posts.removeAt(index);
    if (removedPost != null) notifyListeners();

    try {
      final deletedRows = await Supabase.instance.client
          .from('community_posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', userId)
          .select('id');
      if ((deletedRows as List).isEmpty) {
        throw StateError('Post could not be deleted');
      }
      _commentsByPost.remove(postId);
      _commentCacheReady.remove(postId);
    } catch (_) {
      if (removedPost != null && !_posts.any((post) => post.id == postId)) {
        _posts.insert(index.clamp(0, _posts.length), removedPost);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<CommunityReportSubmitResult> reportPost({
    required String postId,
    required CommunityReportReason reason,
    String? description,
  }) => _submitReport(
    table: 'community_post_reports',
    targetColumn: 'post_id',
    targetId: postId,
    reason: reason,
    description: description,
  );

  Future<CommunityReportSubmitResult> reportComment({
    required String commentId,
    required CommunityReportReason reason,
    String? description,
  }) => _submitReport(
    table: 'community_comment_reports',
    targetColumn: 'comment_id',
    targetId: commentId,
    reason: reason,
    description: description,
  );

  Future<CommunityReportSubmitResult> _submitReport({
    required String table,
    required String targetColumn,
    required String targetId,
    required CommunityReportReason reason,
    String? description,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');
    final client = Supabase.instance.client;

    final existing = await client
        .from(table)
        .select('id')
        .eq(targetColumn, targetId)
        .eq('reporter_id', userId)
        .maybeSingle();
    if (existing != null) {
      return CommunityReportSubmitResult.alreadyReported;
    }

    try {
      await client.from(table).insert({
        targetColumn: targetId,
        'reporter_id': userId,
        'reason': reason.code,
        'description': description,
      });
      return CommunityReportSubmitResult.submitted;
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return CommunityReportSubmitResult.alreadyReported;
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Like / Save
  // ---------------------------------------------------------------------------
  Future<void> toggleLike(String postId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final post = _posts[index];
    final client = Supabase.instance.client;

    // Optimistic update
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
    } catch (error) {
      // Revert on failure
      _posts[index] = post;
      notifyListeners();
      debugPrint('toggleLike error: $error');
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

    // Optimistic update
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
      // Revert on failure
      _posts[index] = post;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Comments
  // ---------------------------------------------------------------------------
  Future<void> fetchComments(String postId) =>
      _loadCommentsForPosts([postId], notify: true);

  Future<void> _prefetchComments(List<String> postIds) async {
    final missingIds = postIds
        .where((postId) => !_commentCacheReady.contains(postId))
        .toList();
    if (missingIds.isEmpty) return;
    await _loadCommentsForPosts(missingIds, notify: false);
  }

  Future<void> _loadCommentsForPosts(
    List<String> postIds, {
    required bool notify,
  }) async {
    if (postIds.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('community_comments')
          .select()
          .inFilter('post_id', postIds)
          .order('created_at', ascending: true);

      final rawComments = (res as List)
          .map((c) => CommunityCommentModel.fromJson(c as Map<String, dynamic>))
          .toList();

      final authorIds = rawComments.map((c) => c.userId).toSet().toList();
      final authors = await _fetchAuthors(authorIds);
      final commentIds = rawComments.map((comment) => comment.id).toList();
      final likedCommentIds = <String>{};
      final userId = _userId;
      if (userId != null && commentIds.isNotEmpty) {
        try {
          final likedRes = await client
              .from('community_comment_likes')
              .select('comment_id')
              .eq('user_id', userId)
              .inFilter('comment_id', commentIds);
          likedCommentIds.addAll(
            (likedRes as List).map(
              (row) => (row as Map<String, dynamic>)['comment_id'] as String,
            ),
          );
        } catch (e) {
          debugPrint('fetch comment likes error: $e');
        }
      }

      final hydratedComments = rawComments.map((c) {
        final author = authors[c.userId];
        return c.copyWith(
          authorName: author?['full_name'] as String?,
          authorAvatarUrl: author?['avatar_url'] as String?,
          isLikedByMe: likedCommentIds.contains(c.id),
        );
      }).toList();

      for (final postId in postIds) {
        _commentsByPost[postId] = hydratedComments
            .where((comment) => comment.postId == postId)
            .toList();
        _commentCacheReady.add(postId);
        _syncPostCommentsCount(postId);
      }
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('loadComments error: $e');
    }
  }

  Future<void> addComment({
    required String postId,
    required String content,
    required bool isAnonymous,
    String? parentCommentId,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client.from('community_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'is_anonymous': isAnonymous,
      'parent_comment_id': parentCommentId,
    });
    // Show the submitted comment immediately. Realtime continues to refresh
    // this cache for inserts, updates, and deletes from other clients.
    await fetchComments(postId);
  }

  Future<void> deleteComment(String commentId, String postId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('community_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', userId);
    // Remove the entire local subtree immediately. Supabase applies the same
    // operation through ON DELETE CASCADE.
    final comments = _commentsByPost[postId];
    if (comments != null) {
      final removedIds = <String>{commentId};
      var foundChild = true;
      while (foundChild) {
        foundChild = false;
        for (final comment in comments) {
          if (comment.parentCommentId != null &&
              removedIds.contains(comment.parentCommentId) &&
              removedIds.add(comment.id)) {
            foundChild = true;
          }
        }
      }
      comments.removeWhere((comment) => removedIds.contains(comment.id));
    }
    _syncPostCommentsCount(postId);
    notifyListeners();
  }

  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    final comments = _commentsByPost[postId];
    final index = comments?.indexWhere((comment) => comment.id == commentId);
    if (comments == null || index == null || index < 0) {
      throw Exception('Comment not found');
    }

    final original = comments[index];
    final shouldLike = !original.isLikedByMe;
    comments[index] = original.copyWith(
      isLikedByMe: shouldLike,
      likesCount: shouldLike
          ? original.likesCount + 1
          : original.likesCount > 0
          ? original.likesCount - 1
          : 0,
    );
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      if (shouldLike) {
        await client.from('community_comment_likes').insert({
          'comment_id': commentId,
          'user_id': userId,
        });
      } else {
        await client
            .from('community_comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      }
    } catch (e) {
      final currentComments = _commentsByPost[postId];
      final currentIndex = currentComments?.indexWhere(
        (comment) => comment.id == commentId,
      );
      if (currentComments != null &&
          currentIndex != null &&
          currentIndex >= 0) {
        currentComments[currentIndex] = original;
        notifyListeners();
      }
      rethrow;
    }
  }

  void _syncPostCommentsCount(String postId) {
    final postIndex = _posts.indexWhere((post) => post.id == postId);
    final comments = _commentsByPost[postId];
    if (postIndex < 0 || comments == null) return;
    _posts[postIndex] = _posts[postIndex].copyWith(
      commentsCount: comments.length,
    );
  }
}

class CommunityPostingMutedException implements Exception {
  const CommunityPostingMutedException();

  @override
  String toString() => 'Tài khoản đã bị tạm khóa quyền đăng bài Community.';
}
