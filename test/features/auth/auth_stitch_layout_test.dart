import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/core/theme/app_theme_manager.dart';
import 'package:finflow/features/auth/presentation/sign_in_screen.dart';
import 'package:finflow/features/auth/presentation/sign_up_screen.dart';
import 'package:finflow/features/auth/presentation/new_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> pumpAuthScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 884);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sign in fills the Stitch mobile viewport', (tester) async {
    await pumpAuthScreen(tester, const SignInScreen());

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    final emailField = tester.getRect(find.byType(TextField).first);
    final googleButton = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
    );
    final accountLink = tester.getRect(
      find.text(AppStrings.newToFinflowSignUp),
    );

    expect(emailField.width, greaterThan(310));
    expect(accountLink.top - googleButton.bottom, lessThan(80));
    expect(find.widgetWithText(ElevatedButton, 'Log In'), findsOneWidget);
  });

  testWidgets('reset password uses the same six-character minimum', (
    tester,
  ) async {
    await pumpAuthScreen(tester, const NewPasswordScreen());

    expect(find.text('At least 6 characters'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsNothing);
  });

  testWidgets('sign up remains full width and vertically balanced', (
    tester,
  ) async {
    await pumpAuthScreen(tester, const SignUpScreen());

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('Confirm your password'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.enterText(find.byType(TextField).at(2), 'FinFlow1');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));

    final nameField = tester.getRect(find.byType(TextField).first);
    final termsCheckbox = tester.getRect(find.byType(Checkbox));
    final termsText = tester.getRect(
      find.text('I agree to the Terms of Service and Privacy Policy.'),
    );
    final accountLink = tester.getRect(
      find.text(AppStrings.alreadyHaveAccount),
    );

    expect(nameField.width, greaterThan(310));
    expect(termsCheckbox.center.dy, closeTo(termsText.center.dy, 1));
    expect(accountLink.bottom, greaterThan(780));

    await tester.enterText(find.byType(TextField).at(0), 'Alex Veridian');
    await tester.enterText(find.byType(TextField).at(1), 'alex@example.com');
    await tester.enterText(find.byType(TextField).at(3), 'FinFlow2');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.passwordsDoNotMatch), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final confirmField = tester.widget<TextField>(find.byType(TextField).at(3));
    expect(confirmField.decoration?.errorText, AppStrings.passwordsDoNotMatch);
    expect(confirmField.decoration?.focusedErrorBorder, isNotNull);
  });
}
