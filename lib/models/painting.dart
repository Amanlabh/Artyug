import '../core/utils/supabase_media_url.dart';

// Model for paintings table
class PaintingModel {
  final String id;
  final String artistId;
  final String title;
  final String? description;
  final String? medium;
  final String? dimensions;
  final String imageUrl;
  final List<String>? additionalImages;
  final double? price;
  final bool isForSale;
  final bool isSold;
  final List<String>? styleTags;
  final String? category;
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final DateTime? createdAt;

  // Joined from profiles
  final String? artistDisplayName;
  final String? artistProfilePictureUrl;
  final bool? artistIsVerified;
  final String? artistType;

  // Aggregated
  final int likesCount;
  final bool isLikedByMe;

  const PaintingModel({
    required this.id,
    required this.artistId,
    required this.title,
    this.description,
    this.medium,
    this.dimensions,
    required this.imageUrl,
    this.additionalImages,
    this.price,
    this.isForSale = false,
    this.isSold = false,
    this.styleTags,
    this.category,
    this.isBoosted = false,
    this.boostExpiresAt,
    this.createdAt,
    this.artistDisplayName,
    this.artistProfilePictureUrl,
    this.artistIsVerified,
    this.artistType,
    this.likesCount = 0,
    this.isLikedByMe = false,
  });

  factory PaintingModel.fromJson(Map<String, dynamic> json) {
    return PaintingModel(
      id: json['id'] as String,
      artistId: json['artist_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      medium: json['medium'] as String?,
      dimensions: json['dimensions'] as String?,
      imageUrl: (json['image_url'] as String?)?.trim() ?? '',
      additionalImages: (json['additional_images'] as List<dynamic>?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      isForSale: json['is_for_sale'] as bool? ?? false,
      isSold: json['is_sold'] as bool? ?? false,
      styleTags: (json['style_tags'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      category: json['category'] as String?,
      isBoosted: json['is_boosted'] as bool? ?? false,
      boostExpiresAt: json['boost_expires_at'] != null
          ? DateTime.tryParse(json['boost_expires_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      // Joined profile fields
      artistDisplayName: json['display_name'] as String? ??
          json['artist_display_name'] as String?,
      artistProfilePictureUrl: json['profile_picture_url'] as String? ??
          json['artist_profile_picture_url'] as String?,
      artistIsVerified: json['is_verified'] as bool?,
      artistType: json['artist_type'] as String?,
      // Aggregates
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['is_liked'] as bool? ?? false,
    );
  }

  String get displayPrice => price != null
      ? '₹${price!.toStringAsFixed(0)}'
      : 'Price on request';

  bool get isAvailable => isForSale && !isSold;

  /// Resolved CDN URL for the primary artwork image (fixes stale Supabase
  /// hosts, bare storage paths, and falls back to [additionalImages]).
  String get resolvedImageUrl {
    final primary = SupabaseMediaUrl.resolve(imageUrl);
    if (primary.isNotEmpty) return primary;
    final extras = additionalImages;
    if (extras == null) return '';
    for (final u in extras) {
      final r = SupabaseMediaUrl.resolve(u);
      if (r.isNotEmpty) return r;
    }
    return '';
  }

  String? get resolvedArtistAvatarUrl {
    final u = artistProfilePictureUrl?.trim();
    if (u == null || u.isEmpty) return null;
    return SupabaseMediaUrl.resolve(u);
  }
}
