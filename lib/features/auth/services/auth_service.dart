import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../models/user_model.dart';

/// Singleton service that wraps all Supabase auth operations.
/// Also listens for auth state changes and notifies listeners.
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  UserModel? _currentUser;
  StreamSubscription<dynamic>? _authSubscription;

  UserModel? get currentUser => _currentUser;

  /// Initialize Supabase and start listening for auth state changes.
  Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      publishableKey: SupabaseConstants.anonKey,
    );

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (authState) async {
        if (authState.session != null) {
          try {
            await _fetchCurrentUserProfile();
          } catch (_) {
            debugPrint('Auth changed but profile fetch failed');
          }
        } else {
          _currentUser = null;
        }
        notifyListeners();
      },
    );

    // Handle existing session (app restored from background)
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        await _fetchCurrentUserProfile();
      } catch (_) {
        debugPrint('Existing session but profile fetch failed');
      }
    }
    notifyListeners();
  }

  Future<void> _fetchCurrentUserProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _currentUser = null;
      return;
    }
    final res = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (res != null) {
      _currentUser = UserModel.fromJson(res);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (response.user == null) return false;
      await _fetchCurrentUserProfile();
      notifyListeners();
      return true;
    } on AuthException {
      return false;
    }
  }

  Future<void> sendOtpForSignUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('AuthService: Calling signUp for $email');
      final response = await Supabase.instance.client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim().isEmpty
              ? 'New FinFlow User'
              : fullName.trim(),
        },
      );
      debugPrint('AuthService: signUp response user=${response.user?.id}, session=${response.session != null}');
    } on AuthException catch (e) {
      debugPrint('AuthService: signUp AuthException: ${e.message}');
      throw ArgumentError(e.message);
    } catch (e) {
      debugPrint('AuthService: signUp error: $e');
      rethrow;
    }
  }

  Future<void> sendOtp({required String email}) async {
    await Supabase.instance.client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
    );
  }

  Future<bool> completeRegistration({
    required String email,
    required String token,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token,
        type: OtpType.signup,
      );
      if (response.user == null) return false;

      // Password was already set in signUp().
      // Profile is auto-created by the handle_new_user DB trigger.
      await _fetchCurrentUserProfile();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token,
        type: OtpType.email,
      );
      return response.user != null;
    } on AuthException {
      return false;
    }
  }

  Future<void> resetPassword({required String email}) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
    );
  }

  Future<void> updatePassword({required String newPassword}) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Whether the current user still needs to set their budget limit.
  bool get needsBudgetSetup {
    final u = _currentUser;
    return u == null || u.budgetLimit <= 0;
  }

  /// Upload avatar file and return the public URL.
  Future<String> uploadAvatar(File file) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user');

    final ext = file.path.split('.').last;
    final path = 'avatars/$userId.$ext';

    await Supabase.instance.client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: FileOptions(upsert: true),
        );

    final url = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> updateProfile({
    required String fullName,
    String? email,
    String? phone,
    int? budgetLimit,
    String? avatarUrl,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user');

    // 1. Update public.profiles — ensure non-nullable fields are always sent
    final currentEmail = _currentUser?.email ?? Supabase.instance.client.auth.currentUser?.email;
    await Supabase.instance.client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'email': email ?? currentEmail,
      if (phone != null) 'phone': phone,
      if (budgetLimit != null) 'budget_limit': budgetLimit,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });

    // 2. Also update user_metadata in auth.users so Supabase Auth reflects the new name
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {'full_name': fullName},
        // Note: phone is NOT passed here — it lives only in public.profiles.
        // Passing phone to updateUser() triggers SMS verification which
        // requires an SMS provider configured in Supabase.
      ),
    );

    await _fetchCurrentUserProfile();
    notifyListeners();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<bool> signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
      await _fetchCurrentUserProfile();
      notifyListeners();
      return true;
    } on AuthException {
      return false;
    }
  }

  Future<bool> signInWithFacebook() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
      await _fetchCurrentUserProfile();
      notifyListeners();
      return true;
    } on AuthException {
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
      await _fetchCurrentUserProfile();
      notifyListeners();
      return true;
    } on AuthException {
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
