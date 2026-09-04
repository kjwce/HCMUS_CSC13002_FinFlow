import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/community_service.dart';

/// Expose the CommunityService singleton and rebuild listeners when its
/// in-memory feed changes.
final communityServiceProvider = ChangeNotifierProvider<CommunityService>((
  ref,
) {
  return CommunityService.instance;
});
