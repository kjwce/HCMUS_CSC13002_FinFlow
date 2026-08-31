import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/screens/community_post_detail_screen.dart';
import '../../features/community/models/notification_model.dart';
import '../../features/community/services/notification_service.dart';
import '../../features/finance/services/recurring_service.dart';
import '../../features/settings/services/notification_preferences_service.dart';
import '../i18n/app_language.dart';

class InAppNotificationHost extends StatefulWidget {
  const InAppNotificationHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<InAppNotificationHost> createState() => _InAppNotificationHostState();
}

class _InAppNotificationHostState extends State<InAppNotificationHost> {
  static const _emerald = Color(0xFF007C61);
  static const _violet = Color(0xFF7558CB);

  final List<NotificationModel> _items = [];
  final Set<String> _successIds = {};
  StreamSubscription<NotificationModel>? _subscription;
  Timer? _dismissTimer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _subscription = NotificationService.instance.incoming.listen(_enqueue);
    NotificationPreferencesService.instance.addListener(_preferencesChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissTimer?.cancel();
    NotificationPreferencesService.instance.removeListener(_preferencesChanged);
    super.dispose();
  }

  void _preferencesChanged() {
    final preferences = NotificationPreferencesService.instance.value;
    if (preferences.masterEnabled && preferences.inAppBannerEnabled) return;
    if (!mounted || _items.isEmpty) return;
    setState(() {
      _items.clear();
      _expanded = false;
    });
  }

  void _enqueue(NotificationModel notification) {
    final preferences = NotificationPreferencesService.instance.value;
    if (!preferences.masterEnabled || !preferences.inAppBannerEnabled) return;
    if (!mounted || _items.any((item) => item.id == notification.id)) return;
    setState(() {
      _items.insert(0, notification);
      if (_items.length > 4) _items.removeLast();
    });
    _restartDismissTimer();
  }

