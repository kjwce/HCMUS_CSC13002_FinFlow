import 'package:finflow/features/community/utils/community_topics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feed topics contain All followed by every composer topic', () {
    expect(communityFeedTopics.first, 'All');
    expect(communityFeedTopics.skip(1), communityTopics);
    expect(communityFeedTopics.toSet().length, communityFeedTopics.length);
  });
}
