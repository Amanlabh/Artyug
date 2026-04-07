import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/auth/oauth_url.dart';
import '../services/notifications/notification_service.dart';

/// Session is considered expired if the user hasn't been active for this long.
const _kSessionTimeoutDuration = Duration(hours: 8);
const _kLastActiveKey = 'artyug_last_active_ms';

String _termsPrefsKey(String userId) => 'artyug_terms_accepted_v1_$userId';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _user;
  bool _loading = true;

  /// Mirrors `profiles.onboarding_complete` for the signed-in user.
  bool _onboardingComplete = false;

  /// Per-user: explicit `true` in SharedPreferences only after Terms screen.
  bool _termsAccepted = false;

  User? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;
  bool get onboardingComplete => _onboardingComplete;
  bool get termsAccepted => _termsAccepted;

  AuthProvider() {
    _initAuth();
  }

  // ── Initialisation ───────────────────────────────────────────────────────────

  Future<void> _initAuth() async {
    try {
      final sessionUser = _supabase.auth.currentUser;
      final session = _supabase.auth.currentSession;

      if (sessionUser != null && session != null) {
        // Check custom session timeout (independent of Supabase JWT expiry)
        final expired = await _isSessionTimedOut();
        if (expired) {
          debugPrint('[Auth] Session timed out — signing out.');
          await _supabase.auth.signOut();
          _user = null;
          _onboardingComplete = false;
        } else {
          _user = sessionUser;
          await _touchLastActive();
          await refreshOnboardingStatus();
          await loadTermsAcceptance();
        }
      }

      _loading = false;
      notifyListeners();

      // Listen for Supabase auth state changes (sign-in, sign-out, token refresh)
      _supabase.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        final session = data.session;

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated) {
          _user = session?.user;
          if (_user != null) {
            await _ensureProfileExists(_user!.id);
            await _touchLastActive();
            NotificationService.instance.subscribeForUser(_user!.id);
            await refreshOnboardingStatus();
            await loadTermsAcceptance();
          }
        } else if (event == AuthChangeEvent.signedOut) {
          NotificationService.instance.unsubscribe();
          _user = null;
          _onboardingComplete = false;
          _termsAccepted = false;
          await _clearLastActive();
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[Auth] initAuth error: $e');
      _loading = false;
      notifyListeners();
    }
  }

  // ── Session timeout helpers ──────────────────────────────────────────────────

  Future<bool> _isSessionTimedOut() async {
    try {
      // ── OAuth callback guard ─────────────────────────────────────────────
      // When Google (or any OAuth provider) redirects back, the URL contains
      // `?code=`. At that point, artyug_last_active_ms hasn't been recorded
      // yet (new session), so we must NOT time out or we'll kill the fresh session.
      if (kIsWeb && oauthBrowserUri().queryParameters.containsKey('code')) {
        debugPrint('[Auth] OAuth callback detected — skipping timeout check.');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastActiveMs = prefs.getInt(_kLastActiveKey);
      // If we have never recorded activity (e.g. first time with new session
      // tracking, or user cleared storage), treat the existing Supabase
      // browser session as expired and force a fresh login.
      if (lastActiveMs == null) return true;
      final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMs);
      final diff = DateTime.now().difference(lastActive);
      return diff > _kSessionTimeoutDuration;
    } catch (_) {
      return false;
    }
  }

  Future<void> _touchLastActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastActiveKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _clearLastActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLastActiveKey);
    } catch (_) {}
  }

  /// Call this when the user takes any meaningful action to refresh the timeout window.
  Future<void> refreshActivity() => _touchLastActive();

  // ── Profile bootstrap ────────────────────────────────────────────────────────

  /// Creates a minimal profile row only if one does not already exist.
  /// Does NOT set `role` (to avoid the DB check constraint); that is
  /// written by the onboarding wizard.
  Future<void> _ensureProfileExists(String userId) async {
    try {
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (existing != null) return; // Already exists — do nothing

      final meta = _user?.userMetadata;
      final emailPrefix = _user?.email?.split('@')[0] ?? 'user';
      await _supabase.from('profiles').insert({
        'id': userId,
        'username': '${emailPrefix}_${userId.substring(0, 6)}',
        'display_name': meta?['full_name'] as String? ??
            meta?['name'] as String? ??
            meta?['display_name'] as String? ??
            _user?.email?.split('@')[0] ??
            'User',
        // DO NOT set 'role' here — the DB check constraint only allows
        // 'creator', 'collector', or NULL. The onboarding screen sets it.
        'onboarding_complete': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[Auth] Profile bootstrap created for $userId');
    } catch (e) {
      debugPrint('[Auth] _ensureProfileExists $userId: $e');
    }
  }

  // ── Onboarding status ────────────────────────────────────────────────────────

  /// Loads [onboardingComplete] from `profiles` for the current session user.
  Future<void> refreshOnboardingStatus() async {
    final uid = _user?.id ?? _supabase.auth.currentUser?.id;
    if (uid == null) {
      _onboardingComplete = false;
      notifyListeners();
      return;
    }
    try {
      final row = await _supabase
          .from('profiles')
          .select('onboarding_complete')
          .eq('id', uid)
          .maybeSingle();
      final oc = row?['onboarding_complete'];
      _onboardingComplete =
          row != null && (oc == true || oc == 'true' || oc == 't');
    } catch (e) {
      final s = e.toString();
      if (s.contains('42703') && s.contains('onboarding_complete')) {
        debugPrint(
          '[Auth] profiles.onboarding_complete column missing — '
          'run: ALTER TABLE profiles ADD COLUMN onboarding_complete boolean NOT NULL DEFAULT false;',
        );
      } else {
        debugPrint('[Auth] refreshOnboardingStatus: $e');
      }
      _onboardingComplete = false;
    }
    notifyListeners();
  }

  // ── Terms & conditions (per user, local) ───────────────────────────────────

  Future<void> loadTermsAcceptance() async {
    final uid = _user?.id;
    if (uid == null) {
      _termsAccepted = false;
      notifyListeners();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _termsAccepted = prefs.getBool(_termsPrefsKey(uid)) == true;
    } catch (_) {
      _termsAccepted = false;
    }
    notifyListeners();
  }

  Future<void> acceptTermsAndConditions() async {
    final uid = _user?.id;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_termsPrefsKey(uid), true);
    _termsAccepted = true;
    notifyListeners();
  }

  // ── Auth actions ─────────────────────────────────────────────────────────────

  /// Signs in with email + password.
  /// THROWS on failure so the UI can show the error.
  /// Does NOT navigate — GoRouter's refreshListenable handles routing.
  Future<void> signInWithEmail(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password are required.');
    }
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) {
      throw Exception('Invalid credentials. Please try again.');
    }
    // _user + onboarding status are updated via onAuthStateChange listener
  }

  Future<void> signUpWithEmail(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );
    if (response.user == null && response.session == null) {
      throw Exception(
          'Check your email for a confirmation link before signing in.');
    }
    // Supabase may return a user with unconfirmed email — that is fine;
    // the onAuthStateChange will fire when they confirm.
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _clearLastActive();
    _user = null;
    _onboardingComplete = false;
    _termsAccepted = false;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Web: [AppConfig.oauthRedirectUrl] if set (must match Supabase Redirect URLs exactly),
  /// else [Uri.base.origin]. Mobile: must match deep link + Supabase redirect allow list.
  String get _oauthRedirectTo {
    if (kIsWeb) {
      final configured = AppConfig.oauthRedirectUrl?.trim();
      if (configured != null && configured.isNotEmpty) return configured;
      return Uri.base.origin;
    }
    return 'artyug://login-callback';
  }

  Future<bool> signInWithGoogle() async {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirectTo,
    );
  }

  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    return _supabase.auth.signInWithOAuth(
      provider,
      redirectTo: _oauthRedirectTo,
    );
  }
}
