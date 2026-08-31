import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/community/models/community_comment_model.dart';
import '../../features/community/models/community_post_model.dart';
import '../../features/community/models/community_report_model.dart';
import '../../features/community/presentation/community_composer_screen.dart';
import '../../features/community/presentation/widgets/community_report_dialog.dart';
import '../../features/community/presentation/widgets/post_card.dart';
import '../../features/community/providers/community_provider.dart';
import '../../features/community/services/community_service.dart';
import '../../features/community/utils/community_date_format.dart';
import '../../features/community/utils/comment_thread.dart';
import '../../features/community/utils/rich_text_formatter.dart';

// =============================================================================
// COMMUNITY POST DETAIL — Deeper Mint Theme
// Matches Stitch screen "Post Details - Deeper Mint Theme"
// =============================================================================

class CommunityPostDetailScreen extends ConsumerStatefulWidget {
  const CommunityPostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState
    extends ConsumerState<CommunityPostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final Set<String> _expandedCommentIds = {};
  CommunityCommentModel? _replyingTo;
  bool _commentAnonymously = false;
  bool _isSending = false;
  bool _loaded = false;
  int _visibleCommentCount = 5;
  late final CommunityService _communityService;

  // ── Deeper Mint Theme Palette ──
  static const _headerBg = Color(0xFFDDF3EA);
  static const _headerText = Color(0xFF006B52);
  static const _primaryGreen = Color(0xFF00C49A);
  static const _textDark = Color(0xFF002117);
  static const _white = Color(0xFFFFFFFF);
  static const _commentBg = Color(0xFFD4F4E4);
  static const _sendGreen = Color(0xFF00513E);
  static const _darkPage = Color(0xFF081C18);
  static const _darkSurface = Color(0xFF16352E);
  static const _darkRaisedSurface = Color(0xFF1C4037);
  static const _darkBorder = Color(0xFF29483F);
  static const _darkText = Color(0xFFF4FBF8);
  static const _darkSecondaryText = Color(0xFFA9C1B9);
  static const _darkMutedText = Color(0xFF708D84);
  static const _darkMint = Color(0xFF38D6AC);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDark ? _darkPage : context.finFlowColors.pageBackground;
  Color get _surface => _isDark ? _darkSurface : context.finFlowColors.surface;
  Color get _raisedSurface =>
      _isDark ? _darkRaisedSurface : context.finFlowColors.inputBackground;
  Color get _border => _isDark ? _darkBorder : context.finFlowColors.divider;
  Color get _primaryText =>
      _isDark ? _darkText : context.finFlowColors.primaryText;
  Color get _secondaryText =>
      _isDark ? _darkSecondaryText : context.finFlowColors.secondaryText;
  Color get _mutedText =>
      _isDark ? _darkMutedText : context.finFlowColors.secondaryText;

