import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/responsive.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/community/models/community_post_model.dart';
import '../../features/community/presentation/community_composer_screen.dart';
import '../../features/community/presentation/widgets/post_card.dart';
import '../../features/community/providers/community_provider.dart';
import 'community_post_detail_screen.dart';

// =============================================================================
// COMMUNITY SCREEN — matches Figma node 1:1313 ("Financial advices")
// =============================================================================

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  int _selectedTab = 0; // 0 = post, 1 = like, 2 = save
  bool _loaded = false;

  static const _bgColor = Color(0xFFF9FBF8);
  static const _headerBg = Color(0xFFD4F4E4);
  static const _primaryGreen = Color(0xFF44BF99);
  static const _textDark = Color(0xFF002117);
  static const _textMuted = Color(0xFF8E918F);
  static const _white = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(communityServiceProvider).fetchPosts();
      if (mounted) setState(() => _loaded = true);
    });
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
      if (mounted) setState(() {});
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
        const SnackBar(content: Text('Sign in to post.')),
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
      setState(() => _selectedTab = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final posts = switch (_selectedTab) {
      1 => service.likedPosts,
      2 => service.savedPosts,
      _ => service.posts,
    };

    return Container(
      color: _bgColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: Responsive.h(context, 16)),
            _buildSegmentedTabs(),
            SizedBox(height: Responsive.h(context, 16)),
            Expanded(
              child: !_loaded && service.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: posts.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.w(context, 16),
                              ),
                              itemCount: posts.length,
                              itemBuilder: (_, i) {
                                final post = posts[i];
                                return CommunityPostCard(
                                  post: post,
                                  onTap: () => _openPost(post),
                                  onLikeTap: () => _toggleLike(post),
                                  onSaveTap: () => _toggleSave(post),
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

  Widget _buildEmptyState() {
    final message = switch (_selectedTab) {
      1 => 'No liked posts yet.\nTap the heart on a post to save it here.',
      2 => 'No saved posts yet.\nTap the bookmark on a post to save it here.',
      _ => 'No posts yet.\nBe the first to share a money tip!',
    };
    return ListView(
      children: [
        SizedBox(height: Responsive.h(context, 80)),
        Icon(Icons.forum_outlined,
            size: Responsive.w(context, 40), color: _textMuted),
        SizedBox(height: Responsive.h(context, 12)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textMuted,
            fontSize: Responsive.sp(context, 13),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _headerBg,
      padding: EdgeInsets.symmetric(
        vertical: Responsive.h(context, 16),
        horizontal: Responsive.w(context, 20),
      ),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Financial advices',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w500,
              fontSize: Responsive.sp(context, 20),
              color: _textDark,
            ),
          ),
          GestureDetector(
            onTap: _openComposer,
            child: Container(
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
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    final tabs = ['post', 'like', 'save'];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      child: Container(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: _primaryGreen, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = _selectedTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = i),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(vertical: Responsive.h(context, 10)),
                  decoration: BoxDecoration(
                    color: isActive ? _primaryGreen : _white,
                    border: i < tabs.length - 1
                        ? Border(
                            right: BorderSide(color: _primaryGreen, width: 1),
                          )
                        : null,
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: Responsive.sp(context, 14),
                      color: isActive ? _white : _primaryGreen,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Tappable pill that opens the full-screen composer (bold/italic/
  /// underline/bullet toolbar + spoiler blur), instead of an inline field.
  Widget _buildComposeEntry() {
    final isSignedIn = AuthService.instance.currentUser != null;
    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: _openComposer,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 16),
            vertical: Responsive.h(context, 10),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 16),
            vertical: Responsive.h(context, 12),
          ),
          decoration: BoxDecoration(
            color: _headerBg.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: Responsive.w(context, 14),
                backgroundColor: _primaryGreen,
                child: Icon(Icons.person, size: Responsive.w(context, 15), color: _white),
              ),
              SizedBox(width: Responsive.w(context, 10)),
              Expanded(
                child: Text(
                  isSignedIn ? 'Share a money tip...' : 'Sign in to post',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: Responsive.sp(context, 13.5),
                  ),
                ),
              ),
              Icon(Icons.edit_outlined, size: Responsive.w(context, 18), color: _primaryGreen),
            ],
          ),
        ),
      ),
    );
  }
}
