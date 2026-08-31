import 'package:finflow/core/theme/app_colors.dart';
import 'package:finflow/features/community/models/community_report_model.dart';
import 'package:finflow/features/community/models/community_post_model.dart';
import 'package:finflow/features/community/presentation/widgets/community_report_dialog.dart';
import 'package:finflow/features/community/presentation/widgets/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    CommunityReportSubmitResult result = CommunityReportSubmitResult.submitted,
    String content = 'Automated a small transfer every payday.',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [FinFlowColors.light],
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCommunityReportDialog(
                  context: context,
                  target: CommunityReportTarget.post,
                  authorName: 'Emma Chen',
                  content: content,
                  onSubmit: (_, _) async => result,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpPostCard(
    WidgetTester tester, {
    required String currentUserId,
  }) async {
    final post = CommunityPostModel(
      id: 'post-1',
      userId: 'author-1',
      content: 'A community post',
      isAnonymous: false,
      category: 'Saving',
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.utc(2026, 8, 28),
      authorName: 'Emma Chen',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [FinFlowColors.light],
        ),
        home: Scaffold(
          body: CommunityPostCard(
            post: post,
            currentUserId: currentUserId,
            onTap: () {},
            onLikeTap: () {},
            onSaveTap: () {},
            onEditTap: () {},
            onDeleteTap: () {},
            onReportTap: () {},
          ),
        ),
      ),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('requires a reason and shows the success state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(tester);

    var submit = tester.widget<FilledButton>(
      find.byKey(const Key('submit-report-button')),
    );
    expect(submit.onPressed, isNull);

    final reason = find.byKey(const Key('report-reason-spam_misleading'));
    await tester.ensureVisible(reason);
    await tester.tap(reason);
    await tester.pump();

    submit = tester.widget<FilledButton>(
      find.byKey(const Key('submit-report-button')),
    );
    expect(submit.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('submit-report-button')));
    await tester.pumpAndSettle();

    expect(find.text('Report submitted'), findsOneWidget);
    expect(find.byKey(const Key('close-report-result')), findsOneWidget);
  });

  testWidgets('shows a dedicated already-reported result', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(
      tester,
      result: CommunityReportSubmitResult.alreadyReported,
    );

    final reason = find.byKey(const Key('report-reason-other'));
    await tester.ensureVisible(reason);
    await tester.tap(reason);
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-report-button')));
    await tester.pumpAndSettle();

    expect(find.text('You already reported this content'), findsOneWidget);
  });

  testWidgets('preview removes community formatting markers', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(
      tester,
      content: '**Bold** *italic* ~underlined~ and normal',
    );

    final preview = tester.widget<Text>(
      find.byKey(const Key('report-content-preview')),
    );
    expect(preview.data, 'Bold italic underlined and normal');
    expect(preview.style?.fontWeight, isNot(FontWeight.bold));
    expect(preview.style?.fontStyle, isNot(FontStyle.italic));
    expect(preview.style?.decoration, isNot(TextDecoration.underline));
  });

  testWidgets('other users see report while the author sees edit and delete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPostCard(tester, currentUserId: 'viewer-1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Report post'), findsOneWidget);
    expect(find.text('Edit post'), findsNothing);

    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();
    await pumpPostCard(tester, currentUserId: 'author-1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Edit post'), findsOneWidget);
    expect(find.text('Delete post'), findsOneWidget);
    expect(find.text('Report post'), findsNothing);
  });
}
