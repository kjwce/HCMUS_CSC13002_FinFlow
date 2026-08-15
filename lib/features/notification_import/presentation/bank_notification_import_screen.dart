import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bank_notification_models.dart';
import '../services/bank_notification_configuration_migration.dart';
import '../services/bank_notification_import_coordinator.dart';
import '../services/bank_notification_platform.dart';

class BankNotificationImportScreen extends StatefulWidget {
  const BankNotificationImportScreen({super.key});

  @override
  State<BankNotificationImportScreen> createState() =>
      _BankNotificationImportScreenState();
}

class _BankNotificationImportScreenState
    extends State<BankNotificationImportScreen>
    with WidgetsBindingObserver {
  static const _consentKey = 'finflow_bank_import_consent';
  final _preferences = SharedPreferencesAsync();
  final _platform = BankNotificationPlatform.instance;
  var _enabled = false;
  var _accessGranted = false;
  var _postNotificationsGranted = false;
  var _loading = true;
  Map<String, String> _diagnostics = const {};
  Set<String> _packages = BankNotificationProvider.supported
      .map((provider) => provider.packageName)
      .toSet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshAccess());
  }

  Future<void> _load() async {
    await BankNotificationConfigurationMigration.instance.run();
    final (configuration, access, postNotifications, diagnostics) = await (
      _platform.configuration(),
      _platform.isAccessGranted(),
      _platform.areAppNotificationsEnabled(),
      _platform.diagnostics(),
    ).wait;
    var packages = configuration.packages;
    if (!configuration.packagesConfigured) {
      packages = BankNotificationProvider.supported
          .map((provider) => provider.packageName)
          .toSet();
      await _platform.setEnabledPackages(packages);
    }
    if (!mounted) return;
    setState(() {
      _enabled = configuration.enabled;
      _accessGranted = access;
      _postNotificationsGranted = postNotifications;
      _packages = packages;
      _diagnostics = diagnostics;
      _loading = false;
    });
  }

  Future<void> _refreshAccess() async {
    final (configuration, access, postNotifications, diagnostics) = await (
      _platform.configuration(),
      _platform.isAccessGranted(),
      _platform.areAppNotificationsEnabled(),
      _platform.diagnostics(),
    ).wait;
    if (mounted) {
      setState(() {
        _enabled = configuration.enabled;
        _packages = configuration.packages;
        _accessGranted = access;
        _postNotificationsGranted = postNotifications;
        _diagnostics = diagnostics;
      });
    }
    if (access && _enabled) {
      final allowed = await _platform.requestPostNotifications();
      if (mounted) setState(() => _postNotificationsGranted = allowed);
      unawaited(BankNotificationImportCoordinator.instance.processPending());
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (value && !_platform.isSupported) {
      _message('Tính năng này hiện chỉ hỗ trợ Android.');
      return;
    }
    if (value) {
      final consented = await _ensureConsent();
      if (!consented) return;
    }
    setState(() => _enabled = value);
    await _platform.setEnabled(value);
    if (value) {
      if (!await _platform.isAccessGranted()) {
        await _platform.openAccessSettings();
      } else {
        final allowed = await _platform.requestPostNotifications();
        if (mounted) setState(() => _postNotificationsGranted = allowed);
      }
    }
  }

  Future<bool> _ensureConsent() async {
    if (await _preferences.getBool(_consentKey) == true) return true;
    if (!mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.choose(
            'Allow transaction detection?',
            'Cho phép nhận diện giao dịch?',
          ),
        ),
        content: Text(
          AppStrings.choose(
            'FinFlow will read notification titles and content from the bank and e-wallet apps you select, mask account-number sequences, then send the content to Gemini through Supabase to detect the amount, transaction type, and category.\n\nFinFlow ignores other apps, never saves transactions automatically, and always asks you to review before saving. You can revoke access at any time.',
            'FinFlow sẽ đọc tiêu đề và nội dung thông báo từ các ứng dụng ngân hàng/ví bạn chọn, che bớt chuỗi số tài khoản rồi gửi nội dung đến Gemini qua Supabase để nhận diện số tiền, thu/chi và danh mục.\n\nFinFlow bỏ qua ứng dụng khác, không tự lưu giao dịch và luôn yêu cầu bạn kiểm tra trước khi lưu. Bạn có thể tắt quyền bất cứ lúc nào.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.choose('Decline', 'Không đồng ý')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.choose('Allow', 'Đồng ý')),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _preferences.setBool(_consentKey, true);
      return true;
    }
    return false;
  }

  Future<void> _togglePackage(String packageName, bool selected) async {
    setState(() {
      if (selected) {
        _packages.add(packageName);
      } else {
        _packages.remove(packageName);
      }
    });
    await _platform.setEnabledPackages(_packages);
  }

  Future<void> _reconnectListener() async {
    final requested = await _platform.requestListenerRebind();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final diagnostics = await _platform.diagnostics();
    if (!mounted) return;
    setState(() => _diagnostics = diagnostics);
    _message(
      requested
          ? AppStrings.choose(
              'Android was asked to reconnect the listener.',
              'Đã yêu cầu Android kết nối lại trình theo dõi.',
            )
          : AppStrings.choose(
              'Notification access has not been granted.',
              'Quyền truy cập thông báo chưa được cấp.',
            ),
    );
  }

  Widget _buildListenerHealth() {
    final colors = context.finFlowColors;
    final state = _diagnostics['listener_state'] ?? 'unknown';
    final connected = state == 'connected';
    final lastPostStatus = _diagnostics['last_post_status'];
    final lastSourceAt = _formatDiagnosticTime(
      _diagnostics['last_source_received_at'],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          connected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
          color: connected ? const Color(0xFF00866A) : Colors.orange,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connected
                    ? AppStrings.choose(
                        'The listener is connected',
                        'Trình theo dõi đang kết nối',
                      )
                    : AppStrings.choose(
                        'Background connection is not confirmed',
                        'Chưa xác nhận được kết nối nền',
                      ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (lastSourceAt != null)
                Text(
                  AppStrings.choose(
                    'Latest source notification: $lastSourceAt',
                    'Nhận thông báo nguồn gần nhất: $lastSourceAt',
                  ),
                  style: TextStyle(color: colors.secondaryText, fontSize: 12),
                ),
              if (lastPostStatus != null)
                Text(
                  AppStrings.choose(
                    'Latest confirmation delivery: $lastPostStatus',
                    'Lần gửi xác nhận gần nhất: $lastPostStatus',
                  ),
                  style: TextStyle(color: colors.secondaryText, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String? _formatDiagnosticTime(String? raw) {
    final milliseconds = int.tryParse(raw ?? '');
    if (milliseconds == null || milliseconds <= 0) return null;
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second ${value.day}/${value.month}/${value.year}';
  }

  Future<void> _testDetection() async {
    if (!_enabled) {
      _message(
        AppStrings.choose(
          'Enable this feature before testing.',
          'Hãy bật tính năng trước khi chạy thử.',
        ),
      );
      return;
    }
    if (_packages.isEmpty) {
      _message(
        AppStrings.choose(
          'Select at least one bank or e-wallet app.',
          'Hãy chọn ít nhất một ứng dụng ngân hàng hoặc ví.',
        ),
      );
      return;
    }
    final shown = await _platform.enqueueTestNotification(_packages.first);
    if (!mounted) return;
    if (shown) {
      _message(
        AppStrings.choose(
          'A test notification was sent. Check your phone notification tray.',
          'Đã gửi thông báo thử. Hãy kiểm tra thanh thông báo của điện thoại.',
        ),
      );
    } else {
      _message(
        AppStrings.choose(
          'Unable to send a notification. Enable FinFlow notifications.',
          'Không thể gửi thông báo. Hãy bật quyền thông báo FinFlow.',
        ),
      );
      await _platform.openAppNotificationSettings();
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.primaryText,
        elevation: 0,
        title: Text(
          AppStrings.choose(
            'Automatic Transaction Detection',
            'Tự động nhận diện giao dịch',
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _enabled,
                        onChanged: _setEnabled,
                        title: Text(
                          AppStrings.choose(
                            'Read transaction notifications',
                            'Đọc thông báo giao dịch',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          AppStrings.choose(
                            'Gemini creates a draft; you confirm before saving.',
                            'Gemini tạo bản nháp; bạn xác nhận trước khi lưu.',
                          ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Icon(
                            _accessGranted
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded,
                            color: _accessGranted
                                ? const Color(0xFF00866A)
                                : Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _accessGranted
                                  ? AppStrings.choose(
                                      'Notification access granted',
                                      'Đã cấp quyền truy cập thông báo',
                                    )
                                  : AppStrings.choose(
                                      'Notification access not granted',
                                      'Chưa cấp quyền truy cập thông báo',
                                    ),
                            ),
                          ),
                          TextButton(
                            onPressed: _platform.openAccessSettings,
                            child: Text(
                              AppStrings.choose('Open settings', 'Mở cài đặt'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Icon(
                            _postNotificationsGranted
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                            color: _postNotificationsGranted
                                ? const Color(0xFF00866A)
                                : Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _postNotificationsGranted
                                  ? AppStrings.choose(
                                      'FinFlow can send notifications',
                                      'FinFlow được phép gửi thông báo',
                                    )
                                  : AppStrings.choose(
                                      'FinFlow notifications are disabled',
                                      'Thông báo của FinFlow đang bị tắt',
                                    ),
                            ),
                          ),
                          TextButton(
                            onPressed: _platform.openAppNotificationSettings,
                            child: Text(
                              AppStrings.choose('Open settings', 'Mở cài đặt'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildListenerHealth(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _reconnectListener,
                              icon: const Icon(Icons.sync_rounded),
                              label: Text(
                                AppStrings.choose('Reconnect', 'Kết nối lại'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _platform.openBatteryOptimizationSettings,
                              icon: const Icon(Icons.battery_saver_rounded),
                              label: Text(
                                AppStrings.choose(
                                  'Battery settings',
                                  'Cài đặt pin',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (kDebugMode) ...[
                        const Divider(),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _testDetection,
                            icon: const Icon(Icons.science_outlined),
                            label: Text(
                              AppStrings.choose(
                                'Create test transaction notification',
                                'Tạo thông báo giao dịch thử',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  AppStrings.choose(
                    'Apps allowed to be read',
                    'Ứng dụng được phép đọc',
                  ),
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.choose(
                    'Notifications from unselected apps are ignored directly on the phone.',
                    'Thông báo từ ứng dụng không được chọn sẽ bị bỏ qua ngay trên điện thoại.',
                  ),
                  style: TextStyle(color: colors.secondaryText),
                ),
                const SizedBox(height: 10),
                ...BankNotificationProvider.supported.map(
                  (provider) => CheckboxListTile(
                    value: _packages.contains(provider.packageName),
                    onChanged: (value) =>
                        _togglePackage(provider.packageName, value == true),
                    title: Text(provider.name),
                    subtitle: Text(
                      provider.packageName,
                      style: TextStyle(
                        color: colors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.choose(
                    'Note: notification formats and app packages may change between bank versions. Transactions without enough data will not be saved automatically.',
                    'Lưu ý: định dạng và package ứng dụng có thể thay đổi theo phiên bản ngân hàng. Giao dịch không đủ dữ liệu sẽ không được tự động lưu.',
                  ),
                  style: TextStyle(color: colors.secondaryText, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
