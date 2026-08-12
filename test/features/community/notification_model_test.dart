import 'package:finflow/features/community/models/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NotificationModel notification(String type) => NotificationModel(
    id: 'notification-1',
    userId: 'recipient-1',
    actorId: 'actor-1',
    postId: 'post-1',
    type: type,
    isRead: false,
    createdAt: DateTime(2026, 7, 13),
    actorName: 'Another user',
    postContent: 'A community post',
  );

  test('post activity has a community-wide message', () {
    expect(
      notification('post').message,
      'shared a new community post: "A community post"',
    );
  });

  test('comment activity does not claim it is always the recipient post', () {
    expect(
      notification('comment').message,
      'commented on a community post: "A community post"',
    );
  });

  test('reply activity identifies the recipient comment', () {
    expect(
      notification('comment_reply').message,
      'replied to your comment on "A community post"',
    );
  });

  test('comment like activity identifies the recipient comment', () {
    expect(
      notification('comment_like').message,
      'liked your comment on "A community post"',
    );
  });
}
