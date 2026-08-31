import 'package:finflow/features/community/models/community_comment_model.dart';
import 'package:finflow/features/community/utils/comment_thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CommunityCommentModel comment(int index) {
    return CommunityCommentModel(
      id: 'comment-$index',
      postId: 'post-1',
      userId: 'user-$index',
      content: 'Comment $index',
      isAnonymous: false,
      createdAt: DateTime.utc(2026, 7, 30, 8, 0, index % 60),
      parentCommentId: index == 0 ? null : 'comment-${index - 1}',
    );
  }

  test('flattens a deeply nested expanded thread without recursion', () {
    const depth = 2000;
    final comments = List.generate(depth, comment);
    final entries = buildVisibleCommentThread(
      comments: comments,
      visibleRootCount: 5,
      expandedCommentIds: comments.map((item) => item.id).toSet(),
    );

    expect(entries, hasLength(depth));
    expect(entries.first.depth, 0);
    expect(entries.last.depth, depth - 1);
    expect(entries.last.comment.id, 'comment-${depth - 1}');
  });

  test('collapsed branches only expose their parent', () {
    final comments = List.generate(4, comment);
    final entries = buildVisibleCommentThread(
      comments: comments,
      visibleRootCount: 5,
      expandedCommentIds: const {},
    );

    expect(entries.map((entry) => entry.comment.id), ['comment-0']);
    expect(entries.single.directReplyCount, 1);
  });
}
