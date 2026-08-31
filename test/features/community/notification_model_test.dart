import 'package:finflow/features/community/models/notification_model.dart';
import 'package:finflow/core/i18n/app_language.dart';
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

  test('parses migration 033 canonical rows and keeps action metadata', () {
    final parsed = NotificationModel.fromJson({
      'id': 'n-033',
      'user_id': 'recipient-1',
      'category': 'recurring',
      'type': 'recurring_review',
      'priority': 'high',
      'action_required': true,
      'is_read': false,
      'is_archived': false,
      'status': 'pending',
      'payload': {'amount': -260000, 'name': 'Netflix'},
      'created_at': '2026-08-29T10:30:00+07:00',
    });

    expect(parsed.category, NotificationCategory.recurring);
    expect(parsed.priority, NotificationPriority.high);
    expect(parsed.actionRequired, isTrue);
    expect(parsed.payload['amount'], -260000);
    expect(parsed.isVisible, isTrue);
  });

  test('budget titles use localized payload names', () {
    final parsed = NotificationModel.fromJson({
      'id': 'budget-1',
      'user_id': 'recipient-1',
      'category': 'budget',
      'type': 'budget_threshold',
      'payload': {'name': 'Food', 'name_vi': 'Ăn uống'},
      'created_at': DateTime.now().toIso8601String(),
    });

    AppLanguage.instance.setLocale(AppLocale.vietnamese);
    expect(parsed.localizedTitle, contains('Ăn uống'));
    AppLanguage.instance.setLocale(AppLocale.english);
    expect(parsed.localizedTitle, contains('Food'));
  });
}
