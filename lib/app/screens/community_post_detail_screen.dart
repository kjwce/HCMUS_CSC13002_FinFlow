import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/community/models/community_comment_model.dart';
import '../../features/community/models/community_post_model.dart';
import '../../features/community/presentation/widgets/post_card.dart';
import '../../features/community/providers/community_provider.dart';
import '../../features/community/services/community_service.dart';
import '../../features/community/utils/community_date_format.dart';
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
  static const _textMuted = Color(0xFF8E918F);
  static const _white = Color(0xFFFFFFFF);
  static const _commentBg = Color(0xFFD4F4E4);
  static const _sendGreen = Color(0xFF00513E);

  @override
  void initState() {
    super.initState();
    _communityService = ref.read(communityServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = _communityService;
      service.subscribeToComments(widget.postId);
      await service.fetchPosts();
      await service.fetchComments(widget.postId);
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _communityService.unsubscribeFromComments(widget.postId);
    _commentController.dispose();
    super.dispose();
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
          const SnackBar(content: Text('Could not update this like.')),
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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await _communityService.addComment(
        postId: widget.postId,
        content: text,
        isAnonymous: _commentAnonymously,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _visibleCommentCount = _communityService
            .commentsFor(widget.postId)
            .length;
        _commentAnonymously = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final colors = context.finFlowColors;
    final post = _findPost(service.posts);
    final allComments = service.commentsFor(widget.postId);
    final firstVisibleIndex = allComments.length > _visibleCommentCount
        ? allComments.length - _visibleCommentCount
        : 0;
    final showComments = allComments.skip(firstVisibleIndex).toList();
    final hasMore = allComments.length > _visibleCommentCount;

    return Scaffold(
      backgroundColor: colors.pageBackground,
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
                              'This post is no longer available.',
                              style: TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                color: _textMuted,
                              ),
                            ),
                    )
                  : ListView(
                      padding: EdgeInsets.all(Responsive.w(context, 16)),
                      children: [
                        // ── Post Card (full content) ──
                        CommunityPostCard(
                          post: post,
                          maxLines: null,
                          onTap: () {},
                          onLikeTap: () => _toggleLike(post),
                          onSaveTap: () => _toggleSave(post),
                        ),

                        SizedBox(height: Responsive.h(context, 20)),

                        // ── Comments Section ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'COMMENTS',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w700,
                                fontSize: Responsive.sp(context, 16),
                                color: colors.primaryText,
                              ),
                            ),
                            Text(
                              '${allComments.length} comment${allComments.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontSize: Responsive.sp(context, 13),
                                color: colors.secondaryText,
                              ),
                            ),
                          ],
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
                                'No comments yet.\nBe the first to share your thoughts!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontSize: Responsive.sp(context, 13),
                                  color: _textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          ...showComments.map(
                            (c) => _CommentTile(
                              comment: c,
                              currentUserId:
                                  AuthService.instance.currentUser?.id,
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete comment'),
                                    content: const Text('Are you sure?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await ref
                                        .read(communityServiceProvider)
                                        .deleteComment(c.id, widget.postId);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not delete: $e'),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ),
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
                                'View ${allComments.length - _visibleCommentCount} more comments',
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontWeight: FontWeight.w600,
                                  fontSize: Responsive.sp(context, 13),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _primaryGreen,
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
    final colors = context.finFlowColors;
    return Container(
      color: _headerBg,
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
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: Responsive.w(context, 16),
                color: _headerText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Post',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w600,
                fontSize: Responsive.sp(context, 18),
                color: Theme.of(context).brightness == Brightness.dark
                    ? colors.primaryText
                    : _headerText,
              ),
            ),
          ),
          Container(
            width: Responsive.w(context, 36),
            height: Responsive.w(context, 36),
            decoration: BoxDecoration(
              color: _primaryGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: Responsive.w(context, 18),
              color: _headerText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBar() {
    final currentUser = AuthService.instance.currentUser;
    final isSignedIn = currentUser != null;
    final colors = context.finFlowColors;
    final avatarUrl = currentUser?.avatarUrl?.trim();
    final fullName = currentUser?.fullName.trim() ?? '';
    final initial = fullName.isEmpty ? '?' : fullName[0].toUpperCase();

    Widget profileFallback() {
      if (!isSignedIn) {
        return Icon(
          Icons.person_outline,
          size: Responsive.w(context, 18),
          color: _textDark,
        );
      }
      return Center(
        child: Text(
          initial,
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w700,
            fontSize: Responsive.sp(context, 13),
          ),
        ),
      );
    }

    return Container(
      color: colors.surface,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 12),
        Responsive.h(context, 8),
        Responsive.w(context, 12),
        Responsive.h(context, 10),
      ),
      child: Row(
        children: [
          // Anonymous toggle
          Tooltip(
            message: _commentAnonymously
                ? 'Post with your profile'
                : 'Comment anonymously',
            child: Material(
              color: _commentAnonymously
                  ? _primaryGreen
                  : _commentBg.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () =>
                    setState(() => _commentAnonymously = !_commentAnonymously),
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
                color: colors.inputBackground,
                borderRadius: BorderRadius.circular(Responsive.w(context, 20)),
              ),
              child: TextField(
                controller: _commentController,
                enabled: isSignedIn && !_isSending,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
                decoration: InputDecoration(
                  hintText: isSignedIn
                      ? 'Write a comment...'
                      : 'Sign in to comment',
                  hintStyle: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    color: colors.secondaryText,
                    fontSize: Responsive.sp(context, 13),
                  ),
                  border: InputBorder.none,
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
            color: isSignedIn ? _sendGreen : colors.disabled,
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
    );
  }
}

// =============================================================================
// COMMENT TILE
// =============================================================================

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    this.currentUserId,
    this.onDelete,
  });

  final CommunityCommentModel comment;
  final String? currentUserId;
  final VoidCallback? onDelete;

  static const _white = Color(0xFFFFFFFF);

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
                color: colors.surface,
                borderRadius: BorderRadius.circular(Responsive.w(context, 12)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF006C53).withValues(alpha: 0.05),
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
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.w(context, 6)),
                      Text(
                        formatCommunityDate(comment.createdAt),
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 10.5),
                          color: colors.secondaryText,
                        ),
                      ),
                      const Spacer(),
                      if (isOwner)
                        IconButton(
                          onPressed: onDelete,
                          tooltip: 'Comment options',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.more_horiz,
                            size: Responsive.w(context, 16),
                            color: colors.secondaryText,
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
                      color: colors.primaryText,
                      height: 1.4,
                    ),
                    spoilerColor: colors.primaryText,
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
