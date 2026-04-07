import 'package:supabase_flutter/supabase_flutter.dart';

/// Single getter for the Supabase client.
/// Use `SupabaseClient.db` everywhere instead of `Supabase.instance.client`.
class SupabaseClientHelper {
  SupabaseClientHelper._();

  static SupabaseClient get db => Supabase.instance.client;

  static GoTrueClient get auth => db.auth;

  static User? get currentUser => auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static bool get isAuthenticated => currentUser != null;

  static SupabaseStorageClient get storage => db.storage;
}
