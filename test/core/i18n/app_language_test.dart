import 'package:finflow/app/shell/finflow_app.dart';
import 'package:finflow/core/i18n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  tearDown(() {
    AppLanguage.instance.setLocale(AppLocale.english);
  });

  test('language setting shows only the currently selected language', () {
    AppLanguage.instance.setLocale(AppLocale.english);
    expect(AppStrings.selectedLanguage, 'English');

    AppLanguage.instance.setLocale(AppLocale.vietnamese);
    expect(AppStrings.selectedLanguage, 'Tiếng Việt');
  });

  testWidgets('FinFlowApp rebuilds with the selected application locale', (
    tester,
  ) async {
    AppLanguage.instance.setLocale(AppLocale.english);
    await tester.pumpWidget(const ProviderScope(child: FinFlowApp()));

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );
    expect(
      find.text('Take Control of Your Finances\nwith Budget Genius'),
      findsOneWidget,
    );

    AppLanguage.instance.setLocale(AppLocale.vietnamese);
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('vi'),
    );
    expect(
      find.text('Làm chủ tài chính của bạn\ncùng trợ lý ngân sách thông minh'),
      findsOneWidget,
    );
    expect(
      find.text('Take Control of Your Finances\nwith Budget Genius'),
      findsNothing,
    );
  });
}
