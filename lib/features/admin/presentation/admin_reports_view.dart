import 'package:flutter/material.dart';

import '../models/admin_post_model.dart';
import '../models/admin_report_model.dart';
import '../services/admin_moderation_service.dart';
import 'admin_strings.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key, required this.service});

  final AdminModerationService service;

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  List<AdminReportedPostModel> _items = const [];
  bool _loading = true;
  bool _showResolved = false;
  String _search = '';
  String? _error;

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
      final items = await widget.service.fetchReportedPosts();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${AdminStrings.t('Could not load reports', 'Không thể tải báo cáo')}: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminReportedPostModel> get _visibleItems {
    final query = _search.trim().toLowerCase();
    return _items.where((item) {
      final resolved =
          item.post.status == ModerationStatus.removed ||
          item.pendingCount == 0;
      if (_showResolved != resolved) return false;
      if (query.isEmpty) return true;
      return item.post.content.toLowerCase().contains(query) ||
          item.post.displayAuthor.toLowerCase().contains(query) ||
          item.reports.any(
            (report) =>
                report.reason.toLowerCase().contains(query) ||
                (report.description?.toLowerCase().contains(query) ?? false),
          );
    }).toList();
  }

  int get _openCount => _items.where((item) => item.pendingCount > 0).length;

  Future<void> _removePost(AdminReportedPostModel item) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AdminStrings.t('Remove post from Community', 'Gỡ bài khỏi Community'),
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AdminStrings.t(
                  'The post will be hidden from Community, while its content and report history remain available to admins.',
                  'Bài sẽ bị ẩn khỏi Community. Nội dung và lịch sử báo cáo vẫn được giữ lại cho admin.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: AdminStrings.t('Removal reason', 'Lý do gỡ bài'),
                  hintText: AdminStrings.t(
                    'Example: Scam or prohibited promotional content...',
                    'Ví dụ: Nội dung lừa đảo hoặc quảng cáo vi phạm...',
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
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(AdminStrings.removePost),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;

    try {
      await widget.service.removeReportedPost(
        postId: item.post.id,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AdminStrings.t(
              'The post was removed and its reports were resolved.',
              'Đã gỡ bài và xử lý các báo cáo.',
            ),
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AdminStrings.t('Could not remove post', 'Không thể gỡ bài')}: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            runSpacing: 14,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AdminStrings.reportedPosts,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AdminStrings.t(
                      '$_openCount posts need community review.',
                      '$_openCount bài cần xem xét từ cộng đồng.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: AdminStrings.t(
                      'Search posts or report reasons...',
                      'Tìm bài hoặc lý do báo cáo...',
                    ),
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              ChoiceChip(
                label: Text(
                  AdminStrings.t(
                    'Open ($_openCount)',
                    'Chờ xử lý ($_openCount)',
                  ),
                ),
                selected: !_showResolved,
                onSelected: (_) => setState(() => _showResolved = false),
              ),
              const SizedBox(width: 9),
              ChoiceChip(
                label: Text(AdminStrings.t('Resolved', 'Đã xử lý')),
                selected: _showResolved,
                onSelected: (_) => setState(() => _showResolved = true),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _MessageCard(
              icon: Icons.cloud_off_outlined,
              title: _error!,
              actionLabel: AdminStrings.retry,
              onAction: _load,
            )
          else if (_visibleItems.isEmpty)
            _MessageCard(
              icon: Icons.verified_outlined,
              title: AdminStrings.t(
                'No reports in this section',
                'Không có báo cáo trong mục này',
              ),
              subtitle: AdminStrings.t(
                'New reports will appear here.',
                'Các báo cáo mới sẽ xuất hiện tại đây.',
              ),
            )
          else
            ..._visibleItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ReportedPostCard(
                  item: item,
                  onRemove: () => _removePost(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportedPostCard extends StatelessWidget {
  const _ReportedPostCard({required this.item, required this.onRemove});

  final AdminReportedPostModel item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final removed = item.post.status == ModerationStatus.removed;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFEAE7),
                child: Icon(Icons.flag_rounded, color: Color(0xFFB42318)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.post.displayAuthor,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${AdminStrings.t('${item.reports.length} reports', '${item.reports.length} lượt báo cáo')} • ${_formatDate(item.reports.first.createdAt)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: removed
                      ? const Color(0xFFE8EFEC)
                      : const Color(0xFFFFEAE7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  removed
                      ? AdminStrings.removed
                      : AdminStrings.t(
                          '${item.pendingCount} open',
                          '${item.pendingCount} chờ xử lý',
                        ),
                  style: TextStyle(
                    color: removed
                        ? const Color(0xFF536B64)
                        : const Color(0xFFB42318),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              item.post.content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...item.reports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 18,
                    color: Color(0xFF8A9A95),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AdminStrings.reportReason(report.reason)}: ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: report.description?.trim().isNotEmpty == true
                                ? report.description
                                : AdminStrings.noDescription,
                          ),
                          TextSpan(
                            text:
                                ' — ${report.reporterName ?? AdminStrings.member}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (removed && item.post.removalReason != null) ...[
            const SizedBox(height: 6),
            Text(
              '${AdminStrings.t('Removal reason', 'Lý do gỡ')}: ${item.post.removalReason}',
              style: const TextStyle(
                color: Color(0xFF8F2D22),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!removed) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onRemove,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(AdminStrings.removePost),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFF78A597)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final date = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