  @override
  void initState() {
    super.initState();
    _communityService = ref.read(communityServiceProvider);
    _communityService.addListener(_onCommunityChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = _communityService;
      service.subscribeToComments(widget.postId);

      if (service.hasCachedCommentsFor(widget.postId)) {
        if (mounted) setState(() => _loaded = true);
        unawaited(service.fetchComments(widget.postId));
        return;
      }

      final postIsCached = service.posts.any(
        (post) => post.id == widget.postId,
      );
      if (!postIsCached) {
        await service.fetchPosts();
      }
      if (!service.hasCachedCommentsFor(widget.postId)) {
        await service.fetchComments(widget.postId);
      }
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _communityService.removeListener(_onCommunityChanged);
    _communityService.unsubscribeFromComments(widget.postId);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _onCommunityChanged() {
    if (mounted) setState(() {});
  }

  CommunityPostModel? _findPost(List<CommunityPostModel> posts) {
    for (final p in posts) {
      if (p.id == widget.postId) return p;
    }
    return null;
  }

  Future<void> _toggleLike(CommunityPostModel post) async {
    try {
      await ref.read(communityServiceProvider).toggleLike(post.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.choose(
                'Could not update this like.',
                'Không thể cập nhật lượt thích này.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleSave(CommunityPostModel post) async {
    try {
      await ref.read(communityServiceProvider).toggleSave(post.id);
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _editPost(CommunityPostModel post) async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityComposerScreen(editPost: post),
        fullscreenDialog: true,
      ),
    );
    if (edited == true && mounted) setState(() {});
  }

  Future<void> _deletePost(CommunityPostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.choose('Delete post', 'Xóa bài viết')),
        content: Text(
          AppStrings.choose(
            'Are you sure you want to delete this post?',
            'Bạn có chắc muốn xóa bài viết này không?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AppStrings.choose('Delete', 'Xóa'),
              style: TextStyle(color: context.finFlowColors.negativeAmount),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _communityService.deletePost(post.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Could not delete: $error',
              'Không thể xóa: $error',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _reportPost(CommunityPostModel post) {
    return showCommunityReportDialog(
      context: context,
      target: CommunityReportTarget.post,
      authorName: post.displayName,
      authorAvatarUrl: post.isAnonymous ? null : post.authorAvatarUrl,
      content: post.content,
      onSubmit: (reason, details) => _communityService.reportPost(
        postId: post.id,
        reason: reason,
        description: details,
      ),
    );
  }

  Future<void> _reportComment(CommunityCommentModel comment) {
    return showCommunityReportDialog(
      context: context,
      target: CommunityReportTarget.comment,
      authorName: comment.displayName,
      authorAvatarUrl: comment.isAnonymous ? null : comment.authorAvatarUrl,
      content: comment.content,
      onSubmit: (reason, details) => _communityService.reportComment(
        commentId: comment.id,
        reason: reason,
        description: details,
      ),
    );
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;
    final parentComment = _replyingTo;
    setState(() => _isSending = true);
    try {
      await _communityService.addComment(
        postId: widget.postId,
        content: text,
        isAnonymous: _commentAnonymously,
        parentCommentId: parentComment?.id,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        if (parentComment == null) {
          _visibleCommentCount += 1;
        } else {
          _expandedCommentIds.add(parentComment.id);
        }
        _replyingTo = null;
        _commentAnonymously = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.choose(
                'Could not comment: $e',
                'Không thể bình luận: $e',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _beginReply(CommunityCommentModel comment) {
    setState(() {
      _replyingTo = comment;
      _expandedCommentIds.add(comment.id);
    });
    _commentFocusNode.requestFocus();
  }

  Future<void> _toggleCommentLike(CommunityCommentModel comment) async {
    try {
      await _communityService.toggleCommentLike(
        postId: widget.postId,
        commentId: comment.id,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Could not update this comment like.',
              'Không thể cập nhật lượt thích bình luận.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteComment(CommunityCommentModel comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.choose('Delete comment', 'Xóa bình luận')),
        content: Text(
          AppStrings.choose(
            'Delete this comment and all of its replies?',
            'Xóa bình luận này và tất cả phản hồi của nó?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.choose('Delete', 'Xóa'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _communityService.deleteComment(comment.id, widget.postId);
      if (!mounted) return;
      setState(() {
        if (_replyingTo?.id == comment.id) _replyingTo = null;
        _expandedCommentIds.remove(comment.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose('Could not delete: $e', 'Không thể xóa: $e'),
          ),
        ),
      );
    }
  }

  List<CommunityCommentThreadEntry> _buildVisibleThread(
    List<CommunityCommentModel> comments,
  ) {
    return buildVisibleCommentThread(
      comments: comments,
      visibleRootCount: _visibleCommentCount,
      expandedCommentIds: _expandedCommentIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final post = _findPost(service.posts);
    final allComments = service.commentsFor(widget.postId);
    final rootCommentCount = allComments
        .where((comment) => comment.parentCommentId == null)
        .length;
    final showComments = _buildVisibleThread(allComments);
    final hasMore = rootCommentCount > _visibleCommentCount;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: post == null
                  ? Center(
                      child: !_loaded
                          ? const CircularProgressIndicator()
                          : Text(
                              AppStrings.choose(
                                'This post is no longer available.',
                                'Bài viết này không còn tồn tại.',
                              ),
                              style: TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                color: _mutedText,
                              ),
                            ),
                    )
                  : ListView(
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.h(context, 16),
                      ),
                      children: [
                        // ── Post Card (full content) ──
                        CommunityPostCard(
                          post: post,
                          maxLines: null,
                          currentUserId: AuthService.instance.currentUser?.id,
                          onTap: () {},
                          onLikeTap: () => _toggleLike(post),
                          onSaveTap: () => _toggleSave(post),
                          onEditTap: () => _editPost(post),
                          onDeleteTap: () => _deletePost(post),
                          onReportTap: () => _reportPost(post),
                        ),

                        SizedBox(height: Responsive.h(context, 20)),

                        // ── Comments Section ──
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(context, 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppStrings.choose('COMMENTS', 'BÌNH LUẬN'),
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w700,
                                  fontSize: Responsive.sp(context, 16),
                                  color: _primaryText,
                                ),
                              ),
                              Text(
                                AppStrings.choose(
                                  '${allComments.length} comment${allComments.length == 1 ? '' : 's'}',
                                  '${allComments.length} bình luận',
                                ),
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontSize: Responsive.sp(context, 13),
                                  color: _secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: Responsive.h(context, 14)),

                        // ── Comment List ──
                        if (allComments.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.h(context, 24),
                            ),
                            child: Center(
                              child: Text(
                                AppStrings.choose(
                                  'No comments yet.\nBe the first to share your thoughts!',
                                  'Chưa có bình luận nào.\nHãy là người đầu tiên chia sẻ suy nghĩ!',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontSize: Responsive.sp(context, 13),
                                  color: _mutedText,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          ...showComments.map((threadComment) {
                            final comment = threadComment.comment;
                            final displayDepth = threadComment.depth > 4
                                ? 4
                                : threadComment.depth;
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                Responsive.w(context, 16 + (displayDepth * 14)),
                                0,
                                Responsive.w(context, 16),
                                0,
                              ),
                              child: Container(
                                padding: threadComment.depth == 0
                                    ? EdgeInsets.zero
                                    : EdgeInsets.only(
                                        left: Responsive.w(context, 8),
                                      ),
                                decoration: threadComment.depth == 0
                                    ? null
                                    : BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: _border,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                child: _CommentTile(
                                  comment: comment,
                                  currentUserId:
                                      AuthService.instance.currentUser?.id,
                                  directReplyCount:
                                      threadComment.directReplyCount,
                                  repliesExpanded: _expandedCommentIds.contains(
                                    comment.id,
                                  ),
                                  onLike: () => _toggleCommentLike(comment),
                                  onReply: () => _beginReply(comment),
                                  onToggleReplies:
                                      threadComment.directReplyCount == 0
                                      ? null
                                      : () => setState(() {
                                          if (!_expandedCommentIds.remove(
                                            comment.id,
                                          )) {
                                            _expandedCommentIds.add(comment.id);
                                          }
                                        }),
                                  onDelete: () =>
                                      _confirmDeleteComment(comment),
                                  onReport: () => _reportComment(comment),
                                ),
                              ),
                            );
                          }),
                          // ── View More ──
                          if (hasMore)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _visibleCommentCount += 10;
                              }),
                              iconAlignment: IconAlignment.end,
                              icon: Icon(
                                Icons.expand_more,
                                size: Responsive.w(context, 20),
                              ),
                              label: Text(
                                AppStrings.choose(
                                  'View ${rootCommentCount - _visibleCommentCount} more comments',
                                  'Xem thêm ${rootCommentCount - _visibleCommentCount} bình luận',
                                ),
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontWeight: FontWeight.w600,
                                  fontSize: Responsive.sp(context, 13),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _isDark
                                    ? _darkMint
                                    : _primaryGreen,
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
            if (post != null) _buildCommentBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _isDark ? _darkPage : _headerBg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.symmetric(
        vertical: Responsive.h(context, 14),
        horizontal: Responsive.w(context, 16),
      ),
      width: double.infinity,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: Responsive.w(context, 36),
              height: Responsive.w(context, 36),
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: Responsive.w(context, 16),
                color: _isDark ? _darkMint : _headerText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.choose('Post', 'Bài viết'),
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 22),
                color: _isDark ? _darkText : AppColors.deepEmerald,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBar() {
    final currentUser = AuthService.instance.currentUser;
    final isSignedIn = currentUser != null;
    final avatarUrl = currentUser?.avatarUrl?.trim();
    final fullName = currentUser?.fullName.trim() ?? '';
    final initial = fullName.isEmpty ? '?' : fullName[0].toUpperCase();

    Widget profileFallback() {
      if (!isSignedIn) {
        return Icon(
          Icons.person_outline,
          size: Responsive.w(context, 18),
          color: _isDark ? _darkText : _textDark,
        );
      }
      return Center(
        child: Text(
          initial,
          style: TextStyle(
            color: _isDark ? _darkText : _textDark,
            fontWeight: FontWeight.w700,
            fontSize: Responsive.sp(context, 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 12),
        Responsive.h(context, 8),
        Responsive.w(context, 12),
        Responsive.h(context, 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null) ...[
            Row(
              children: [
                Icon(
                  Icons.reply_rounded,
                  size: Responsive.w(context, 16),
                  color: _isDark ? _darkMint : _headerText,
                ),
                SizedBox(width: Responsive.w(context, 6)),
                Expanded(
                  child: Text(
                    AppStrings.choose(
                      'Replying to ${_replyingTo!.displayName}',
                      'Đang trả lời ${_replyingTo!.displayName}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 12),
                      fontWeight: FontWeight.w600,
                      color: _primaryText,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _replyingTo = null),
                  tooltip: AppStrings.choose('Cancel reply', 'Hủy trả lời'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    size: Responsive.w(context, 17),
                    color: _secondaryText,
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(context, 4)),
          ],
          Row(
            children: [
              // Anonymous toggle
              Tooltip(
                message: _commentAnonymously
                    ? AppStrings.choose(
                        'Post with your profile',
                        'Bình luận bằng hồ sơ',
                      )
                    : AppStrings.choose(
                        'Comment anonymously',
                        'Bình luận ẩn danh',
                      ),
                child: Material(
                  color: _commentAnonymously
                      ? (_isDark ? const Color(0xFF006C53) : _primaryGreen)
                      : (_isDark
                            ? _darkRaisedSurface
                            : _commentBg.withValues(alpha: 0.5)),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(
                      () => _commentAnonymously = !_commentAnonymously,
                    ),
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: Responsive.w(context, 40),
                      height: Responsive.w(context, 40),
                      child: _commentAnonymously
                          ? Icon(
                              Icons.visibility_off,
                              size: Responsive.w(context, 18),
                              color: _white,
                            )
                          : avatarUrl?.isNotEmpty == true
                          ? Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => profileFallback(),
                            )
                          : profileFallback(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(context, 8)),
              // Text field
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 16),
                  ),
                  decoration: BoxDecoration(
                    color: _raisedSurface,
                    borderRadius: BorderRadius.circular(
                      Responsive.w(context, 20),
                    ),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    enabled: isSignedIn && !_isSending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: isSignedIn
                          ? _replyingTo == null
                                ? AppStrings.choose(
                                    'Write a comment...',
                                    'Viết bình luận...',
                                  )
                                : AppStrings.choose(
                                    'Write a reply...',
                                    'Viết phản hồi...',
                                  )
                          : AppStrings.choose(
                              'Sign in to comment',
                              'Đăng nhập để bình luận',
                            ),
                      hintStyle: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        color: _secondaryText,
                        fontSize: Responsive.sp(context, 13),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: Responsive.h(context, 10),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(context, 8)),
              // Send button
              Material(
                color: isSignedIn
                    ? (_isDark ? const Color(0xFF006C53) : _sendGreen)
                    : context.finFlowColors.disabled,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: isSignedIn ? _submitComment : null,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: Responsive.w(context, 40),
                    height: Responsive.w(context, 40),
                    child: _isSending
                        ? Padding(
                            padding: EdgeInsets.all(Responsive.w(context, 10)),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _white,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            size: Responsive.w(context, 18),
                            color: isSignedIn
                                ? _white
                                : _white.withValues(alpha: 0.5),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMMENT TILE
// =============================================================================

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.directReplyCount,
    required this.repliesExpanded,
    required this.onLike,
    required this.onReply,
    this.currentUserId,
    this.onToggleReplies,
    this.onDelete,
    this.onReport,
  });

  final CommunityCommentModel comment;
  final int directReplyCount;
  final bool repliesExpanded;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final String? currentUserId;
  final VoidCallback? onToggleReplies;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  static const _white = Color(0xFFFFFFFF);
  static const _darkSurface = Color(0xFF16352E);
  static const _darkBorder = Color(0xFF29483F);
  static const _darkText = Color(0xFFF4FBF8);
  static const _darkSecondaryText = Color(0xFFA9C1B9);
  static const _darkMutedText = Color(0xFF708D84);
  static const _darkMint = Color(0xFF38D6AC);

  static const _avatarPalette = [
    Color(0xFF7C5CFC),
    Color(0xFF3799D2),
    Color(0xFF44BF99),
    Color(0xFFE8A23D),
    Color(0xFFE86B5D),
  ];

  Color get _avatarColor {
    final key = comment.userId.isNotEmpty
        ? comment.userId
        : comment.displayName;
    final hash = key.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarPalette[hash % _avatarPalette.length];
  }

  String get _initials {
    final name = comment.displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1);
    }
    return '${parts.first[0]}${parts.last[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = currentUserId != null && comment.userId == currentUserId;
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(context, 10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: Responsive.w(context, 16),
            backgroundColor: _avatarColor,
            backgroundImage: comment.authorAvatarUrl?.isNotEmpty == true
                ? NetworkImage(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl?.isNotEmpty == true
                ? null
                : Text(
                    _initials.toUpperCase(),
                    style: TextStyle(
                      color: _white,
                      fontWeight: FontWeight.w700,
                      fontSize: Responsive.sp(context, 11),
                    ),
                  ),
          ),
          SizedBox(width: Responsive.w(context, 10)),
          // Content
          Expanded(
            child: Container(
              padding: EdgeInsets.all(Responsive.w(context, 12)),
              decoration: BoxDecoration(
                color: isDark ? _darkSurface : colors.surface,
                borderRadius: BorderRadius.circular(Responsive.w(context, 12)),
                border: Border.all(
                  color: isDark ? _darkBorder : colors.divider,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(
                            0xFF006C53,
                          ).withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: Responsive.sp(context, 12.5),
                            color: isDark ? _darkText : colors.primaryText,
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.w(context, 6)),
                      Text(
                        formatCommunityDate(comment.createdAt),
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 10.5),
                          color: isDark
                              ? _darkSecondaryText
                              : colors.secondaryText,
                        ),
                      ),
                      if (currentUserId != null)
                        PopupMenuButton<String>(
                          tooltip: AppStrings.choose(
                            'Comment options',
                            'Tùy chọn bình luận',
                          ),
                          position: PopupMenuPosition.under,
                          color: isDark ? _darkSurface : colors.surface,
                          surfaceTintColor: Colors.transparent,
                          constraints: BoxConstraints(
                            minWidth: Responsive.w(context, 166),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark ? _darkBorder : colors.divider,
                            ),
                          ),
                          onSelected: (value) {
                            if (value == 'delete') onDelete?.call();
                            if (value == 'report') onReport?.call();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: isOwner ? 'delete' : 'report',
                              child: Row(
                                children: [
                                  Icon(
                                    isOwner
                                        ? Icons.delete_outline_rounded
                                        : Icons.outlined_flag_rounded,
                                    size: Responsive.w(context, 18),
                                    color: const Color(0xFFE86B5D),
                                  ),
                                  SizedBox(width: Responsive.w(context, 10)),
                                  Text(
                                    isOwner
                                        ? AppStrings.choose(
                                            'Delete comment',
                                            'Xóa bình luận',
                                          )
                                        : AppStrings.choose(
                                            'Report comment',
                                            'Báo cáo bình luận',
                                          ),
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontSize: Responsive.sp(context, 13),
                                      fontWeight: FontWeight.w600,
                                      color: isOwner
                                          ? const Color(0xFFE86B5D)
                                          : (isDark
                                                ? _darkText
                                                : colors.primaryText),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            size: Responsive.w(context, 16),
                            color: isDark
                                ? _darkMutedText
                                : colors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(context, 6)),
                  RichPostContent(
                    content: comment.content,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 13),
                      color: isDark ? _darkText : colors.primaryText,
                      height: 1.4,
                    ),
                    spoilerColor: isDark ? _darkText : colors.primaryText,
                  ),
                  SizedBox(height: Responsive.h(context, 8)),
                  Wrap(
                    spacing: Responsive.w(context, 14),
                    runSpacing: Responsive.h(context, 4),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _CommentAction(
                        onTap: onLike,
                        color: comment.isLikedByMe
                            ? (isDark ? _darkMint : const Color(0xFF008D6A))
                            : (isDark ? _darkMutedText : colors.secondaryText),
                        icon: comment.isLikedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: comment.likesCount == 0
                            ? AppStrings.choose('Like', 'Thích')
                            : '${comment.likesCount}',
                      ),
                      _CommentAction(
                        onTap: onReply,
                        color: isDark ? _darkMutedText : colors.secondaryText,
                        icon: Icons.reply_rounded,
                        label: AppStrings.choose('Reply', 'Trả lời'),
                      ),
                      if (directReplyCount > 0)
                        _CommentAction(
                          onTap: onToggleReplies!,
                          color: isDark ? _darkMint : const Color(0xFF008D6A),
                          icon: repliesExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          label: repliesExpanded
                              ? AppStrings.choose('Hide replies', 'Ẩn phản hồi')
                              : AppStrings.choose(
                                  'View replies ($directReplyCount)',
                                  'Xem phản hồi ($directReplyCount)',
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({
    required this.onTap,
    required this.color,
    required this.icon,
    required this.label,
  });

  final VoidCallback onTap;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 2),
          vertical: Responsive.h(context, 3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Responsive.w(context, 14), color: color),
            SizedBox(width: Responsive.w(context, 4)),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: Responsive.sp(context, 11),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
