import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Normalizes image URLs from Supabase Storage and legacy rows so network
/// image widgets load reliably (web + mobile).
class SupabaseMediaUrl {
  SupabaseMediaUrl._();

  static final _uuidPath = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/',
  );

  /// Public URL for display. Handles:
  /// - Full https URLs (re-aligns host to current [AppConfig.supabaseUrl] when
  ///   the path is Supabase storage but the project ref in the host is stale)
  /// - Bare storage object paths for `paintings`, `profiles`, `post-images`
  static String resolve(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return '';

    if (s.startsWith('http://') || s.startsWith('https://')) {
      return _realignSupabaseStorageHost(s);
    }

    final client = Supabase.instance.client;

    if (s.startsWith('avatars/')) {
      return client.storage.from('profiles').getPublicUrl(s);
    }

    if (s.contains('/post-images/')) {
      return client.storage.from('post-images').getPublicUrl(s);
    }

    if (_uuidPath.hasMatch(s)) {
      return client.storage.from('paintings').getPublicUrl(s);
    }

    return s;
  }

  static String _realignSupabaseStorageHost(String url) {
    final configured = AppConfig.supabaseUrl.trim();
    if (configured.isEmpty) return url;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;

    final configuredUri = Uri.tryParse(configured);
    if (configuredUri == null || !configuredUri.hasScheme) return url;

    final path = uri.path;
    if (!path.contains('/storage/v1/object/public/')) return url;
    if (!uri.host.endsWith('supabase.co')) return url;

    if (uri.host == configuredUri.host) return url;

    return uri
        .replace(
          scheme: configuredUri.scheme,
          host: configuredUri.host,
          port: configuredUri.hasPort ? configuredUri.port : null,
        )
        .toString();
  }
}
