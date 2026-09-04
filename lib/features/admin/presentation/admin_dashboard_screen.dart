import 'package:flutter/material.dart';

import '../models/admin_post_model.dart';
import '../services/admin_moderation_service.dart';
import 'admin_brand.dart';
import 'admin_members_view.dart';
import 'admin_preferences_controls.dart';
import 'admin_reports_view.dart';
import 'admin_strings.dart';

enum AdminSection { moderation, reports, members }

extension on AdminSection {
  String get label => switch (this) {
    AdminSection.moderation => AdminStrings.moderation,
    AdminSection.reports => AdminStrings.reportedPosts,
    AdminSection.members => AdminStrings.members,
  };
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.service,
    required this.onSignedOut,
  });

  final AdminModerationService service;
  final VoidCallback onSignedOut;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<AdminPostModel> _posts = const [];
  ModerationStatus? _filter = ModerationStatus.pending;
  String _search = '';
  bool _loading = true;
  String? _error;
  AdminSection _section = AdminSection.moderation;
  int _sectionRefresh = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await widget.service.fetchPosts();
      if (mounted) setState(() => _posts = posts);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AdminStrings.t(
            'Could not load posts. Please try again.',
            'Không thể tải danh sách bài viết. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminPostModel> get _visiblePosts {
    final query = _search.trim().toLowerCase();
    return _posts.where((post) {
      if (_filter != null && post.status != _filter) return false;
      if (query.isEmpty) return true;
      return post.content.toLowerCase().contains(query) ||
          post.displayAuthor.toLowerCase().contains(query) ||
          post.category.toLowerCase().contains(query);
    }).toList();
  }

  int _count(ModerationStatus status) =>
      _posts.where((post) => post.status == status).length;

  Future<void> _moderate(
    AdminPostModel post,
    ModerationStatus status, {
    String? reason,
  }) async {
    try {
      await widget.service.moderate(
        postId: post.id,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == ModerationStatus.approved
                ? AdminStrings.t('Post approved.', 'Đã duyệt bài viết.')
                : AdminStrings.t('Post rejected.', 'Đã từ chối bài viết.'),
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AdminStrings.t(
              'Action failed. Please try again.',
              'Thao tác thất bại. Vui lòng thử lại.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _reject(AdminPostModel post) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AdminStrings.t('Reject post', 'Từ chối bài viết')),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AdminStrings.t(
                  'The reason will be saved in the moderation history.',
                  'Lý do sẽ được lưu trong lịch sử kiểm duyệt.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: AdminStrings.t(
                    'Rejection reason',
                    'Lý do từ chối',
                  ),
                  hintText: AdminStrings.t(
                    'Example: Inappropriate promotional content...',
                    'Ví dụ: Nội dung quảng cáo không phù hợp...',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AdminStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(
              AdminStrings.t('Confirm rejection', 'Xác nhận từ chối'),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && mounted) {
      await _moderate(post, ModerationStatus.rejected, reason: reason);
    }
  }

  Future<void> _signOut() async {
    await widget.service.signOut();
    widget.onSignedOut();
  }

  void _selectSection(AdminSection section) {
    setState(() => _section = section);
  }

  void _refreshCurrentSection() {
    if (_section == AdminSection.moderation) {
      _load();
      return;
    }
    setState(() => _sectionRefresh++);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      body: Row(
        children: [
          if (desktop)
            _AdminSidebar(
              email: widget.service.currentUser?.email ?? 'Admin',
              section: _section,
              onSectionChanged: _selectSection,
              onSignOut: _signOut,
            ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    email: widget.service.currentUser?.email ?? 'Admin',
                    desktop: desktop,
                    section: _section,
                    onSectionChanged: _selectSection,
                    onRefresh: _refreshCurrentSection,
                    onSignOut: _signOut,
                  ),
                  Expanded(
                    child: switch (_section) {
                      AdminSection.reports => AdminReportsView(
                        key: ValueKey('reports-$_sectionRefresh'),
                        service: widget.service,
                      ),
                      AdminSection.members => AdminMembersView(
                        key: ValueKey('members-$_sectionRefresh'),
                        service: widget.service,
                      ),
                      AdminSection.moderation => RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 36 : 18,
                            22,
                            desktop ? 36 : 18,
                            40,
                          ),
                          children: [
                            _Header(
                              totalPending: _count(ModerationStatus.pending),
                            ),
                            const SizedBox(height: 24),
                            _StatsRow(
                              pending: _count(ModerationStatus.pending),
                              approved: _count(ModerationStatus.approved),
                              rejected: _count(ModerationStatus.rejected),
                              reports: _posts.fold(
                                0,
                                (sum, post) => sum + post.reportCount,
                              ),
                            ),
                            const SizedBox(height: 26),
                            _FilterBar(
                              filter: _filter,
                              pending: _count(ModerationStatus.pending),
                              approved: _count(ModerationStatus.approved),
                              rejected: _count(ModerationStatus.rejected),
                              onFilterChanged: (value) =>
                                  setState(() => _filter = value),
                              onSearch: (value) =>
                                  setState(() => _search = value),
                            ),
                            const SizedBox(height: 18),
                            if (_loading)
                              const _LoadingCard()
                            else if (_error != null)
                              _ErrorCard(message: _error!, onRetry: _load)
                            else if (_visiblePosts.isEmpty)
                              const _EmptyCard()
                            else
                              ..._visiblePosts.map(
                                (post) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _PostCard(
                                    post: post,
                                    onOpen: () => showDialog<void>(
                                      context: context,
                                      builder: (_) => _PostDetailDialog(
                                        post: post,
                                        onApprove: () => _moderate(
                                          post,
                                          ModerationStatus.approved,
                                        ),
                                        onReject: () => _reject(post),
                                      ),
                                    ),
                                    onApprove: () => _moderate(
                                      post,
                                      ModerationStatus.approved,
                                    ),
                                    onReject: () => _reject(post),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    },
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

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.email,
    required this.section,
    required this.onSectionChanged,
    required this.onSignOut,
  });
  final String email;
  final AdminSection section;
  final ValueChanged<AdminSection> onSectionChanged;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF103E33),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminBrand(light: true, iconSize: 42, showAdminBadge: false),
          const SizedBox(height: 42),
          _SidebarItem(
            icon: Icons.rate_review_rounded,
            label: AdminStrings.moderation,
            selected: section == AdminSection.moderation,
            onTap: () => onSectionChanged(AdminSection.moderation),
          ),
          _SidebarItem(
            icon: Icons.flag_outlined,
            label: AdminStrings.reportedPosts,
            selected: section == AdminSection.reports,
            onTap: () => onSectionChanged(AdminSection.reports),
          ),
          _SidebarItem(
            icon: Icons.people_outline_rounded,
            label: AdminStrings.members,
            selected: section == AdminSection.members,
            onTap: () => onSectionChanged(AdminSection.members),
          ),
          const Spacer(),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFB7CEC7), fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onSignOut,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.logout_rounded, size: 19),
            label: Text(AdminStrings.signOut),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFF276653) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : const Color(0xFF9CBAB1),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFB7CEC7),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.email,
    required this.desktop,
    required this.section,
    required this.onSectionChanged,
    required this.onRefresh,
    required this.onSignOut,
  });
  final String email;
  final bool desktop;
  final AdminSection section;
  final ValueChanged<AdminSection> onSectionChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 36 : 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          if (!desktop) ...[
            const AdminBrand(
              iconSize: 30,
              showName: false,
              showAdminBadge: false,
            ),
            const SizedBox(width: 8),
            PopupMenuButton<AdminSection>(
              onSelected: onSectionChanged,
              itemBuilder: (_) => AdminSection.values
                  .map(
                    (value) =>
                        PopupMenuItem(value: value, child: Text(value.label)),
                  )
                  .toList(),
              child: Row(
                children: [
                  Text(
                    section.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ] else
            Text(
              AdminStrings.t('Community Operations', 'Vận hành cộng đồng'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            tooltip: AdminStrings.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
          const AdminPreferencesControls(compact: true),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') onSignOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'logout', child: Text(AdminStrings.signOut)),
            ],
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFFE2F1EB),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 19,
                    color: Color(0xFF0B6B4F),
                  ),
                ),
                if (desktop) ...[
                  const SizedBox(width: 9),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.totalPending});
  final int totalPending;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AdminStrings.moderation,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AdminStrings.t(
                'Review content before it appears in Community.',
                'Xem xét nội dung trước khi hiển thị trong Community.',
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (totalPending > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AdminStrings.t(
                '$totalPending posts waiting',
                '$totalPending bài đang chờ',
              ),
              style: const TextStyle(
                color: Color(0xFF855D0D),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.reports,
  });
  final int pending;
  final int approved;
  final int rejected;
  final int reports;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatData(
        AdminStrings.pending,
        pending,
        Icons.hourglass_top_rounded,
        const Color(0xFFF7B731),
        const Color(0xFFFFF7E2),
      ),
      _StatData(
        AdminStrings.approved,
        approved,
        Icons.check_circle_outline_rounded,
        const Color(0xFF169B6B),
        const Color(0xFFE8F7F1),
      ),
      _StatData(
        AdminStrings.rejected,
        rejected,
        Icons.block_rounded,
        const Color(0xFFD14A3A),
        const Color(0xFFFFEEEB),
      ),
      _StatData(
        AdminStrings.reports,
        reports,
        Icons.flag_outlined,
        const Color(0xFF6C63C7),
        const Color(0xFFF0EFFE),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 760
            ? (constraints.maxWidth - 42) / 4
            : (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map(
                (data) => SizedBox(
                  width: width,
                  child: _StatCard(data: data),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatData {
  const _StatData(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.background,
  );
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color background;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.value}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.onFilterChanged,
    required this.onSearch,
  });
  final ModerationStatus? filter;
  final int pending;
  final int approved;
  final int rejected;
  final ValueChanged<ModerationStatus?> onFilterChanged;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Wrap(
        spacing: 9,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterChip(
            label: AdminStrings.pending,
            count: pending,
            selected: filter == ModerationStatus.pending,
            onTap: () => onFilterChanged(ModerationStatus.pending),
          ),
          _FilterChip(
            label: AdminStrings.approved,
            count: approved,
            selected: filter == ModerationStatus.approved,
            onTap: () => onFilterChanged(ModerationStatus.approved),
          ),
          _FilterChip(
            label: AdminStrings.rejected,
            count: rejected,
            selected: filter == ModerationStatus.rejected,
            onTap: () => onFilterChanged(ModerationStatus.rejected),
          ),
          _FilterChip(
            label: AdminStrings.all,
            count: pending + approved + rejected,
            selected: filter == null,
            onTap: () => onFilterChanged(null),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 260,
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                isDense: true,
                hintText: AdminStrings.t(
                  'Search content or author...',
                  'Tìm nội dung, tác giả...',
                ),
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE1F1EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });
  final AdminPostModel post;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AuthorAvatar(
                    imageUrl: post.authorAvatarUrl,
                    displayName: post.displayAuthor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.displayAuthor,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDate(post.createdAt)} • ${post.category}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: post.status),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Meta(
                    icon: Icons.favorite_border,
                    text: AdminStrings.t(
                      '${post.likesCount} likes',
                      '${post.likesCount} lượt thích',
                    ),
                  ),
                  _Meta(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: AdminStrings.t(
                      '${post.commentsCount} comments',
                      '${post.commentsCount} bình luận',
                    ),
                  ),
                  if (post.mediaUrls.isNotEmpty)
                    _Meta(
                      icon: Icons.image_outlined,
                      text: AdminStrings.t(
                        '${post.mediaUrls.length} images',
                        '${post.mediaUrls.length} ảnh',
                      ),
                    ),
                  if (post.reportCount > 0)
                    _Meta(
                      icon: Icons.flag_outlined,
                      text: AdminStrings.t(
                        '${post.reportCount} reports',
                        '${post.reportCount} báo cáo',
                      ),
                      warning: true,
                    ),
                  if (post.status == ModerationStatus.pending) ...[
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(AdminStrings.reject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB42318),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(AdminStrings.approve),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostDetailDialog extends StatelessWidget {
  const _PostDetailDialog({
    required this.post,
    required this.onApprove,
    required this.onReject,
  });
  final AdminPostModel post;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AdminStrings.t('Post details', 'Chi tiết bài viết'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  _StatusBadge(status: post.status),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _AuthorAvatar(
                          imageUrl: post.authorAvatarUrl,
                          displayName: post.displayAuthor,
                          radius: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.displayAuthor,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${post.authorEmail ?? AdminStrings.noEmail} • ${_formatDate(post.createdAt)}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        post.content,
                        style: TextStyle(
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (post.mediaUrls.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: post.mediaUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (_, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              post.mediaUrls[index],
                              width: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 240,
                                color: const Color(0xFFE8EFEC),
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (post.rejectionReason != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEEB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${AdminStrings.t('Rejection reason', 'Lý do từ chối')}: ${post.rejectionReason}',
                          style: const TextStyle(color: Color(0xFF8F2D22)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (post.status == ModerationStatus.pending) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onReject();
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: Text(AdminStrings.reject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB42318),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onApprove();
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(AdminStrings.approve),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ModerationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      ModerationStatus.pending => (
        AdminStrings.pending,
        const Color(0xFF8A610B),
        const Color(0xFFFFF3D4),
      ),
      ModerationStatus.approved => (
        AdminStrings.approved,
        const Color(0xFF087A52),
        const Color(0xFFE4F5EE),
      ),
      ModerationStatus.rejected => (
        AdminStrings.rejected,
        const Color(0xFFA23428),
        const Color(0xFFFFEAE7),
      ),
      ModerationStatus.removed => (
        AdminStrings.removed,
        const Color(0xFF536B64),
        const Color(0xFFE8EFEC),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.warning = false});
  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? const Color(0xFFB42318)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: warning ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.imageUrl,
    required this.displayName,
    this.radius = 20,
  });

  final String? imageUrl;
  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE5F2ED),
      child: Text(
        displayName.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF0B6B4F),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 220,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => Container(
    height: 240,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 48,
            color: Color(0xFF78A597),
          ),
          const SizedBox(height: 12),
          Text(
            AdminStrings.t(
              'No posts in this section',
              'Không có bài viết trong mục này',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            AdminStrings.t(
              'The moderation queue has been cleared.',
              'Hàng đợi kiểm duyệt đã được xử lý.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    height: 220,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: Color(0xFFB42318),
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(AdminStrings.retry),
          ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)} • ${two(local.day)}/${two(local.month)}/${local.year}';
}
