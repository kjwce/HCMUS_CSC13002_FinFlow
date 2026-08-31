import 'package:flutter/material.dart';

import '../models/admin_member_model.dart';
import '../services/admin_moderation_service.dart';
import 'admin_strings.dart';

class AdminMembersView extends StatefulWidget {
  const AdminMembersView({super.key, required this.service});

  final AdminModerationService service;

  @override
  State<AdminMembersView> createState() => _AdminMembersViewState();
}

class _AdminMembersViewState extends State<AdminMembersView> {
  List<AdminMemberModel> _members = const [];
  bool _loading = true;
  bool _onlyMuted = false;
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
      final members = await widget.service.fetchMembers();
      if (mounted) setState(() => _members = members);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${AdminStrings.t('Could not load members', 'Không thể tải thành viên')}: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminMemberModel> get _visibleMembers {
    final query = _search.trim().toLowerCase();
    return _members.where((member) {
      if (_onlyMuted && !member.isMuted) return false;
      return query.isEmpty ||
          member.displayName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleMute(AdminMemberModel member) async {
    String? reason;
    if (!member.isMuted) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            AdminStrings.t('Mute posting access', 'Mute quyền đăng bài'),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AdminStrings.t(
                    '${member.displayName} can still use the app, but cannot create new Community posts.',
                    '${member.displayName} vẫn có thể dùng ứng dụng, nhưng không thể tạo bài Community mới.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: AdminStrings.t('Mute reason', 'Lý do mute'),
                    hintText: AdminStrings.t(
                      'Example: Repeated promotional posts...',
                      'Ví dụ: Đăng nội dung quảng cáo nhiều lần...',
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
                backgroundColor: const Color(0xFFB56A16),
              ),
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: Text(AdminStrings.t('Confirm mute', 'Xác nhận mute')),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AdminStrings.t('Unmute member', 'Bỏ mute thành viên')),
          content: Text(
            AdminStrings.t(
              '${member.displayName} will be able to post in Community again.',
              '${member.displayName} sẽ có thể đăng bài Community trở lại.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AdminStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AdminStrings.t('Unmute', 'Bỏ mute')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await widget.service.setUserMuted(
        userId: member.id,
        muted: !member.isMuted,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            member.isMuted
                ? AdminStrings.t('Member unmuted.', 'Đã bỏ mute thành viên.')
                : AdminStrings.t(
                    'Posting access muted.',
                    'Đã mute quyền đăng bài.',
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
            '${AdminStrings.t('Could not update member', 'Không thể cập nhật thành viên')}: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutedCount = _members.where((member) => member.isMuted).length;
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
                    AdminStrings.t('Community members', 'Thành viên Community'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AdminStrings.t(
                      '${_members.length} members • $mutedCount muted',
                      '${_members.length} thành viên • $mutedCount đang bị mute',
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
                      'Search name or email...',
                      'Tìm tên hoặc email...',
                    ),
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilterChip(
                selected: _onlyMuted,
                onSelected: (value) => setState(() => _onlyMuted = value),
                avatar: const Icon(Icons.volume_off_outlined, size: 17),
                label: Text(
                  AdminStrings.t('Muted users only', 'Chỉ xem user bị mute'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _MemberMessage(message: _error!, onRetry: _load)
          else if (_visibleMembers.isEmpty)
            _MemberMessage(
              message: AdminStrings.t(
                'No matching members found.',
                'Không tìm thấy thành viên phù hợp.',
              ),
            )
          else
            ..._visibleMembers.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MemberCard(
                  member: member,
                  isCurrentAdmin: member.id == widget.service.currentUser?.id,
                  onToggleMute: () => _toggleMute(member),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.isCurrentAdmin,
    required this.onToggleMute,
  });

  final AdminMemberModel member;
  final bool isCurrentAdmin;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE2F1EB),
            backgroundImage: member.avatarUrl?.isNotEmpty == true
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl?.isNotEmpty == true
                ? null
                : Text(
                    member.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF0B6B4F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      member.displayName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isCurrentAdmin)
                      const _MemberBadge(label: 'ADMIN', muted: false),
                    if (member.isMuted)
                      _MemberBadge(
                        label: AdminStrings.t('MUTED', 'ĐANG MUTE'),
                        muted: true,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  member.email,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 15,
                  runSpacing: 5,
                  children: [
                    _MemberMeta(
                      icon: Icons.article_outlined,
                      text: AdminStrings.t(
                        '${member.postCount} posts',
                        '${member.postCount} bài viết',
                      ),
                    ),
                    _MemberMeta(
                      icon: Icons.flag_outlined,
                      text: AdminStrings.t(
                        '${member.receivedReportCount} reports received',
                        '${member.receivedReportCount} báo cáo nhận được',
                      ),
                      warning: member.receivedReportCount > 0,
                    ),
                    _MemberMeta(
                      icon: Icons.calendar_today_outlined,
                      text:
                          '${AdminStrings.t('Joined', 'Tham gia')} ${_formatDate(member.createdAt)}',
                    ),
                  ],
                ),
                if (member.isMuted && member.muteReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${AdminStrings.t('Mute reason', 'Lý do mute')}: ${member.muteReason}',
                    style: const TextStyle(
                      color: Color(0xFF9A5A12),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: isCurrentAdmin ? null : onToggleMute,
            style: OutlinedButton.styleFrom(
              foregroundColor: member.isMuted
                  ? const Color(0xFF0B6B4F)
                  : const Color(0xFFB56A16),
            ),
            icon: Icon(
              member.isMuted
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              size: 18,
            ),
            label: Text(
              member.isMuted
                  ? AdminStrings.t('Unmute', 'Bỏ mute')
                  : AdminStrings.t('Mute posting', 'Mute đăng bài'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberBadge extends StatelessWidget {
  const _MemberBadge({required this.label, required this.muted});
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFFFF0D9) : const Color(0xFFE4F5EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? const Color(0xFF9A5A12) : const Color(0xFF087A52),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _MemberMeta extends StatelessWidget {
  const _MemberMeta({
    required this.icon,
    required this.text,
    this.warning = false,
  });
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
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}

class _MemberMessage extends StatelessWidget {
  const _MemberMessage({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icons.people_outline_rounded,
              size: 44,
              color: Color(0xFF78A597),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(AdminStrings.retry),
              ),
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
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
