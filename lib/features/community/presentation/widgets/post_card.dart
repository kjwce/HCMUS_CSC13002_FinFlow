import 'package:flutter/material.dart';

import '../../../../core/utils/responsive.dart';
import '../../models/community_post_model.dart';
import '../../utils/community_date_format.dart';
import '../../utils/rich_text_formatter.dart';

/// Post card used in the Post / Like / Save feed tabs — matches the Figma
/// "Financial advices" list cards.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLikeTap,
    required this.onSaveTap,
    this.maxLines = 3,
  });

  final CommunityPostModel post;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onSaveTap;

  /// Truncates the post body when set; pass `null` to show it in full
  /// (used on the post detail screen).
  final int? maxLines;

  static const _textDark = Color(0xFF002117);
  static const _textBody = Color(0xFF404944);
  static const _textMuted = Color(0xFF8E918F);
  static const _primaryGreen = Color(0xFF44BF99);
  static const _coral = Color(0xFFE86B5D);
  static const _white = Color(0xFFFFFFFF);

  static const _avatarPalette = [
    Color(0xFF7C5CFC),
    Color(0xFF3799D2),
    Color(0xFF44BF99),
    Color(0xFFE8A23D),
    Color(0xFFE86B5D),
  ];

  Color get _avatarColor {
    final key = post.displayName;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: Responsive.h(context, 12)),
        padding: EdgeInsets.all(Responsive.w(context, 16)),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                CircleAvatar(
                  radius: Responsive.w(context, 18),
                  backgroundColor: _avatarColor,
                  child: Text(
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
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.sp(context, 13.5),
                          color: _textDark,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 2)),
                      Text(
                        '${formatCommunityDate(post.createdAt)} · ${post.category}',
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 11.5),
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(context, 10)),
            RichPostContent(
              content: post.content,
              maxLines: maxLines,
              style: TextStyle(
                fontSize: Responsive.sp(context, 13),
                color: _textBody,
                height: 1.4,
              ),
              spoilerColor: _textDark,
            ),
            SizedBox(height: Responsive.h(context, 12)),
            Divider(height: 1, color: _textMuted.withValues(alpha: 0.2)),
            SizedBox(height: Responsive.h(context, 8)),
            Row(
              children: [
                _IconCount(
                  icon: post.isLikedByMe
                      ? Icons.favorite
                      : Icons.favorite_border,
                  iconColor: post.isLikedByMe ? _coral : _textMuted,
                  count: post.likesCount,
                  onTap: onLikeTap,
                ),
                SizedBox(width: Responsive.w(context, 18)),
                _IconCount(
                  icon: Icons.mode_comment_outlined,
                  iconColor: _textMuted,
                  count: post.commentsCount,
                  onTap: onTap,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onSaveTap,
                  child: Icon(
                    post.isSavedByMe ? Icons.bookmark : Icons.bookmark_border,
                    size: Responsive.w(context, 20),
                    color: post.isSavedByMe ? _primaryGreen : _textMuted,
                  ),
                ),
              ],
            ),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: Responsive.w(context, 18), color: iconColor),
          SizedBox(width: Responsive.w(context, 5)),
          Text(
            '$count',
            style: TextStyle(
              fontSize: Responsive.sp(context, 12),
              color: CommunityPostCard._textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
