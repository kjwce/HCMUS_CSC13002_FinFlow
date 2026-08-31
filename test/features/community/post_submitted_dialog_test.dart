import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/features/community/presentation/widgets/post_submitted_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppLanguage.instance.setLocale(AppLocale.english));
  tearDown(() => AppLanguage.instance.setLocale(AppLocale.english));

  Future<void> pumpLauncher(
    WidgetTester tester,
    ValueChanged<PostSubmittedAction> onResult,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                onResult(await showPostSubmittedDialog(context));
              },
              child: const Text('Launch'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the English review message and returns dismiss', (
    tester,
  ) async {
    PostSubmittedAction? result;
    await pumpLauncher(tester, (value) => result = value);

    expect(find.text('Post submitted for review'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('View my activity'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(result, PostSubmittedAction.dismiss);
  });

  testWidgets('shows Vietnamese copy and returns view activity', (
    tester,
  ) async {
    AppLanguage.instance.setLocale(AppLocale.vietnamese);
    PostSubmittedAction? result;
    await pumpLauncher(tester, (value) => result = value);

    expect(find.text('Bài viết đã gửi thành công'), findsOneWidget);
    expect(find.text('Đã hiểu'), findsOneWidget);
    expect(find.text('Xem hoạt động của tôi'), findsOneWidget);

    await tester.tap(find.text('Xem hoạt động của tôi'));
    await tester.pumpAndSettle();
    expect(result, PostSubmittedAction.viewActivity);
  });
}
