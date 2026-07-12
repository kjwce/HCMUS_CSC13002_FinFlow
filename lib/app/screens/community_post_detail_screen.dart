import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/responsive.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/community/models/community_comment_model.dart';
import '../../features/community/models/community_post_model.dart';
import '../../features/community/presentation/widgets/post_card.dart';
import '../../features/community/providers/community_provider.dart';
import '../../features/community/utils/community_date_format.dart';
import '../../features/community/utils/rich_text_formatter.dart';

// =============================================================================
// COMMUNITY POST DETAIL — matches Figma node 1:1266 ("Post")
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

  static const _bgColor = Color(0xFFF9FBF8);
  static const _headerBg = Color(0xFFD4F4E4);
  static const _primaryGreen = Color(0xFF44BF99);
  static const _textDark = Color(0xFF002117);
  static const _textBody = Color(0xFF404944);
  static const _textMuted = Color(0xFF8E918F);
  static const _white = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(communityServiceProvider).fetchComments(widget.postId);
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
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
      await ref.read(communityServiceProvider).addComment(
            postId: widget.postId,
            content: text,
            isAnonymous: _commentAnonymously,
          );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final post = _findPost(service.posts);
    final comments = service.commentsFor(widget.postId);

    return Scaffold(
      backgroundColor: _bgColor,
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
                              style: TextStyle(color: _textMuted),
                            ),
                    )
                  : ListView(
                      padding: EdgeInsets.all(Responsive.w(context, 16)),
                      children: [
                        CommunityPostCard(
                          post: post,
                          maxLines: null,
                          onTap: () {},
                          onLikeTap: () => _toggleLike(post),
                          onSaveTap: () => _toggleSave(post),
                        ),
                        SizedBox(height: Responsive.h(context, 8)),
                        Text(
                          comments.isEmpty
                              ? 'No comments yet'
                              : '${comments.length} comment${comments.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: Responsive.sp(context, 13),
                            color: _textDark,
                          ),
                        ),
                        SizedBox(height: Responsive.h(context, 10)),
                        ...comments.map(
                          (c) => _CommentTile(comment: c),
                        ),
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
            child: Icon(Icons.arrow_back_ios_new,
                size: Responsive.w(context, 18), color: _textDark),
          ),
          Expanded(
            child: Text(
              'Post',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                fontSize: Responsive.sp(context, 18),
                color: _textDark,
              ),
            ),
          ),
          Container(
            width: Responsive.w(context, 36),
            height: Responsive.h(context, 36),
            decoration: const BoxDecoration(
              color: _white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: Responsive.w(context, 18),
              color: _primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBar() {
    final isSignedIn = AuthService.instance.currentUser != null;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 16),
          vertical: Responsive.h(context, 10),
        ),
        decoration: BoxDecoration(
          color: _white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () =>
                  setState(() => _commentAnonymously = !_commentAnonymously),
              child: Container(
                width: Responsive.w(context, 32),
                height: Responsive.w(context, 32),
                decoration: BoxDecoration(
                  color: _commentAnonymously ? _primaryGreen : _headerBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _commentAnonymously
                      ? Icons.visibility_off
                      : Icons.person_outline,
                  size: Responsive.w(context, 16),
                  color: _commentAnonymously ? _white : _textDark,
                ),
              ),
            ),
            SizedBox(width: Responsive.w(context, 10)),
            Expanded(
              child: TextField(
                controller: _commentController,
                enabled: isSignedIn && !_isSending,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
                decoration: InputDecoration(
                  hintText:
                      isSignedIn ? 'Write a comment...' : 'Sign in to comment',
                  hintStyle: TextStyle(
                    color: _textMuted,
                    fontSize: Responsive.sp(context, 13),
                  ),
                  filled: true,
                  fillColor: _headerBg.withValues(alpha: 0.5),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: Responsive.w(context, 14)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: Responsive.w(context, 8)),
            GestureDetector(
              onTap: isSignedIn ? _submitComment : null,
              child: Container(
                width: Responsive.w(context, 32),
                height: Responsive.w(context, 32),
                decoration: const BoxDecoration(
                  color: _primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? Padding(
                        padding: EdgeInsets.all(Responsive.w(context, 8)),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _white,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        size: Responsive.w(context, 14),
                        color: _white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CommunityCommentModel comment;

  static const _textDark = Color(0xFF002117);
  static const _textBody = Color(0xFF404944);
  static const _textMuted = Color(0xFF8E918F);
  static const _headerBg = Color(0xFFD4F4E4);
  static const _white = Color(0xFFFFFFFF);

  static const _avatarPalette = [
    Color(0xFF7C5CFC),
    Color(0xFF3799D2),
    Color(0xFF44BF99),
    Color(0xFFE8A23D),
    Color(0xFFE86B5D),
  ];

  Color get _avatarColor {
    final hash = comment.displayName.codeUnits.fold<int>(0, (a, b) => a + b);
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
    return Container(
      margin: EdgeInsets.only(
        left: Responsive.w(context, 12),
        bottom: Responsive.h(context, 10),
      ),
      padding: EdgeInsets.all(Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: _headerBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF44BF99), width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: Responsive.w(context, 14),
            backgroundColor: _avatarColor,
            child: Text(
              _initials.toUpperCase(),
              style: TextStyle(
                color: _white,
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 10.5),
              ),
            ),
          ),
          SizedBox(width: Responsive.w(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: Responsive.sp(context, 12.5),
                        color: _textDark,
                      ),
                    ),
                    SizedBox(width: Responsive.w(context, 6)),
                    Text(
                      formatCommunityDate(comment.createdAt),
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 10.5),
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 4)),
                RichPostContent(
                  content: comment.content,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 12.5),
                    color: _textBody,
                    height: 1.35,
                  ),
                  spoilerColor: _textDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
