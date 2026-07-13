import 'package:finflow/core/theme/app_colors.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/core/theme/app_theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppThemeManager.instance.setMode(ThemeMode.light);
  });

  test('FinFlow defaults to light when no preference exists', () async {
    await AppThemeManager.instance.init();
    expect(AppThemeManager.instance.mode, ThemeMode.light);
  });

  test('system mode is never accepted', () {
    AppThemeManager.instance.setMode(ThemeMode.dark);
    AppThemeManager.instance.setMode(ThemeMode.system);
    expect(AppThemeManager.instance.mode, ThemeMode.dark);
  });

  test('light and dark themes expose controlled semantic colors', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(
      AppTheme.light.extension<FinFlowColors>()?.pageBackground,
      FinFlowColors.light.pageBackground,
    );
    expect(
      AppTheme.dark.extension<FinFlowColors>()?.pageBackground,
      FinFlowColors.dark.pageBackground,
    );
  });

  testWidgets('selected FinFlow theme does not read platform brightness', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        home: const Scaffold(body: Text('FinFlow')),
      ),
    );

    final context = tester.element(find.text('FinFlow'));
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
