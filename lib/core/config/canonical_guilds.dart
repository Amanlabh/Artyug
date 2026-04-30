import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_media_url.dart';

/// The product surface shows exactly three official guilds: Artyug, Motojojo,
/// Webcoin Labs. Matching is fuzzy on [communities.name] so existing DB rows
/// still work without a dedicated slug column.
class CanonicalGuilds {
  CanonicalGuilds._();

  static bool matchesOfficialName(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final n = name.toLowerCase();
    return n.contains('artyug') ||
        n.contains('motojojo') ||
        n.contains('webcoin');
  }

  /// Order: Artyug → Motojojo → Webcoin Labs.
  static int sortKey(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('artyug')) return 0;
    if (n.contains('motojojo')) return 1;
    if (n.contains('webcoin')) return 2;
    return 99;
  }

  static List<T> filterAndSort<T>(Iterable<T> items, String? Function(T) nameOf) {
    final list = items.where((e) => matchesOfficialName(nameOf(e))).toList();
    list.sort((a, b) => sortKey(nameOf(a)).compareTo(sortKey(nameOf(b))));
    return list;
  }

  static String? officialAssetForName(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('artyug')) return 'assets/guilds/artyug.png';
    if (n.contains('motojojo')) return 'assets/guilds/motojojo.png';
    if (n.contains('webcoin')) return 'assets/guilds/webcoinlabs.jpg';
    return null;
  }

  static String preferredImageForCommunityRow(Map<String, dynamic> row) {
    final avatar = SupabaseMediaUrl.resolve(row['avatar_url'] as String?);
    if (avatar.isNotEmpty) return avatar;
    final cover = SupabaseMediaUrl.resolve(row['cover_image_url'] as String?);
    if (cover.isNotEmpty) return cover;
    return officialAssetForName(row['name'] as String?) ?? '';
  }

  /// Fetches all communities from Supabase and returns only the three official guilds.
  static Future<List<Map<String, dynamic>>> fetchOfficialCommunities(
    SupabaseClient client,
  ) async {
    final res = await client.from('communities').select('*').order('created_at');
    final rows = List<Map<String, dynamic>>.from(res as List);
    final filtered = filterAndSort(rows, (m) => m['name'] as String?);
    return filtered;
  }
}
