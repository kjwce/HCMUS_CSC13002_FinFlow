import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/core/widgets/home_header_controls.dart';
import 'package:finflow/features/settings/presentation/settings_screen.dart';
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

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  setUp(() => AppLanguage.instance.setLocale(AppLocale.english));
  tearDown(() => AppLanguage.instance.setLocale(AppLocale.english));

  testWidgets('Settings reuses the centered Home language dialog with flags', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ProviderScope(child: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-language-dialog')), findsOneWidget);
    expect(find.byType(LanguageFlag), findsNWidgets(2));
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('English'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const Key('language-option-vi')));
    await tester.pumpAndSettle();

    expect(AppLanguage.instance.locale, AppLocale.vietnamese);
    expect(find.byKey(const Key('home-language-dialog')), findsNothing);
  });

  testWidgets('Settings rows use readable title and description sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ProviderScope(child: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Notification Preferences'));
    final subtitle = tester.widget<Text>(
      find.text('Budgets, recurring and community'),
    );

    expect(title.style?.fontSize, greaterThanOrEqualTo(15));
    expect(subtitle.style?.fontSize, greaterThanOrEqualTo(12.3));
    expect(tester.takeException(), isNull);
  });
}
