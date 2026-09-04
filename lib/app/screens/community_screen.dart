import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/finflow_action_icon.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/community/models/community_post_model.dart';
import '../../features/community/models/community_report_model.dart';
import '../../features/community/presentation/community_composer_screen.dart';
import '../../features/community/presentation/widgets/community_report_dialog.dart';
import '../../features/community/presentation/widgets/post_card.dart';
import '../../features/community/presentation/widgets/post_removal_animation.dart';
import '../../features/community/providers/community_provider.dart';
import '../../features/community/services/community_service.dart';
import '../../features/community/utils/community_topics.dart';
import 'community_post_detail_screen.dart';

// =============================================================================
// COMMUNITY SCREEN — topic-driven social feed
// =============================================================================

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _selectedTopic = communityFeedTopics.first;
  bool _loaded = false;
  final Set<String> _removingPostIds = <String>{};
  late final CommunityService _communityService;

  // ── Deeper Mint Theme Palette ──
  static const _headerBg = Color(0xFFF0F9F4);
  static const _headerText = Color(0xFF006B52);
  static const _primaryGreen = Color(0xFF00C49A);
  static const _white = Color(0xFFFFFFFF);
  static const _cardShadow = Color(0xFF006C53);
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
  Color get _border => _isDark ? _darkBorder : context.finFlowColors.divider;
  Color get _secondaryText =>
      _isDark ? _darkSecondaryText : context.finFlowColors.secondaryText;
  Color get _mutedText =>
      _isDark ? _darkMutedText : context.finFlowColors.secondaryText;

  @override
  void initState() {
    super.initState();
    _communityService = ref.read(communityServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = _communityService;
      service.subscribeToRealtime();
      await service.fetchPosts();
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _communityService.disposeRealtime();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(communityServiceProvider).fetchPosts();
    if (mounted) setState(() {});
  }

  Future<void> _toggleLike(CommunityPostModel post) async {
    try {
      await ref.read(communityServiceProvider).toggleLike(post.id);
      if (mounted) setState(() {});
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
        setState(() {});
      }
    }
  }

  Future<void> _toggleSave(CommunityPostModel post) async {
    try {
      await ref.read(communityServiceProvider).toggleSave(post.id);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _deletePost(CommunityPostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.choose('Delete post', 'Xóa bài viết')),
        content: Text(
          AppStrings.choose(
            'Are you sure you want to delete this post?',
            'Bạn có chắc muốn xóa bài viết này không?',
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
    if (confirm == true && mounted) {
      setState(() => _removingPostIds.add(post.id));
      await Future<void>.delayed(PostRemovalAnimation.duration);
      if (!mounted) return;
      try {
        await ref.read(communityServiceProvider).deletePost(post.id);
      } catch (e) {
        if (mounted) {
          setState(() => _removingPostIds.remove(post.id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.choose('Could not delete: $e', 'Không thể xóa: $e'),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _editPost(CommunityPostModel post) async {
    if (AuthService.instance.currentUser == null) return;
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityComposerScreen(editPost: post),
        fullscreenDialog: true,
      ),
    );
    if (edited == true && mounted) setState(() {});
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

  void _openPost(CommunityPostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailScreen(postId: post.id),
      ),
    );
  }

  Future<void> _openComposer() async {
    if (AuthService.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose('Sign in to post.', 'Đăng nhập để đăng bài.'),
          ),
        ),
      );
      return;
    }
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CommunityComposerScreen(),
        fullscreenDialog: true,
      ),
    );
    if (posted == true && mounted) {
      setState(() => _selectedTopic = communityFeedTopics.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final user = ref.watch(authServiceProvider).currentUser;
    final posts = service.postsForTopic(_selectedTopic);

    return DecoratedBox(
      decoration: BoxDecoration(color: _pageBackground),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(
              avatarUrl: user?.avatarUrl?.trim(),
              displayName: user?.fullName.trim().isNotEmpty == true
                  ? user!.fullName.trim()
                  : AppStrings.choose('FinFlow User', 'Người dùng FinFlow'),
            ),
            _buildTopicFilters(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: !_loaded && service.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: posts.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    padding: EdgeInsets.only(
                                      top: Responsive.h(context, 4),
                                      bottom: Responsive.h(context, 108),
                                    ),
                                    itemCount: posts.length,
                                    itemBuilder: (_, i) {
                                      final post = posts[i];
                                      return PostRemovalAnimation(
                                        key: ValueKey('post-${post.id}'),
                                        removing: _removingPostIds.contains(
                                          post.id,
                                        ),
                                        child: CommunityPostCard(
                                          post: post,
                                          currentUserId: AuthService
                                              .instance
                                              .currentUser
                                              ?.id,
                                          onTap: () => _openPost(post),
                                          onLikeTap: () => _toggleLike(post),
                                          onSaveTap: () => _toggleSave(post),
                                          onEditTap: () => _editPost(post),
                                          onDeleteTap: () => _deletePost(post),
                                          onReportTap: () => _reportPost(post),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: Responsive.h(context, 2),
                    child: _buildComposeEntry(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required String displayName, String? avatarUrl}) {
    return Container(
      decoration: BoxDecoration(
        color: _isDark ? _darkPage : _headerBg,
        border: Border(
          bottom: BorderSide(color: _isDark ? _darkBorder : Colors.transparent),
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: Responsive.h(context, 14),
        horizontal: Responsive.w(context, 20),
      ),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: Responsive.w(context, 42),
                height: Responsive.w(context, 42),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xFF006C53)
                      : const Color(0xFF8DE6C4),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _headerAvatarFallback(displayName),
                        )
                      : _headerAvatarFallback(displayName),
                ),
              ),
              SizedBox(width: Responsive.w(context, 10)),
              Text(
                AppStrings.choose('Financial Advice', 'Tư vấn tài chính'),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.sp(context, 20),
                  color: _isDark ? _darkText : _headerText,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _openComposer,
            child: Container(
              width: Responsive.w(context, 40),
              height: Responsive.w(context, 40),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF00D09C) : _primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _cardShadow.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FinFlowPencilIcon(
                size: Responsive.w(context, 20),
                color: _white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAvatarFallback(String displayName) {
    return ColoredBox(
      color: _isDark ? const Color(0xFF006C53) : AppColors.lightGreen,
      child: Center(
        child: Text(
          displayName.trim().isEmpty
              ? '?'
              : displayName.trim().substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: _isDark ? _darkText : const Color(0xFF006C52),
            fontSize: Responsive.sp(context, 16),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildTopicFilters() {
    return Container(
      color: _isDark ? _darkPage : _surface,
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 10)),
      child: SizedBox(
        height: Responsive.h(context, 34),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
          itemCount: communityFeedTopics.length,
          separatorBuilder: (_, _) => SizedBox(width: Responsive.w(context, 8)),
          itemBuilder: (_, index) {
            final topic = communityFeedTopics[index];
            final selected = topic == _selectedTopic;
            return ChoiceChip(
              label: Text(communityTopicLabel(topic)),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedTopic = topic),
              labelStyle: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontWeight: FontWeight.w600,
                fontSize: Responsive.sp(context, 12),
                color: selected ? _white : _secondaryText,
              ),
              selectedColor: _isDark
                  ? const Color(0xFF006C53)
                  : AppColors.deepEmerald,
              backgroundColor: _surface,
              side: BorderSide(
                color: selected
                    ? (_isDark
                          ? const Color(0xFF006C53)
                          : AppColors.deepEmerald)
                    : _border,
              ),
              shape: const StadiumBorder(),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 8),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _selectedTopic == 'All'
        ? AppStrings.choose(
            'No posts yet.\nBe the first to share a money tip!',
            'Chưa có bài viết nào.\nHãy là người đầu tiên chia sẻ mẹo tài chính!',
          )
        : AppStrings.choose(
            'No posts in ${communityTopicLabel(_selectedTopic)} yet.\nStart the conversation!',
            'Chưa có bài viết trong ${communityTopicLabel(_selectedTopic)}.\nHãy bắt đầu cuộc trò chuyện!',
          );
    return ListView(
      padding: EdgeInsets.only(top: Responsive.h(context, 40)),
      children: [
        Icon(
          Icons.forum_outlined,
          size: Responsive.w(context, 56),
          color: _mutedText.withValues(alpha: 0.65),
        ),
        SizedBox(height: Responsive.h(context, 16)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 14),
            color: _mutedText,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildComposeEntry() {
    final user = AuthService.instance.currentUser;
    final isSignedIn = user != null;
    final avatarUrl = user?.avatarUrl;
    final displayName = user?.fullName.trim() ?? '';
    final initial = displayName.isEmpty ? '?' : displayName[0].toUpperCase();
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 12),
        Responsive.h(context, 8),
        Responsive.w(context, 12),
        Responsive.h(context, 12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _isDark ? _darkRaisedSurface : _surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _border.withValues(alpha: 0.9)),
          boxShadow: _isDark
              ? const [
                  BoxShadow(
                    color: Color(0x52000000),
                    blurRadius: 20,
                    offset: Offset(0, 7),
                  ),
                ]
              : [
                  BoxShadow(
                    color: _cardShadow.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.08),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openComposer,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 10),
                vertical: Responsive.h(context, 9),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: Responsive.w(context, 22),
                    backgroundColor: _isDark
                        ? const Color(0xFF006C53)
                        : _headerText,
                    backgroundImage: avatarUrl?.isNotEmpty == true
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl?.isNotEmpty == true
                        ? null
                        : isSignedIn
                        ? Text(
                            initial,
                            style: TextStyle(
                              color: _white,
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.sp(context, 18),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: Responsive.w(context, 20),
                            color: _white,
                          ),
                  ),
                  SizedBox(width: Responsive.w(context, 18)),
                  Expanded(
                    child: Text(
                      isSignedIn
                          ? AppStrings.choose(
                              "What's on your mind?",
                              'Bạn đang nghĩ gì?',
                            )
                          : AppStrings.choose(
                              'Sign in to post',
                              'Đăng nhập để đăng bài',
                            ),
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 16),
                        color: _secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    width: Responsive.w(context, 44),
                    height: Responsive.w(context, 44),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF006C53)
                          : const Color(0xFFCFF8E8),
                      shape: BoxShape.circle,
                    ),
                    child: FinFlowPencilIcon(
                      size: Responsive.w(context, 21),
                      color: _isDark ? _darkMint : _headerText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
