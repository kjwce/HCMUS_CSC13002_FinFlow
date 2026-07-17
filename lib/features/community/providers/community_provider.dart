import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/community_service.dart';

/// Expose the CommunityService singleton as a Riverpod provider.
final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService.instance;
});
