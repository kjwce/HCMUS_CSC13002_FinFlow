import 'package:finflow/features/admin/models/admin_member_model.dart';
import 'package:finflow/features/admin/models/admin_post_model.dart';
import 'package:finflow/features/admin/models/admin_report_model.dart';
import 'package:finflow/features/auth/models/user_model.dart';
import 'package:finflow/features/chatbot/models/chat_model.dart';
import 'package:finflow/features/community/models/community_comment_model.dart';
import 'package:finflow/features/community/models/community_post_model.dart';
import 'package:finflow/features/finance/models/goal_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const storedTimestamp = '2026-09-03T18:25:00.000Z';
  final expectedLocal = DateTime.parse(storedTimestamp).toLocal();

  void expectLocal(DateTime actual) {
    expect(actual, expectedLocal);
    expect(actual.isUtc, isFalse);
  }

  void expectUtcJson(Object? actual) {
    expect(actual, isA<String>());
    final value = actual! as String;
    expect(value.endsWith('Z'), isTrue);
    expect(DateTime.parse(value), expectedLocal.toUtc());
  }

  test('community timestamps read as local and write as UTC', () {
    final post = CommunityPostModel.fromJson({
      'id': 'post-1',
      'user_id': 'user-1',
      'content': 'Post',
      'created_at': storedTimestamp,
    });
    final comment = CommunityCommentModel.fromJson({
      'id': 'comment-1',
      'post_id': 'post-1',
      'user_id': 'user-1',
      'content': 'Comment',
      'created_at': storedTimestamp,
    });

    expectLocal(post.createdAt);
    expectLocal(comment.createdAt);
    expectUtcJson(post.toJson()['created_at']);
    expectUtcJson(comment.toJson()['created_at']);
  });

  test('chat timestamps read as local and write as UTC', () {
    final message = ChatModel.fromJson({
      'id': 'message-1',
      'message': 'Hello',
      'role': 'user',
      'created_at': storedTimestamp,
    });
    final conversation = ChatConversation.fromJson({
      'id': 'conversation-1',
      'title': 'Chat',
      'created_at': storedTimestamp,
      'updated_at': storedTimestamp,
    });

    expectLocal(message.createdAt);
    expectLocal(conversation.createdAt);
    expectLocal(conversation.updatedAt);
    expectUtcJson(message.toJson()['created_at']);
  });

  test('profile and goal timestamps use local reads and UTC writes', () {
    final user = UserModel.fromJson({
      'id': 'user-1',
      'full_name': 'FinFlow User',
      'email': 'user@example.com',
      'created_at': storedTimestamp,
    });
    final goal = GoalModel.fromJson({
      'id': 'goal-1',
      'user_id': 'user-1',
      'name': 'Emergency fund',
      'target_amount': 1000000,
      'created_at': storedTimestamp,
      'target_date': '2026-09-03',
    });

    expectLocal(user.createdAt);
    expectLocal(goal.createdAt);
    expectUtcJson(user.toJson()['created_at']);
    expectUtcJson(goal.toJson()['created_at']);
    expect(goal.targetDate, DateTime(2026, 9, 3));
    expect(goal.toJson()['target_date'], '2026-09-03');
  });

  test('admin audit timestamps are converted to device local time', () {
    final post = AdminPostModel.fromJson({
      'id': 'post-1',
      'user_id': 'user-1',
      'content': 'Post',
      'created_at': storedTimestamp,
      'reviewed_at': storedTimestamp,
      'removed_at': storedTimestamp,
      'moderation_status': 'removed',
    });
    final report = AdminReportModel.fromJson({
      'id': 'report-1',
      'post_id': 'post-1',
      'reporter_id': 'user-2',
      'reason': 'spam',
      'created_at': storedTimestamp,
    });
    final member = AdminMemberModel.fromJson({
      'id': 'user-1',
      'full_name': 'Member',
      'email': 'member@example.com',
      'created_at': storedTimestamp,
      'community_muted_at': storedTimestamp,
    });

    expectLocal(post.createdAt);
    expectLocal(post.reviewedAt!);
    expectLocal(post.removedAt!);
    expectLocal(report.createdAt);
    expectLocal(member.createdAt);
    expectLocal(member.mutedAt!);
  });
}