  void _restartDismissTimer() {
    _dismissTimer?.cancel();
    if (_expanded || _items.isEmpty) return;
    _dismissTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_expanded && _items.isNotEmpty) {
        _dismiss(_items.last.id);
      }
    });
  }

  void _setExpanded(bool value) {
    _dismissTimer?.cancel();
    setState(() => _expanded = value);
    if (!value) _restartDismissTimer();
  }

  void _dismiss(String id) {
    if (!mounted) return;
    setState(() {
      _items.removeWhere((item) => item.id == id);
      _successIds.remove(id);
      if (_items.isEmpty) _expanded = false;
    });
    _restartDismissTimer();
  }

  Future<void> _open(NotificationModel notification) async {
    await NotificationService.instance.markAsRead(notification.id);
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    switch (notification.category) {
      case NotificationCategory.recurring:
        if (notification.scheduleId != null) {
          await navigator.pushNamed(
            '/recurring/details',
            arguments: notification.scheduleId,
          );
        }
        break;
      case NotificationCategory.community:
        if (notification.postId != null) {
          await navigator.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  CommunityPostDetailScreen(postId: notification.postId!),
            ),
          );
        }
        break;
      case NotificationCategory.budget:
        await navigator.pushNamed('/category-budgets');
        break;
      case NotificationCategory.goal:
        await navigator.pushNamed(
          '/saving-goals/details',
          arguments:
              notification.entityId ??
              notification.payload['goal_id']?.toString(),
        );
        break;
      case NotificationCategory.transaction:
        await navigator.pushNamed('/dashboard', arguments: 0);
        break;
      case NotificationCategory.system:
        break;
    }
    _dismiss(notification.id);
  }

  Future<void> _secondary(NotificationModel notification) async {
    if (notification.isRecurring && notification.scheduleId != null) {
      final schedule = RecurringService.instance.findById(
        notification.scheduleId!,
      );
      if (schedule != null) {
        await RecurringService.instance.skipOccurrence(schedule);
      }
    }
    await NotificationService.instance.resolve(
      notification.id,
      status: 'dismissed',
    );
    if (!mounted) return;
    setState(() => _successIds.add(notification.id));
    _dismissTimer?.cancel();
    _dismissTimer = Timer(
      const Duration(milliseconds: 1500),
      () => _dismiss(notification.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_expanded && _items.isNotEmpty)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _setExpanded(false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: ColoredBox(color: Colors.black.withValues(alpha: .14)),
              ),
            ),
          ),
        if (_items.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + 8,
            child: SafeArea(
              top: false,
              child: Material(
                type: MaterialType.transparency,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -.45),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _expanded ? _expandedPanel() : _compactStack(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _compactStack() {
    final current = _items.first;
    return GestureDetector(
      key: const Key('in-app-notification-compact'),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 180) _setExpanded(true);
      },
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0).abs() > 250) _dismiss(current.id);
      },
      child: SizedBox(
        height: 104 + (_items.length.clamp(1, 3) - 1) * 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var layer = _items.length.clamp(1, 3) - 1; layer >= 1; layer--)
              Positioned(
                left: layer * 8.0,
                right: layer * 8.0,
                top: layer * 8.0,
                child: Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF16352E)
                        : const Color(0xFFE4F5EE),
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2200523C),
                        blurRadius: 13,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned.fill(
              bottom: (_items.length.clamp(1, 3) - 1) * 8.0,
              child: _compactCard(current),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactCard(NotificationModel notification) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final success = _successIds.contains(notification.id);
    final color = success ? _emerald : _colorFor(notification);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF16352E) : Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: dark ? const Color(0xFF31564B) : const Color(0xFFC8E2D8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300523C),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _icon(notification, color, success: success),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.choose('FinFlow · now', 'FinFlow · bây giờ'),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: dark
                        ? const Color(0xFFA9C1B9)
                        : const Color(0xFF62746D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  success
                      ? AppStrings.choose('Action completed', 'Đã xử lý xong')
                      : notification.localizedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: dark
                        ? const Color(0xFFF4FBF8)
                        : const Color(0xFF15382F),
                  ),
                ),
                if (!success && notification.message.isNotEmpty)
                  Text(
                    notification.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 13,
                      color: dark
                          ? const Color(0xFFA9C1B9)
                          : const Color(0xFF5B6D66),
                    ),
                  ),
              ],
            ),
          ),
          if (_items.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _emerald,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${_items.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          IconButton(
            tooltip: AppStrings.choose('Expand', 'Mở rộng'),
            onPressed: () => _setExpanded(true),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }

  Widget _expandedPanel() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      key: const Key('in-app-notification-expanded'),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -180) _setExpanded(false);
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .64,
        ),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF112622) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: dark ? const Color(0xFF29483F) : const Color(0xFFC8E2D8),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44001610),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: AppStrings.choose('Collapse', 'Thu gọn'),
                    onPressed: () => _setExpanded(false),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  Expanded(
                    child: Text(
                      AppStrings.choose('New notifications', 'Thông báo mới'),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: dark
                            ? const Color(0xFFF4FBF8)
                            : const Color(0xFF15382F),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      NotificationService.instance.markAllAsRead();
                      setState(() {});
                    },
                    child: Text(
                      AppStrings.choose('Mark read', 'Đánh dấu đã đọc'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = _items[index];
                  return _expandedItem(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedItem(NotificationModel notification) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final success = _successIds.contains(notification.id);
    final color = success ? _emerald : _colorFor(notification);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF16352E) : const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: dark ? const Color(0xFF29483F) : const Color(0xFFDCE8E3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _icon(notification, color, success: success),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  success
                      ? AppStrings.choose('Action completed', 'Đã xử lý xong')
                      : notification.localizedTitle,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: dark
                        ? const Color(0xFFF4FBF8)
                        : const Color(0xFF15382F),
                  ),
                ),
                if (!success && notification.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 13,
                      height: 1.3,
                      color: dark
                          ? const Color(0xFFA9C1B9)
                          : const Color(0xFF5B6D66),
                    ),
                  ),
                ],
                if (!success) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _open(notification),
                        style: FilledButton.styleFrom(
                          backgroundColor: _emerald,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          notification.actionRequired
                              ? AppStrings.choose('Review', 'Xem lại')
                              : AppStrings.choose('Open', 'Mở'),
                        ),
                      ),
                      if (notification.actionRequired)
                        TextButton(
                          onPressed: () => _secondary(notification),
                          child: Text(AppStrings.choose('Skip', 'Bỏ qua')),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _dismiss(notification.id),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _icon(
    NotificationModel notification,
    Color color, {
    bool success = false,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        success ? Icons.check_rounded : _iconFor(notification),
        color: color,
        size: 21,
      ),
    );
  }

  Color _colorFor(NotificationModel notification) {
    return switch (notification.category) {
      NotificationCategory.recurring =>
        notification.actionRequired ? _violet : _emerald,
      NotificationCategory.budget => const Color(0xFFE39A16),
      NotificationCategory.goal => _violet,
      NotificationCategory.community => const Color(0xFF3799D2),
      NotificationCategory.transaction => const Color(0xFF3976B8),
      NotificationCategory.system => _emerald,
    };
  }

  IconData _iconFor(NotificationModel notification) {
    return switch (notification.category) {
      NotificationCategory.recurring =>
        notification.actionRequired
            ? Icons.event_repeat_rounded
            : Icons.event_available_outlined,
      NotificationCategory.budget => Icons.account_balance_wallet_outlined,
      NotificationCategory.goal => Icons.track_changes_rounded,
      NotificationCategory.community => Icons.chat_bubble_outline_rounded,
      NotificationCategory.transaction => Icons.receipt_long_outlined,
      NotificationCategory.system => Icons.info_outline_rounded,
    };
  }
}
