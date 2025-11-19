import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      _user = _supabase.auth.currentUser;
      _loading = false;
      notifyListeners();

      // Listen for auth changes
      _supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.signedIn) {
          _user = session?.user;
          if (_user != null) {
            _ensureProfileExists(_user!.id);
          }
        } else if (event == AuthChangeEvent.signedOut) {
          _user = null;
        }
        notifyListeners();
      });
    } catch (e) {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureProfileExists(String userId) async {
    try {
      // Non-blocking profile creation - don't wait for completion
      _supabase.from('profiles').insert({
        'id': userId,
        'username': _user?.email?.split('@')[0] ?? 'user_${userId.substring(0, 8)}',
        'display_name': _user?.userMetadata?['display_name'] ?? 
                       _user?.email?.split('@')[0] ?? 
                       'User',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single().then((_) {
        debugPrint('Profile created for $userId');
      }).catchError((e) {
        // Ignore errors - profile likely already exists
        debugPrint('Profile creation (non-blocking) for $userId: $e');
      });
    } catch (e) {
      // Silently fail - profile might be created by trigger or already exists
      debugPrint('Profile creation error (non-blocking): $e');
    }
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _user = response.user;
      if (_user != null) {
        await _ensureProfileExists(_user!.id);
      }
      notifyListeners();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      _user = response.user;
      if (_user != null) {
        await _ensureProfileExists(_user!.id);
      }
      notifyListeners();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    return await _supabase.auth.signInWithOAuth(provider);
  }
}

