import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/bank_notification_models.dart';

class BankNotificationPlatform {
  BankNotificationPlatform._();

  static final instance = BankNotificationPlatform._();
  static const _channel = MethodChannel('com.finflow/bank_notifications');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<BankNotificationConfiguration> configuration() async {
    if (!isSupported) {
      return const BankNotificationConfiguration(
        enabled: false,
        packages: <String>{},
        packagesConfigured: false,
      );
    }
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getImportConfiguration',
    );
    return BankNotificationConfiguration.fromMap(raw);
  }

  Future<Map<String, String>> diagnostics() async {
    if (!isSupported) return const {};
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getImportDiagnostics',
    );
    return {
      for (final entry in (raw ?? const {}).entries)
        entry.key.toString(): entry.value.toString(),
    };
  }

  Future<String?> consumeLaunchNotificationId() async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('consumeLaunchNotificationId');
  }

  Future<bool> requestListenerRebind() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>(
          'requestNotificationListenerRebind',
        ) ??
        false;
  }

  Future<bool> isAccessGranted() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isNotificationAccessGranted') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    if (isSupported) {
      await _channel.invokeMethod<void>('openNotificationAccessSettings');
    }
  }

  Future<bool> requestPostNotifications() async {
    if (isSupported) {
      return await _channel.invokeMethod<bool>('requestPostNotifications') ??
          false;
    }
    return false;
  }

  Future<bool> areAppNotificationsEnabled() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('areAppNotificationsEnabled') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openAppNotificationSettings() async {
    if (isSupported) {
      await _channel.invokeMethod<void>('openAppNotificationSettings');
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (isSupported) {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (isSupported) {
      await _channel.invokeMethod<void>('setImportEnabled', {
        'enabled': enabled,
      });
    }
  }

  Future<void> setEnabledPackages(Set<String> packages) async {
    if (isSupported) {
      await _channel.invokeMethod<void>('setEnabledPackages', {
        'packages': packages.toList(growable: false),
      });
    }
  }

  Future<List<BankNotificationEnvelope>> pending() async {
    if (!isSupported) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'getPendingNotifications',
    );
    return (raw ?? const [])
        .whereType<Map>()
        .map(BankNotificationEnvelope.fromMap)
        .where((item) => item.isValid)
        .toList(growable: false);
  }

  Future<bool> enqueueTestNotification(String packageName) async {
    if (isSupported && kDebugMode) {
      return await _channel.invokeMethod<bool>('enqueueTestNotification', {
            'packageName': packageName,
          }) ??
          false;
    }
    return false;
  }

  Future<void> acknowledge(String id) async {
    if (isSupported) {
      await _channel.invokeMethod<void>('acknowledgeNotification', {'id': id});
    }
  }
}
