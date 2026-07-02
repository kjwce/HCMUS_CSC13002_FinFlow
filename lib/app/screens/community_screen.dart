import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/responsive.dart';
import '../../core/widgets/notification_bell.dart';

// =============================================================================
// COMMUNITY SCREEN — matches Figma node 1:1313
// =============================================================================

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  int _selectedTab = 1; // "like" active by default

  static const _bgColor = Color(0xFFF9FBF8);
  static const _headerBg = Color(0xFFD4F4E4);
  static const _primaryGreen = Color(0xFF44BF99);
  static const _textDark = Color(0xFF002117);
  static const _textBody = Color(0xFF404944);
  static const _textMuted = Color(0xFF8E918F);
  static const _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: Responsive.h(context, 16)),
            _buildSegmentedTabs(),
            SizedBox(height: Responsive.h(context, 16)),
            Expanded(child: _buildArticleGrid()),
          ],
        ),
      ),
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
          const NotificationBell(),
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
                  padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 10)),
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

  Widget _buildArticleGrid() {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 167 / 186,
        crossAxisSpacing: Responsive.w(context, 12),
        mainAxisSpacing: Responsive.h(context, 12),
      ),
      itemCount: _articles.length,
      itemBuilder: (_, index) => _ArticleCard(article: _articles[index]),
    );
  }
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _ArticleData {
  final Color bgColor;
  final IconData icon;
  final String title;
  final String date;

  const _ArticleData({
    required this.bgColor,
    required this.icon,
    required this.title,
    required this.date,
  });
}

const _articles = <_ArticleData>[
  _ArticleData(
    bgColor: Color(0xFFEBC7CD),
    icon: Icons.monetization_on_outlined,
    title: 'How to Create a Budget That Works for You',
    date: '6th May',
  ),
  _ArticleData(
    bgColor: Color(0xFFEBE3C7),
    icon: Icons.credit_card_outlined,
    title: 'Maximizing Your Retirement Savings',
    date: '6th May',
  ),
  _ArticleData(
    bgColor: Color(0xFFCAECC9),
    icon: Icons.wallet_outlined,
    title: 'Understanding Your Credit Score',
    date: '6th May',
  ),
  _ArticleData(
    bgColor: Color(0xFFE4C7EB),
    icon: Icons.receipt_long_outlined,
    title: 'Debt Reduction Strategies',
    date: '6th May',
  ),
];

// ---------------------------------------------------------------------------
// Article card widget
// ---------------------------------------------------------------------------

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final _ArticleData article;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _CommunityScreenState._white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image section (106px)
          Container(
            height: Responsive.h(context, 106),
            decoration: BoxDecoration(
              color: article.bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Icon(article.icon, color: Colors.white, size: Responsive.w(context, 40)),
            ),
          ),
          // Text section (80px)
          Container(
            height: Responsive.h(context, 80),
            padding: EdgeInsets.all(Responsive.w(context, 10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: Responsive.sp(context, 12),
                    color: _CommunityScreenState._textBody,
                  ),
                ),
                const Spacer(),
                Text(
                  article.date,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: Responsive.sp(context, 11),
                    color: _CommunityScreenState._textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
