import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme_manager.dart';
import 'package:finflow/core/widgets/home_header_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  setUp(() {
    AppLanguage.instance.setLocale(AppLocale.english);
    AppThemeManager.instance.setMode(ThemeMode.light);
  });

  tearDown(() {
    AppLanguage.instance.setLocale(AppLocale.english);
    AppThemeManager.instance.setMode(ThemeMode.light);
  });

  testWidgets('opens centered language dialog and changes the app locale', (
    tester,
  ) async {
    await tester.pumpWidget(const _ControlsHost());

    await tester.tap(find.byKey(const Key('home-language-selector')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-language-dialog')), findsOneWidget);
    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-option-vi')));
    await tester.pumpAndSettle();

    expect(AppLanguage.instance.locale, AppLocale.vietnamese);
    expect(find.byKey(const Key('home-language-dialog')), findsNothing);
  });

  testWidgets('theme control switches between moon and sun states', (
    tester,
  ) async {
    await tester.pumpWidget(const _ControlsHost());

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-theme-toggle')));
    await tester.pumpAndSettle();

    expect(AppThemeManager.instance.mode, ThemeMode.dark);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}

class _ControlsHost extends StatelessWidget {
  const _ControlsHost();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLanguage.instance,
        AppThemeManager.instance,
      ]),
      builder: (context, _) => MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: AppThemeManager.instance.mode,
        home: const Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [HomeLanguageSelector(), HomeThemeToggle()],
            ),
          ),
        ),
      ),
    );
  }
}
