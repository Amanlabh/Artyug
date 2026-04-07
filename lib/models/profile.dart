class ProfileModel {
  final String id;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? profilePictureUrl;
  final String? coverImageUrl;
  final String? artistType; // 'painter', 'sculptor', 'digital', etc.
  final bool isVerified;
  final bool isPremium;
  final int followersCount;
  final int followingCount;
  final int artworksCount;
  final String? location;
  final String? website;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    this.username,
    this.displayName,
    this.bio,
    this.profilePictureUrl,
    this.coverImageUrl,
    this.artistType,
    this.isVerified = false,
    this.isPremium = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.artworksCount = 0,
    this.location,
    this.website,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      artistType: json['artist_type'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      artworksCount: (json['artworks_count'] as num?)?.toInt() ?? 0,
      location: json['location'] as String?,
      website: json['website'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get displayNameOrUsername =>
      (displayName?.isNotEmpty == true ? displayName : username) ?? 'Artist';

  String get initials {
    final name = displayNameOrUsername;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
