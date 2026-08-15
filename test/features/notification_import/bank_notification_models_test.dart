import 'package:finflow/features/notification_import/models/bank_notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads native SQLite notification-import configuration', () {
    final configuration = BankNotificationConfiguration.fromMap({
      'enabled': true,
      'packages': ['com.VCB', 'com.mservice.momotransfer'],
      'packagesConfigured': true,
    });

    expect(configuration.enabled, isTrue);
    expect(
      configuration.packages,
      {'com.VCB', 'com.mservice.momotransfer'},
    );
    expect(configuration.packagesConfigured, isTrue);
  });

  test('uses safe defaults for an empty configuration', () {
    final configuration = BankNotificationConfiguration.fromMap({});

    expect(configuration.enabled, isFalse);
    expect(configuration.packages, isEmpty);
    expect(configuration.packagesConfigured, isFalse);
  });
}
