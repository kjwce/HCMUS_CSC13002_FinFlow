import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/community_post_model.dart';
import '../../utils/community_date_format.dart';
import '../../utils/rich_text_formatter.dart';

/// Post card used in the Post / Like / Save feed tabs — Deeper Mint Theme.
/// Matches Stitch screen "Community Feed - Deeper Mint Theme" cards.
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
      margin: EdgeInsets.only(bottom: Responsive.h(context, 12)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Responsive.w(context, 14)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).shadowColor.withValues(alpha: isDark ? 0.2 : 0.13),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: AppColors.accentTeal.withValues(alpha: isDark ? 0.04 : 0.07),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Responsive.w(context, 14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(Responsive.w(context, 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row: Avatar + Name/Date + Category + Menu ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar circle
                    CircleAvatar(
                      radius: Responsive.w(context, 18),
                      backgroundColor: post.isAnonymous
                          ? AppColors.mutedGray
                          : _avatarColor,
                      backgroundImage:
                          !post.isAnonymous &&
                              post.authorAvatarUrl?.isNotEmpty == true
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
                    // Name + Date
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
                              color: colors.primaryText,
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
                                  color: colors.secondaryText,
                                ),
                              ),
                              SizedBox(width: Responsive.w(context, 8)),
                              // Category chip
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.w(context, 8),
                                  vertical: Responsive.h(context, 2),
                                ),
                                decoration: BoxDecoration(
                                  color: _chipBg(post.category),
                                  borderRadius: BorderRadius.circular(
                                    Responsive.w(context, 4),
                                  ),
                                ),
                                child: Text(
                                  post.category,
                                  style: TextStyle(
                                    fontFamily: 'Hanken Grotesk',
                                    fontSize: Responsive.sp(context, 10),
                                    fontWeight: FontWeight.w600,
                                    color: _chipText(post.category),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Owner menu
                    if (currentUserId != null && post.userId == currentUserId)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          size: Responsive.w(context, 18),
                          color: colors.secondaryText,
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
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                SizedBox(height: Responsive.h(context, 12)),

                // ── Post Content ──
                RichPostContent(
                  content: post.content,
                  maxLines: maxLines,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 13.5),
                    color: colors.primaryText,
                    height: 1.45,
                  ),
                  spoilerColor: colors.primaryText,
                ),

                if (post.mediaUrls.isNotEmpty) ...[
                  SizedBox(height: Responsive.h(context, 12)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.mediaUrls.first,
                      width: double.infinity,
                      height: Responsive.h(
                        context,
                        maxLines == null ? 220 : 160,
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],

                SizedBox(height: Responsive.h(context, 12)),

                // ── Divider ──
                Divider(height: 1, color: colors.divider),

                SizedBox(height: Responsive.h(context, 8)),

                // ── Action Bar ──
                Row(
                  children: [
                    // Like
                    _IconCount(
                      icon: post.isLikedByMe
                          ? Icons.favorite
                          : Icons.favorite_border,
                      iconColor: post.isLikedByMe
                          ? _heartRed
                          : colors.secondaryText,
                      count: post.likesCount,
                      onTap: onLikeTap,
                    ),
                    SizedBox(width: Responsive.w(context, 20)),
                    // Comment
                    _IconCount(
                      icon: Icons.mode_comment_outlined,
                      iconColor: colors.secondaryText,
                      count: post.commentsCount,
                      onTap: onTap,
                    ),
                    const Spacer(),
                    // Save
                    IconButton(
                      onPressed: onSaveTap,
                      tooltip: post.isSavedByMe
                          ? 'Remove saved post'
                          : 'Save post',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        post.isSavedByMe
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size: Responsive.w(context, 22),
                        color: post.isSavedByMe
                            ? _primaryGreen
                            : colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  final IconData icon;
  final Color iconColor;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, size: Responsive.w(context, 20), color: iconColor),
              SizedBox(width: Responsive.w(context, 5)),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 12),
                  color: context.finFlowColors.secondaryText,
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
