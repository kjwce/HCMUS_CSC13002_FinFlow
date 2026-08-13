import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

/// Exposes the app-lifetime singleton without letting a temporary
/// [ProviderScope] dispose it. Invalidating the provider still rebuilds every
/// consumer whenever the service notifies listeners.
final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService.instance;
  void handleChange() => ref.invalidateSelf();
  service.addListener(handleChange);
  ref.onDispose(() => service.removeListener(handleChange));
  return service;
});
