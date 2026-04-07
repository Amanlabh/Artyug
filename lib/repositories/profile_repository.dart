import '../core/config/supabase_client.dart';
import '../models/profile.dart';

class ProfileRepository {
  static final _client = SupabaseClientHelper.db;

  static Future<ProfileModel?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  static Future<ProfileModel?> getMyProfile() async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) return null;
    return getProfile(userId);
  }

  static Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? location,
    String? website,
    String? profilePictureUrl,
    String? coverImageUrl,
    String? artistType,
  }) async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (username != null) updates['username'] = username;
    if (bio != null) updates['bio'] = bio;
    if (location != null) updates['location'] = location;
    if (website != null) updates['website'] = website;
    if (profilePictureUrl != null) {
      updates['profile_picture_url'] = profilePictureUrl;
    }
    if (coverImageUrl != null) updates['cover_image_url'] = coverImageUrl;
    if (artistType != null) updates['artist_type'] = artistType;

    await _client.from('profiles').update(updates).eq('id', userId);
  }

  /// Follow/unfollow a user — returns new following state
  static Future<bool> toggleFollow(String targetUserId) async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    if (userId == targetUserId) throw Exception('Cannot follow yourself');

    final existing = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('following_id', targetUserId);
      return false;
    } else {
      await _client.from('follows').insert({
        'follower_id': userId,
        'following_id': targetUserId,
      });
      return true;
    }
  }

  static Future<bool> isFollowing(String targetUserId) async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) return false;
    final data = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return data != null;
  }

  static Future<List<ProfileModel>> getFollowers(String userId) async {
    final data = await _client
        .from('follows')
        .select('profiles!follows_follower_id_fkey(*)')
        .eq('following_id', userId);
    return (data as List)
        .map((e) => ProfileModel.fromJson(e['profiles'] as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ProfileModel>> getFollowing(String userId) async {
    final data = await _client
        .from('follows')
        .select('profiles!follows_following_id_fkey(*)')
        .eq('follower_id', userId);
    return (data as List)
        .map((e) => ProfileModel.fromJson(e['profiles'] as Map<String, dynamic>))
        .toList();
  }
}
