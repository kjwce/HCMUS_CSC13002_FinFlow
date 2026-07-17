import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

/// Expose the AuthService singleton as a ChangeNotifier provider.
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService.instance;
});
