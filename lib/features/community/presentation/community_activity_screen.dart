import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/screens/community_post_detail_screen.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../models/community_post_model.dart';
import '../models/community_report_model.dart';
import '../providers/community_provider.dart';
import 'community_composer_screen.dart';
import 'widgets/community_report_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/post_removal_animation.dart';

class CommunityActivityScreen extends ConsumerStatefulWidget {
  const CommunityActivityScreen({super.key});

  @override
  ConsumerState<CommunityActivityScreen> createState() =>
      _CommunityActivityScreenState();
}

class _CommunityActivityScreenState
    extends ConsumerState<CommunityActivityScreen> {
  var _selectedTab = 0;
  final Set<String> _removingPostIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communityServiceProvider).fetchPosts();
    });
  }

  Future<void> _toggleLike(CommunityPostModel post) async {
    try {
      await ref.read(communityServiceProvider).toggleLike(post.id);
    } catch (_) {
      if (mounted) {
        _showMessage(
          AppStrings.choose(
            'Could not update this like.',
            'Không thể cập nhật lượt thích này.',
          ),
        );
      }
    }
  }

  Future<void> _toggleSave(CommunityPostModel post) async {
    await ref.read(communityServiceProvider).toggleSave(post.id);
  }

  void _openPost(CommunityPostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailScreen(postId: post.id),
      ),
    );
  }

  Future<void> _editPost(CommunityPostModel post) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityComposerScreen(editPost: post),
        fullscreenDialog: true,
      ),
    );
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
    setState(() => _removingPostIds.add(post.id));
    await Future<void>.delayed(PostRemovalAnimation.duration);
    if (!mounted) return;
    try {
      await ref.read(communityServiceProvider).deletePost(post.id);
    } catch (_) {
      if (mounted) {
        setState(() => _removingPostIds.remove(post.id));
        _showMessage(
          AppStrings.choose(
            'Could not delete this post.',
            'Không thể xóa bài viết này.',
          ),
        );
      }
    }
  }

  Future<void> _reportPost(CommunityPostModel post) {
    return showCommunityReportDialog(
      context: context,
      target: CommunityReportTarget.post,
      authorName: post.displayName,
      authorAvatarUrl: post.isAnonymous ? null : post.authorAvatarUrl,
      content: post.content,
      onSubmit: (reason, details) => ref
          .read(communityServiceProvider)
          .reportPost(postId: post.id, reason: reason, description: details),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final posts = switch (_selectedTab) {
      1 => service.likedPosts,
      2 => service.savedPosts,
      _ => service.myPosts,
    };
    return Scaffold(
      backgroundColor: context.finFlowColors.pageBackground,
      appBar: AppBar(
        title: Text(
          AppStrings.choose('Community Activity', 'Hoạt động cộng đồng'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildActivityTabs(),
          Expanded(
            child: service.isLoading && service.posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: service.fetchPosts,
                    child: posts.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              top: Responsive.h(context, 8),
                              bottom: Responsive.h(context, 24),
                            ),
                            itemCount: posts.length,
                            itemBuilder: (_, index) {
                              final post = posts[index];
                              return PostRemovalAnimation(
                                key: ValueKey('activity-post-${post.id}'),
                                removing: _removingPostIds.contains(post.id),
                                child: CommunityPostCard(
                                  post: post,
                                  currentUserId:
                                      AuthService.instance.currentUser?.id,
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
        ],
      ),
    );
  }

  Widget _buildActivityTabs() {
    final labels = [
      AppStrings.choose('Post', 'Bài viết'),
      AppStrings.choose('Like', 'Đã thích'),
      AppStrings.choose('Save', 'Đã lưu'),
    ];
    final colors = context.finFlowColors;
    return Container(
      color: colors.pageBackground,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 16),
        Responsive.h(context, 10),
        Responsive.w(context, 16),
        Responsive.h(context, 12),
      ),
      child: Container(
        padding: EdgeInsets.all(Responsive.w(context, 3)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.divider),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: .06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / labels.length;
            return SizedBox(
              height: Responsive.h(context, 46),
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
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withValues(
                              alpha: .24,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(labels.length, (index) {
                      final selected = index == _selectedTab;
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _selectedTab = index),
                            borderRadius: BorderRadius.circular(999),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: Responsive.sp(context, 15),
                                  color: selected
                                      ? AppColors.darkText
                                      : colors.primaryText,
                                ),
                                child: Text(labels[index]),
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

  Widget _emptyState() {
    final message = switch (_selectedTab) {
      1 => AppStrings.choose(
        'Posts you like will appear here.',
        'Các bài viết bạn thích sẽ xuất hiện tại đây.',
      ),
      2 => AppStrings.choose(
        'Posts you save will appear here.',
        'Các bài viết bạn lưu sẽ xuất hiện tại đây.',
      ),
      _ => AppStrings.choose(
        'Your community posts will appear here.',
        'Các bài viết cộng đồng của bạn sẽ xuất hiện tại đây.',
      ),
    };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: Responsive.h(context, 96)),
      children: [
        Icon(
          _selectedTab == 1
              ? Icons.favorite_border
              : _selectedTab == 2
              ? Icons.bookmark_border
              : Icons.article_outlined,
          size: Responsive.w(context, 52),
          color: context.finFlowColors.secondaryText,
        ),
        SizedBox(height: Responsive.h(context, 14)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 14),
            color: context.finFlowColors.secondaryText,
          ),
        ),
      ],
    );
  }
}
