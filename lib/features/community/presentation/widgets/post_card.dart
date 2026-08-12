import 'package:flutter/material.dart';

import '../../../../core/i18n/app_language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/community_post_model.dart';
import '../../utils/community_date_format.dart';
import '../../utils/community_topics.dart';
import '../../utils/rich_text_formatter.dart';
import 'community_comment_icon.dart';
import 'post_media_grid.dart';

/// Compact social-feed card shared by Community and Community Activity.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLikeTap,
    required this.onSaveTap,
    this.onEditTap,
    this.onDeleteTap,
    this.currentUserId,
    this.maxLines = 3,
  });

  final CommunityPostModel post;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onSaveTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;
  final String? currentUserId;

  /// Truncates the post body when set; pass `null` to show it in full
  /// (used on the post detail screen).
  final int? maxLines;

  // ── Deeper Mint Palette ──
  static const _primaryGreen = Color(0xFF00C49A);
  static const _white = Color(0xFFFFFFFF);
  static const _heartRed = Color(0xFFE86B5D);
  static const _darkSurface = Color(0xFF16352E);
  static const _darkBorder = Color(0xFF29483F);
  static const _darkText = Color(0xFFF4FBF8);
  static const _darkSecondaryText = Color(0xFFA9C1B9);
  static const _darkMutedText = Color(0xFF708D84);
  static const _darkMint = Color(0xFF38D6AC);

  // Category chip colors
  static Color _chipBg(String category) => switch (category) {
    'Budgeting' => const Color(0xFFE4F3D9),
    'Saving' => const Color(0xFFFFF5DB),
    'Debt-free' => const Color(0xFFFFDAD6),
    'Investing' => const Color(0xFFD5E8FF),
    _ => const Color(0xFFE9EFEC),
  };

  static Color _chipText(String category) => switch (category) {
    'Budgeting' => const Color(0xFF2E7D32),
    'Saving' => const Color(0xFF8A6100),
    'Debt-free' => const Color(0xFF8C1D18),
    'Investing' => const Color(0xFF004883),
    _ => const Color(0xFF404944),
  };

  static const _avatarPalette = [
    Color(0xFF7C5CFC),
    Color(0xFF3799D2),
    Color(0xFF44BF99),
    Color(0xFFE8A23D),
    Color(0xFFE86B5D),
  ];

  Color get _avatarColor {
    final key = post.userId.isNotEmpty ? post.userId : post.displayName;
    final hash = key.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarPalette[hash % _avatarPalette.length];
  }

  String get _initials {
    final name = post.displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1);
    }
    return '${parts.first[0]}${parts.last[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(context, 8)),
      decoration: BoxDecoration(
        color: isDark ? _darkSurface : colors.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? _darkBorder : colors.divider.withValues(alpha: .55),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 16),
                  Responsive.w(context, 16),
                  Responsive.w(context, 16),
                  Responsive.h(context, post.mediaUrls.isEmpty ? 4 : 12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostHeader(context),
                    SizedBox(height: Responsive.h(context, 12)),
                    RichPostContent(
                      content: post.content,
                      maxLines: maxLines,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 13.5),
                        color: isDark ? _darkText : colors.primaryText,
                        height: 1.45,
                      ),
                      spoilerColor: isDark ? _darkText : colors.primaryText,
                    ),
                  ],
                ),
              ),
              if (post.mediaUrls.isNotEmpty)
                PostMediaGrid(
                  urls: post.mediaUrls,
                  detailMode: maxLines == null,
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 16),
                  Responsive.h(context, 12),
                  Responsive.w(context, 16),
                  Responsive.h(context, 8),
                ),
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      color: isDark ? _darkBorder : colors.divider,
                    ),
                    SizedBox(height: Responsive.h(context, 8)),
                    _buildActionBar(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostHeader(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: Responsive.w(context, 18),
          backgroundColor: post.isAnonymous
              ? AppColors.mutedGray
              : _avatarColor,
          backgroundImage:
              !post.isAnonymous && post.authorAvatarUrl?.isNotEmpty == true
              ? NetworkImage(post.authorAvatarUrl!)
              : null,
          child: post.isAnonymous
              ? Icon(
                  Icons.visibility_off,
                  color: _white,
                  size: Responsive.w(context, 18),
                )
              : post.authorAvatarUrl?.isNotEmpty == true
              ? null
              : Text(
                  _initials.toUpperCase(),
                  style: TextStyle(
                    color: _white,
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.sp(context, 13),
                  ),
                ),
        ),
        SizedBox(width: Responsive.w(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.sp(context, 14),
                  color: isDark ? _darkText : colors.primaryText,
                ),
              ),
              SizedBox(height: Responsive.h(context, 2)),
              Row(
                children: [
                  Text(
                    formatCommunityDate(post.createdAt),
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 11),
                      color: isDark ? _darkSecondaryText : colors.secondaryText,
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(context, 8),
                      vertical: Responsive.h(context, 2),
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x4D006C53)
                          : _chipBg(post.category),
                      borderRadius: BorderRadius.circular(
                        Responsive.w(context, 4),
                      ),
                    ),
                    child: Text(
                      communityTopicLabel(post.category),
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 10),
                        fontWeight: FontWeight.w600,
                        color: isDark ? _darkMint : _chipText(post.category),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (currentUserId != null && post.userId == currentUserId)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              size: Responsive.w(context, 18),
              color: isDark ? _darkMutedText : colors.secondaryText,
            ),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onSelected: (value) {
              if (value == 'edit') onEditTap?.call();
              if (value == 'delete') onDeleteTap?.call();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(AppStrings.choose('Edit', 'Chỉnh sửa')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.choose('Delete', 'Xóa'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? _darkMutedText : colors.secondaryText;
    return Row(
      children: [
        _IconCount(
          icon: Icon(post.isLikedByMe ? Icons.favorite : Icons.favorite_border),
          iconColor: post.isLikedByMe ? _heartRed : inactiveColor,
          count: post.likesCount,
          onTap: onLikeTap,
        ),
        SizedBox(width: Responsive.w(context, 20)),
        _IconCount(
          icon: const CommunityCommentIcon(),
          iconColor: inactiveColor,
          count: post.commentsCount,
          onTap: onTap,
        ),
        const Spacer(),
        IconButton(
          onPressed: onSaveTap,
          tooltip: post.isSavedByMe
              ? AppStrings.choose('Remove saved post', 'Bỏ lưu bài viết')
              : AppStrings.choose('Save post', 'Lưu bài viết'),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            post.isSavedByMe ? Icons.bookmark : Icons.bookmark_border,
            size: Responsive.w(context, 22),
            color: post.isSavedByMe
                ? (isDark ? _darkMint : _primaryGreen)
                : inactiveColor,
          ),
        ),
      ],
    );
  }
}

class _IconCount extends StatelessWidget {
  const _IconCount({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.onTap,
  });

  final Widget icon;
  final Color iconColor;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: '$count',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  size: Responsive.w(context, 20),
                  color: iconColor,
                ),
                child: icon,
              ),
              SizedBox(width: Responsive.w(context, 5)),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 12),
                  color: isDark
                      ? CommunityPostCard._darkSecondaryText
                      : context.finFlowColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
