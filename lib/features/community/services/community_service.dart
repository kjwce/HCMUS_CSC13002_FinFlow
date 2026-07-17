import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_comment_model.dart';
import '../models/community_post_model.dart';

/// Service handling community feed CRUD + likes/saves/comments via Supabase.
/// Supports realtime updates via Supabase Realtime channels.
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
            final commentsCount = payload.newRecord['comments_count'] as int?;
            final likesCount = payload.newRecord['likes_count'] as int?;
            if (postId == null) return;
            final index = _posts.indexWhere((post) => post.id == postId);
            if (index < 0) return;
            _posts[index] = _posts[index].copyWith(
              commentsCount: commentsCount ?? _posts[index].commentsCount,
              likesCount: likesCount ?? _posts[index].likesCount,
            );
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
              .select('post_id,url')
              .inFilter('post_id', rawPosts.map((p) => p.id).toList());
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
  }

  Future<void> addPostImage({
    required String postId,
    required XFile image,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');
    final extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';
    final storagePath =
        '$userId/$postId/${DateTime.now().millisecondsSinceEpoch}.$extension';
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

    await Supabase.instance.client
        .from('community_posts')
        .delete()
        .eq('id', postId)
        .eq('user_id', userId);
    // Xoá khỏi danh sách local ngay lập tức
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
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
  Future<void> fetchComments(String postId) async {
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('community_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final rawComments = (res as List)
          .map((c) => CommunityCommentModel.fromJson(c as Map<String, dynamic>))
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
      _syncPostCommentsCount(postId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchComments error: $e');
    }
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
    // Xoá khỏi danh sách local ngay lập tức
    _commentsByPost[postId]?.removeWhere((c) => c.id == commentId);
    _syncPostCommentsCount(postId);
    notifyListeners();
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
