import '../core/config/supabase_client.dart';
import '../models/painting.dart';

class PaintingRepository {
  static final _client = SupabaseClientHelper.db;

  /// Main feed — artworks with profile join + like count + isLikedByMe
  static Future<List<PaintingModel>> fetchFeed({
    int page = 0,
    int pageSize = 20,
  }) async {
    final userId = SupabaseClientHelper.currentUserId;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final data = await _client
        .from('paintings')
        .select('''
          *,
          profiles!paintings_artist_id_fkey(
            id, display_name, username, profile_picture_url, is_verified, artist_type
          )
        ''')
        .order('is_boosted', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);

    if (data.isEmpty) return [];

    final paintings = (data as List).map((item) {
      final profile = item['profiles'] as Map<String, dynamic>?;
      return PaintingModel.fromJson({
        ...item,
        'display_name': profile?['display_name'],
        'profile_picture_url': profile?['profile_picture_url'],
        'is_verified': profile?['is_verified'],
        'artist_type': profile?['artist_type'],
      });
    }).toList();

    // Fetch like counts + isLiked in batch
    if (userId != null) {
      final paintingIds = paintings.map((p) => p.id).toList();
      final likes = await _client
          .from('painting_likes')
          .select('painting_id, user_id')
          .inFilter('painting_id', paintingIds);

      final likeMap = <String, int>{};
      final likedSet = <String>{};
      for (final l in (likes as List)) {
        final pid = l['painting_id'] as String;
        likeMap[pid] = (likeMap[pid] ?? 0) + 1;
        if (l['user_id'] == userId) likedSet.add(pid);
      }

      return paintings.map((p) {
        return PaintingModel.fromJson({
          'id': p.id,
          'artist_id': p.artistId,
          'title': p.title,
          'description': p.description,
          'medium': p.medium,
          'dimensions': p.dimensions,
          'image_url': p.imageUrl,
          'additional_images': p.additionalImages,
          'price': p.price,
          'is_for_sale': p.isForSale,
          'is_sold': p.isSold,
          'style_tags': p.styleTags,
          'category': p.category,
          'is_boosted': p.isBoosted,
          'boost_expires_at': p.boostExpiresAt?.toIso8601String(),
          'created_at': p.createdAt?.toIso8601String(),
          'display_name': p.artistDisplayName,
          'profile_picture_url': p.artistProfilePictureUrl,
          'is_verified': p.artistIsVerified,
          'artist_type': p.artistType,
          'likes_count': likeMap[p.id] ?? 0,
          'is_liked': likedSet.contains(p.id),
        });
      }).toList();
    }

    return paintings;
  }

  /// Artworks for a specific artist
  static Future<List<PaintingModel>> fetchByArtist(String artistId) async {
    final data = await _client
        .from('paintings')
        .select('*')
        .eq('artist_id', artistId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PaintingModel.fromJson(e)).toList();
  }

  /// Single painting by ID
  static Future<PaintingModel?> fetchById(String id) async {
    final data = await _client
        .from('paintings')
        .select('''
          *,
          profiles!paintings_artist_id_fkey(
            id, display_name, username, profile_picture_url, is_verified, artist_type
          )
        ''')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    final profile = data['profiles'] as Map<String, dynamic>?;
    return PaintingModel.fromJson({
      ...data,
      'display_name': profile?['display_name'],
      'profile_picture_url': profile?['profile_picture_url'],
      'is_verified': profile?['is_verified'],
    });
  }

  /// Toggle like — returns new like state
  static Future<bool> toggleLike(String paintingId) async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final existing = await _client
        .from('painting_likes')
        .select('id')
        .eq('painting_id', paintingId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('painting_likes')
          .delete()
          .eq('painting_id', paintingId)
          .eq('user_id', userId);
      return false;
    } else {
      await _client.from('painting_likes').insert({
        'painting_id': paintingId,
        'user_id': userId,
      });
      return true;
    }
  }

  /// Search paintings by title or style tags
  static Future<List<PaintingModel>> search(String query) async {
    final data = await _client
        .from('paintings')
        .select('''
          *,
          profiles!paintings_artist_id_fkey(
            display_name, profile_picture_url, is_verified
          )
        ''')
        .ilike('title', '%$query%')
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List).map((item) {
      final profile = item['profiles'] as Map<String, dynamic>?;
      return PaintingModel.fromJson({
        ...item,
        'display_name': profile?['display_name'],
        'profile_picture_url': profile?['profile_picture_url'],
        'is_verified': profile?['is_verified'],
      });
    }).toList();
  }

  /// Alias used by ArtworkDetailScreen — full detail with likes for current user
  static Future<PaintingModel?> getPaintingDetail(String id) async {
    final userId = SupabaseClientHelper.currentUserId;
    final painting = await fetchById(id);
    if (painting == null) return null;

    // Fetch like count + isLikedByMe for this single painting
    final likes = await _client
        .from('painting_likes')
        .select('user_id')
        .eq('painting_id', id);

    final likeList = likes as List;
    final likesCount = likeList.length;
    final isLiked =
        userId != null && likeList.any((l) => l['user_id'] == userId);

    return PaintingModel.fromJson({
      'id': painting.id,
      'artist_id': painting.artistId,
      'title': painting.title,
      'description': painting.description,
      'medium': painting.medium,
      'dimensions': painting.dimensions,
      'image_url': painting.imageUrl,
      'additional_images': painting.additionalImages,
      'price': painting.price,
      'is_for_sale': painting.isForSale,
      'is_sold': painting.isSold,
      'style_tags': painting.styleTags,
      'category': painting.category,
      'is_boosted': painting.isBoosted,
      'boost_expires_at': painting.boostExpiresAt?.toIso8601String(),
      'created_at': painting.createdAt?.toIso8601String(),
      'display_name': painting.artistDisplayName,
      'profile_picture_url': painting.artistProfilePictureUrl,
      'is_verified': painting.artistIsVerified,
      'artist_type': painting.artistType,
      'likes_count': likesCount,
      'is_liked': isLiked,
    });
  }
}

