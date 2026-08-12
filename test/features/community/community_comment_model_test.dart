import 'package:finflow/features/community/models/community_comment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> commentJson({
    String id = 'comment-1',
    String? parentCommentId,
    int? likesCount,
  }) {
    return {
      'id': id,
      'post_id': 'post-1',
      'user_id': 'user-1',
      'content': 'Helpful advice',
      'is_anonymous': false,
      'created_at': '2026-07-30T08:00:00.000Z',
      'parent_comment_id': ?parentCommentId,
      'likes_count': ?likesCount,
    };
  }

  test('old top-level comments remain backward compatible', () {
    final comment = CommunityCommentModel.fromJson(commentJson());

    expect(comment.parentCommentId, isNull);
    expect(comment.likesCount, 0);
    expect(comment.isLikedByMe, isFalse);
  });

  test('parses recursive reply relationship and likes', () {
    final comment = CommunityCommentModel.fromJson(
      commentJson(id: 'comment-3', parentCommentId: 'comment-2', likesCount: 4),
    );

    expect(comment.parentCommentId, 'comment-2');
    expect(comment.likesCount, 4);
  });

  test('optimistic like copy preserves reply relationship', () {
    final reply = CommunityCommentModel.fromJson(
      commentJson(parentCommentId: 'comment-parent'),
    );
    final liked = reply.copyWith(likesCount: 1, isLikedByMe: true);

    expect(liked.parentCommentId, 'comment-parent');
    expect(liked.likesCount, 1);
    expect(liked.isLikedByMe, isTrue);
  });
}
