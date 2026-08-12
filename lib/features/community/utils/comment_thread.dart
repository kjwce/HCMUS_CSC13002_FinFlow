import '../models/community_comment_model.dart';

class CommunityCommentThreadEntry {
  const CommunityCommentThreadEntry({
    required this.comment,
    required this.depth,
    required this.directReplyCount,
  });

  final CommunityCommentModel comment;
  final int depth;
  final int directReplyCount;
}

/// Flattens the expanded portion of a comment tree without recursion, so an
/// arbitrarily deep reply chain cannot overflow the Dart call stack.
List<CommunityCommentThreadEntry> buildVisibleCommentThread({
  required List<CommunityCommentModel> comments,
  required int visibleRootCount,
  required Set<String> expandedCommentIds,
}) {
  final commentIds = comments.map((comment) => comment.id).toSet();
  final childrenByParent = <String, List<CommunityCommentModel>>{};
  final roots = <CommunityCommentModel>[];

  for (final comment in comments) {
    final parentId = comment.parentCommentId;
    if (parentId == null || !commentIds.contains(parentId)) {
      roots.add(comment);
    } else {
      childrenByParent.putIfAbsent(parentId, () => []).add(comment);
    }
  }

  final firstRootIndex = roots.length > visibleRootCount
      ? roots.length - visibleRootCount
      : 0;
  final visibleRoots = roots.skip(firstRootIndex).toList();
  final stack = <_PendingComment>[
    for (final root in visibleRoots.reversed)
      _PendingComment(comment: root, depth: 0),
  ];
  final result = <CommunityCommentThreadEntry>[];
  final visited = <String>{};

  while (stack.isNotEmpty) {
    final pending = stack.removeLast();
    if (!visited.add(pending.comment.id)) continue;

    final children =
        childrenByParent[pending.comment.id] ?? const <CommunityCommentModel>[];
    result.add(
      CommunityCommentThreadEntry(
        comment: pending.comment,
        depth: pending.depth,
        directReplyCount: children.length,
      ),
    );

    if (expandedCommentIds.contains(pending.comment.id)) {
      for (final child in children.reversed) {
        stack.add(_PendingComment(comment: child, depth: pending.depth + 1));
      }
    }
  }
  return result;
}

class _PendingComment {
  const _PendingComment({required this.comment, required this.depth});

  final CommunityCommentModel comment;
  final int depth;
}
