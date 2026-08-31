import 'package:finflow/app/screens/profile_screen.dart';
import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  tearDownAll(() => SharedPreferencesAsyncPlatform.instance = null);

  setUp(() => AppLanguage.instance.setLocale(AppLocale.english));
  tearDown(() => AppLanguage.instance.setLocale(AppLocale.english));

  testWidgets('profile menu uses readable primary and secondary typography', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ProviderScope(child: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final appSettings = tester.widget<Text>(find.text('App Settings'));
    final description = tester.widget<Text>(find.text('Notifications & Theme'));

    expect(appSettings.style?.fontSize, greaterThanOrEqualTo(15));
    expect(description.style?.fontSize, greaterThanOrEqualTo(12.5));
    expect(find.text('Community Activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
