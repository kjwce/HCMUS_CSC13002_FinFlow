import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/community/models/community_post_model.dart';
import '../../features/community/presentation/community_composer_screen.dart';
import '../../features/community/presentation/widgets/post_card.dart';
import '../../features/community/providers/community_provider.dart';
import '../../features/community/services/community_service.dart';
import 'community_post_detail_screen.dart';

// =============================================================================
// COMMUNITY SCREEN — Deeper Mint Theme
// Matches Stitch screen "Community Feed - Deeper Mint Theme"
// =============================================================================

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  int _selectedTab = 0; // 0 = post, 1 = like, 2 = save
  bool _loaded = false;
  late final CommunityService _communityService;

  // ── Deeper Mint Theme Palette ──
  static const _headerBg = Color(0xFFF0F9F4);
  static const _headerText = Color(0xFF006B52);
  static const _primaryGreen = Color(0xFF00C49A);
  static const _textMuted = Color(0xFF8E918F);
  static const _white = Color(0xFFFFFFFF);
  static const _tabActiveBg = Color(0xFF00C49A);
  static const _tabActiveText = _white;
  static const _cardShadow = Color(0xFF006C53);

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
          const SnackBar(content: Text('Could not update this like.')),
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
        title: const Text('Delete post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref.read(communityServiceProvider).deletePost(post.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
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

  void _openPost(CommunityPostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailScreen(postId: post.id),
      ),
    );
  }

  Future<void> _openComposer() async {
    if (AuthService.instance.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to post.')));
      return;
    }
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CommunityComposerScreen(),
        fullscreenDialog: true,
      ),
    );
    if (posted == true && mounted) {
      setState(() => _selectedTab = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posts = switch (_selectedTab) {
      1 => service.likedPosts,
      2 => service.savedPosts,
      _ => service.posts,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? colors.pageBackground : AppColors.mintSoft,
        gradient: isDark
            ? null
            : RadialGradient(
                center: const Alignment(0.45, -0.72),
                radius: 0.95,
                colors: [
                  AppColors.primaryGreen.withValues(alpha: 0.24),
                  AppColors.dashboardHeaderBg.withValues(alpha: 0.82),
                  AppColors.mint,
                ],
                stops: const [0, 0.38, 1],
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSegmentedTabs(),
            SizedBox(height: Responsive.h(context, 4)),
            Expanded(
              child: !_loaded && service.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: posts.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: EdgeInsets.only(
                                left: Responsive.w(context, 16),
                                right: Responsive.w(context, 16),
                                top: Responsive.h(context, 8),
                                bottom: Responsive.h(context, 80),
                              ),
                              itemCount: posts.length,
                              itemBuilder: (_, i) {
                                final post = posts[i];
                                return CommunityPostCard(
                                  post: post,
                                  currentUserId:
                                      AuthService.instance.currentUser?.id,
                                  onTap: () => _openPost(post),
                                  onLikeTap: () => _toggleLike(post),
                                  onSaveTap: () => _toggleSave(post),
                                  onEditTap: () => _editPost(post),
                                  onDeleteTap: () => _deletePost(post),
                                );
                              },
                            ),
                    ),
            ),
            if (_selectedTab == 0) _buildComposeEntry(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.finFlowColors;
    final user = AuthService.instance.currentUser;
    final avatarUrl = user?.avatarUrl;
    final displayName = user?.fullName ?? 'User';
    return Container(
      color: _headerBg,
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
              CircleAvatar(
                radius: Responsive.w(context, 15),
                backgroundColor: AppColors.lightGreen,
                backgroundImage:
                    avatarUrl != null && avatarUrl.trim().isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.trim().isEmpty
                    ? Text(
                        displayName.trim().isEmpty
                            ? '?'
                            : displayName.trim().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: Responsive.sp(context, 12),
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: Responsive.w(context, 10)),
              Text(
                'Financial Advices',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.sp(context, 20),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? colors.primaryText
                      : _headerText,
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
                color: _primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _cardShadow.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_outlined,
                size: Responsive.w(context, 20),
                color: _headerText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    final tabs = ['Post', 'Like', 'Save'];
    final colors = context.finFlowColors;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 16),
        vertical: Responsive.h(context, 10),
      ),
      child: Container(
        padding: EdgeInsets.all(Responsive.w(context, 3)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(Responsive.w(context, 12)),
          boxShadow: [
            BoxShadow(
              color: _cardShadow.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / tabs.length;

            return SizedBox(
              height: Responsive.h(context, 40),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    left: tabWidth * _selectedTab,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _tabActiveBg,
                        borderRadius: BorderRadius.circular(
                          Responsive.w(context, 10),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(tabs.length, (i) {
                      final isActive = _selectedTab == i;
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _selectedTab = i),
                            borderRadius: BorderRadius.circular(
                              Responsive.w(context, 10),
                            ),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontWeight: FontWeight.w600,
                                  fontSize: Responsive.sp(context, 14),
                                  color: isActive
                                      ? _tabActiveText
                                      : colors.primaryText,
                                ),
                                child: Text(tabs[i]),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = switch (_selectedTab) {
      1 => 'No liked posts yet.\nTap the heart on a post to save it here.',
      2 => 'No saved posts yet.\nTap the bookmark on a post to save it here.',
      _ => 'No posts yet.\nBe the first to share a money tip!',
    };
    return ListView(
      padding: EdgeInsets.only(top: Responsive.h(context, 40)),
      children: [
        Icon(
          Icons.forum_outlined,
          size: Responsive.w(context, 56),
          color: _textMuted.withValues(alpha: 0.5),
        ),
        SizedBox(height: Responsive.h(context, 16)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 14),
            color: _textMuted,
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
    final colors = context.finFlowColors;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 16),
        Responsive.h(context, 4),
        Responsive.w(context, 16),
        Responsive.h(context, 10),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: _openComposer,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 16),
              vertical: Responsive.h(context, 12),
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(Responsive.w(context, 24)),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: AppColors.accentTeal.withValues(alpha: 0.08),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: Responsive.w(context, 16),
                  backgroundColor: _primaryGreen,
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
                            fontSize: Responsive.sp(context, 13),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: Responsive.w(context, 16),
                          color: _white,
                        ),
                ),
                SizedBox(width: Responsive.w(context, 10)),
                Expanded(
                  child: Text(
                    isSignedIn ? "What's on your mind?" : 'Sign in to post',
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 14),
                      color: colors.secondaryText,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: Responsive.w(context, 18),
                  color: _primaryGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
