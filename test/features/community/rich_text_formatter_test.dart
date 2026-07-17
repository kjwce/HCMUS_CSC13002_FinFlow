import 'package:finflow/features/community/utils/rich_text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseStyle = TextStyle(fontSize: 14);

  Future<TextSpan> renderContent(
    WidgetTester tester,
    String content, {
    int? maxLines,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichPostContent(
            content: content,
            style: baseStyle,
            maxLines: maxLines,
          ),
        ),
      ),
    );
    return tester.widget<RichText>(find.byType(RichText).last).text as TextSpan;
  }

  List<TextSpan> leafSpans(InlineSpan span) {
    if (span is! TextSpan) return const [];
    if (span.children == null) return [span];
    return [for (final child in span.children!) ...leafSpans(child)];
  }

  test('notification preview strips markers but preserves their text', () {
    expect(
      stripFormattingForPreview(
        '**Bold** *italic* ~underlined~ ||hidden content||',
      ),
      'Bold italic underlined 🙈 spoiler',
    );
  });

  test('full notification message cannot leak formatting markers', () {
    final preview = stripFormattingForNotificationPreview(
      'shared a new community post: "**Budget** *today* ~important~"',
    );

    expect(preview, 'shared a new community post: "Budget today important"');
    expect(preview, isNot(contains('*')));
    expect(preview, isNot(contains('~')));
  });

  test('legacy notification history removes unmatched old markers', () {
    final preview = stripFormattingForNotificationPreview(
      'shared a post: ~ **Old budget note* ||unfinished',
    );

    expect(preview, 'shared a post: Old budget note unfinished');
    expect(preview, isNot(contains('*')));
    expect(preview, isNot(contains('~')));
    expect(preview, isNot(contains('||')));
  });

  testWidgets('renders formatting in a limited feed preview', (tester) async {
    final root = await renderContent(
      tester,
      '**Bold** *italic* ~underlined~',
      maxLines: 3,
    );
    final leaves = leafSpans(root);

    expect(leaves.map((span) => span.text).join(), 'Bold italic underlined');
    expect(leaves[0].style?.fontWeight, FontWeight.w800);
    expect(leaves[2].style?.fontStyle, FontStyle.italic);
    expect(leaves[4].style?.decoration, TextDecoration.underline);
  });

  testWidgets('renders combined formatting without leaking markers', (
    tester,
  ) async {
    final root = await renderContent(tester, '~***All three***~');
    final leaves = leafSpans(root);

    expect(leaves.single.text, 'All three');
    expect(leaves.single.style?.fontWeight, FontWeight.w800);
    expect(leaves.single.style?.fontStyle, FontStyle.italic);
    expect(leaves.single.style?.decoration, TextDecoration.underline);
  });

  testWidgets('keeps unmatched marker characters as normal text', (
    tester,
  ) async {
    final root = await renderContent(tester, 'About ~ 100 and price * 2');

    expect(
      leafSpans(root).map((span) => span.text).join(),
      'About ~ 100 and price * 2',
    );
  });
}
