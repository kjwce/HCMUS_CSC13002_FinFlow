import 'package:shared_preferences/shared_preferences.dart';

import 'bank_notification_platform.dart';

/// One-time bridge from the previous duplicated Flutter preferences to the
/// native SQLite configuration used by NotificationListenerService.
class BankNotificationConfigurationMigration {
  BankNotificationConfigurationMigration._();

  static final instance = BankNotificationConfigurationMigration._();

  static const _legacyEnabledKey = 'finflow_bank_import_enabled';
  static const _legacyPackagesKey = 'finflow_bank_import_packages';

  final _preferences = SharedPreferencesAsync();
  bool _completed = false;

  Future<void> run() async {
    if (_completed || !BankNotificationPlatform.instance.isSupported) return;
    final legacyEnabled = await _preferences.getBool(_legacyEnabledKey);
    final legacyPackages = await _preferences.getStringList(_legacyPackagesKey);
    if (legacyPackages != null) {
      await BankNotificationPlatform.instance.setEnabledPackages(
        legacyPackages.toSet(),
      );
    }
    if (legacyEnabled != null) {
      await BankNotificationPlatform.instance.setEnabled(legacyEnabled);
    }
    if (legacyEnabled != null || legacyPackages != null) {
      await _preferences.remove(_legacyEnabledKey);
      await _preferences.remove(_legacyPackagesKey);
    }
    _completed = true;
  }
}
