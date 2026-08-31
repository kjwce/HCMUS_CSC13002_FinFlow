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
  bool _initialized = false;

  /// In-memory fallback for selectedCategory when the DB column doesn't exist yet.
  /// Gets priority over [_currentUser.selectedCategory].
  String? _selectedCategoryOverride;
  int? _dailyBudgetOverride;
  int? _weeklyBudgetOverride;

  UserModel? get currentUser => _currentUser;

  /// True when Supabase restored a persisted session for this installation.
  bool get hasActiveSession =>
      _initialized && Supabase.instance.client.auth.currentSession != null;

  /// Effective selected category: local override wins, then DB value.
  String? get selectedCategory =>
      _selectedCategoryOverride ?? _currentUser?.selectedCategory;

  int get dailyBudget => _dailyBudgetOverride ?? _currentUser?.dailyBudget ?? 0;

  int get weeklyBudget =>
      _weeklyBudgetOverride ?? _currentUser?.weeklyBudget ?? 0;

  /// Initialize Supabase and start listening for auth state changes.
  /// Safe to call multiple times — subsequent calls are a no-op.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(
        url: SupabaseConstants.url,
        publishableKey: SupabaseConstants.anonKey,
      );
      _initialized = true;
    } catch (_) {
      // Allow a later retry instead of leaving AuthService permanently in a
      // partially initialized state.
      _initialized = false;
      rethrow;
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) async {
      final session = authState.session;
      if (session != null) {
        // Session is present. For email sign-in the profile was already
        // fetched synchronously, but for OAuth (Google) the session arrives
        // asynchronously via a deep-link callback, so fetch the profile the
        // first time the session becomes available — and only then notify
        // listeners, so anything waiting on currentUser fires at the right
        // time.
        final needsProfileFetch = _currentUser?.id != session.user.id;
        if (needsProfileFetch) {
          try {
            await _fetchCurrentUserProfile();
          } catch (_) {}
          notifyListeners();
        }
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });

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

  Future<bool> signIn({required String email, required String password}) async {
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
      debugPrint(
        'AuthService: signUp response user=${response.user?.id}, '
        'session=${response.session != null}',
      );
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

  Future<bool> verifyOtp({required String email, required String token}) async {
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

  /// Verifies the OTP issued by Supabase's password-recovery flow.
  /// This intentionally remains separate from the regular email OTP method.
  Future<bool> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token,
        type: OtpType.recovery,
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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) throw Exception('No authenticated user');
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await updatePassword(newPassword: newPassword);
  }

  Future<void> deleteAccount() async {
    final response = await Supabase.instance.client.functions.invoke(
      'delete-account',
      body: const <String, dynamic>{},
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Account deletion failed (${response.status})');
    }

    _currentUser = null;
    _selectedCategoryOverride = null;
    _dailyBudgetOverride = null;
    _weeklyBudgetOverride = null;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  /// Whether the current user still needs to set their budget limit.
  bool get needsBudgetSetup {
    final u = _currentUser;
    return u != null && u.budgetLimit <= 0;
  }

  /// Upload avatar file and return the public URL.
  Future<String> uploadAvatar(File file) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user');

    final ext = file.path.split('.').last;
    final path = 'avatars/$userId.$ext';

    await Supabase.instance.client.storage
        .from('avatars')
        .upload(path, file, fileOptions: FileOptions(upsert: true));

    final url = Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(path);
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> updateProfile({
    required String fullName,
    String? email,
    String? phone,
    int? budgetLimit,
    String? avatarUrl,
    String? selectedCategory,
    int? dailyBudget,
    int? weeklyBudget,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user');
    if (selectedCategory != null) {
      _selectedCategoryOverride = selectedCategory;
    }
    if (dailyBudget != null) {
      _dailyBudgetOverride = dailyBudget;
    }
    if (weeklyBudget != null) {
      _weeklyBudgetOverride = weeklyBudget;
    }

    // 1. Update public.profiles — ensure non-nullable fields are always sent
    final currentEmail =
        _currentUser?.email ?? Supabase.instance.client.auth.currentUser?.email;
    await Supabase.instance.client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'email': email ?? currentEmail,
      'phone': ?phone,
      'budget_limit': ?budgetLimit,
      'avatar_url': ?avatarUrl,
    });

    if (selectedCategory != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'selected_category': selectedCategory})
            .eq('id', userId);
      } catch (e) {
        debugPrint(
          'updateProfile: column selected_category not available yet: $e',
        );
      }
    }

    if (dailyBudget != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'daily_budget': dailyBudget})
            .eq('id', userId);
      } catch (e) {
        debugPrint('updateProfile: column daily_budget not available yet: $e');
      }
    }

    if (weeklyBudget != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'weekly_budget': weeklyBudget})
            .eq('id', userId);
      } catch (e) {
        debugPrint('updateProfile: column weekly_budget not available yet: $e');
      }
    }

    // 2. Also update user_metadata in auth.users
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'full_name': fullName}),
    );

    try {
      await _fetchCurrentUserProfile();
    } catch (e) {
      debugPrint('updateProfile: profile refresh failed: $e');
    }
    notifyListeners();
  }

  /// Persist the user's chosen dynamic category in the goal summary card.
  Future<void> saveSelectedCategory(String category) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user');

    _selectedCategoryOverride = category;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'selected_category': category})
          .eq('id', userId);
      await _fetchCurrentUserProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('saveSelectedCategory: column not available yet: $e');
      notifyListeners();
    }
  }

  /// Sign out and immediately clear local state so the UI never reads stale data.
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
    await Supabase.instance.client.auth.signOut();
  }

  Future<bool> signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
      // On Android this method returns as soon as the external browser is
      // opened — the auth callback (via deep link) arrives later and syncs
      // the session via Supabase's onAuthStateChange listener. On iOS the
      // callback is completed synchronously, so the session is already set
      // here.
      final sessionReady = Supabase.instance.client.auth.currentSession != null;
      if (sessionReady) {
        await _fetchCurrentUserProfile();
        notifyListeners();
      }
      return _currentUser != null;
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
      return _currentUser != null;
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
      return _currentUser != null;
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
