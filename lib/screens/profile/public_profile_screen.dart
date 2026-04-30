import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../core/utils/supabase_media_url.dart';
import '../../repositories/painting_repository.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _paintings = [];
  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _suggestedProfiles = [];
  Map<String, dynamic>? _studio;
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  int _followersCount = 0;
  int _followingCount = 0;

  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final meId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    await Future.wait([
      _fetchProfile(),
      _fetchPaintings(),
      _fetchThreads(),
      _fetchFollowStats(),
      _fetchStudio(),
      _fetchSuggestedProfiles(meId),
    ]);
    if (meId != null && meId != widget.userId) {
      await _checkFollowStatus(meId);
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .single();
      if (mounted) {
        setState(() {
          _profile = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPaintings() async {
    try {
      final res = await _supabase
          .from('paintings')
          .select('id, title, image_url, price_inr, is_available')
          .eq('artist_id', widget.userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _paintings = List<Map<String, dynamic>>.from(res));
      }
    } catch (_) {}
  }

  Future<void> _fetchThreads() async {
    try {
      final res = await _supabase
          .from('paintings')
          .select(
              'id, title, description, image_url, medium, category, created_at, profiles:artist_id(display_name, username, profile_picture_url, is_verified)')
          .eq('artist_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(10);
      final rows = List<Map<String, dynamic>>.from(res);
      final currentUserId = _supabase.auth.currentUser?.id;
      if (rows.isNotEmpty) {
        final ids = rows.map((e) => e['id']?.toString()).whereType<String>().toList();
        final likes = await _supabase
            .from('painting_likes')
            .select('painting_id, user_id')
            .inFilter('painting_id', ids);
        final likeCounts = <String, int>{};
        final likedSet = <String>{};
        for (final row in (likes as List)) {
          final paintingId = row['painting_id']?.toString();
          if (paintingId == null || paintingId.isEmpty) continue;
          likeCounts[paintingId] = (likeCounts[paintingId] ?? 0) + 1;
          if (currentUserId != null && row['user_id'] == currentUserId) {
            likedSet.add(paintingId);
          }
        }
        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          row['likes_count'] = likeCounts[id] ?? 0;
          row['is_liked'] = likedSet.contains(id);
        }
      }
      if (mounted) {
        setState(() => _threads = rows);
      }
    } catch (_) {}
  }

  Future<void> _fetchSuggestedProfiles(String? meId) async {
    try {
      final rows = await _supabase
          .from('profiles')
          .select(
              'id, username, display_name, profile_picture_url, artist_type, is_verified, followers_count')
          .neq('id', widget.userId)
          .order('followers_count', ascending: false)
          .limit(12);
      final list = List<Map<String, dynamic>>.from(rows as List)
          .where((row) => row['id']?.toString().isNotEmpty == true)
          .where((row) => row['id']?.toString() != meId)
          .take(6)
          .toList();
      if (mounted) {
        setState(() => _suggestedProfiles = list);
      }
    } catch (_) {}
  }

  Future<void> _fetchFollowStats() async {
    try {
      final followers = await _supabase
          .from('follows')
          .select('id')
          .eq('following_id', widget.userId);
      final following = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', widget.userId);
      if (mounted) {
        setState(() {
          _followersCount = (followers as List).length;
          _followingCount = (following as List).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkFollowStatus(String myId) async {
    try {
      final res = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', myId)
          .eq('following_id', widget.userId)
          .maybeSingle();
      if (mounted) setState(() => _isFollowing = res != null);
    } catch (_) {}
  }

  Future<void> _fetchStudio() async {
    try {
      final row = await _supabase
          .from('shops')
          .select('id, name, slug, description, is_active')
          .eq('owner_id', widget.userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _studio = row == null ? null : Map<String, dynamic>.from(row));
    } catch (_) {}
  }

  Future<void> _handleFollow() async {
    final me = Provider.of<AuthProvider>(context, listen: false).user;
    if (me == null || me.id == widget.userId) return;
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', me.id)
            .eq('following_id', widget.userId);
        setState(() {
          _isFollowing = false;
          _followersCount--;
        });
      } else {
        await _supabase.from('follows').insert({
          'follower_id': me.id,
          'following_id': widget.userId,
        });
        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Provider.of<AuthProvider>(context).user;
    final isOwn = me?.id == widget.userId;

    final canvas = AppColors.canvasOf(context);
    final surface = AppColors.surfaceOf(context);
    final surfaceSoft = AppColors.surfaceSoftOf(context);
    final border = AppColors.borderOf(context);
    final borderStrong = AppColors.borderStrongOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textTertiary = AppColors.textTertiaryOf(context);
    final accent = AppColors.accentOf(context);
    final accentSoft = AppColors.accentSoftOf(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: canvas,
        body: Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(
          backgroundColor: canvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Profile not found',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final name = _profile!['display_name'] as String? ??
        _profile!['username'] as String? ??
        'Artist';
    final username = _profile!['username'] as String? ?? '';
    final bio = (_profile!['bio'] as String?)?.trim();
    final avatarUrl = _profile!['profile_picture_url'] as String?;
    final isVerified = _profile!['is_verified'] == true;
    final artistType =
        _friendlyArtistType(_profile!['artist_type'] as String? ?? 'Creator');
    final role = _profile!['role'] as String?;

    return Scaffold(
      backgroundColor: canvas,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: canvas,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textPrimary),
              onPressed: () => context.pop(),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                Text(
                  username.isEmpty ? name : '@$username',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified_rounded, size: 16, color: accent),
                ],
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: border.withValues(alpha: 0.7)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: border),
                      boxShadow: AppColors.cardShadows(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 720;
                            final stats = compact
                                ? Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _StatCard(value: '${_paintings.length}', label: 'Works'),
                                      _StatCard(value: '$_followersCount', label: 'Followers'),
                                      _StatCard(value: '$_followingCount', label: 'Following'),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: _StatCard(
                                          value: '${_paintings.length}',
                                          label: 'Works',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _StatCard(
                                          value: '$_followersCount',
                                          label: 'Followers',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _StatCard(
                                          value: '$_followingCount',
                                          label: 'Following',
                                        ),
                                      ),
                                    ],
                                  );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ProfileIdentityBlock(
                                    name: name,
                                    username: username,
                                    bio: bio,
                                    avatarUrl: avatarUrl,
                                    artistType: artistType,
                                    isVerified: isVerified,
                                  ),
                                  const SizedBox(height: 18),
                                  stats,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _ProfileIdentityBlock(
                                    name: name,
                                    username: username,
                                    bio: bio,
                                    avatarUrl: avatarUrl,
                                    artistType: artistType,
                                    isVerified: isVerified,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(flex: 6, child: stats),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        if (!isOwn)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _followLoading ? null : _handleFollow,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: _isFollowing ? accentSoft : accent,
                                    foregroundColor: _isFollowing ? textPrimary : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      side: _isFollowing
                                          ? BorderSide(color: borderStrong)
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: _followLoading
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _isFollowing ? accent : Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isFollowing ? 'Following' : 'Follow',
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.push('/chat/${widget.userId}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    side: BorderSide(color: borderStrong),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: const Text(
                                    'Message',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => context.push('/edit-profile'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                side: BorderSide(color: borderStrong),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text(
                                'Edit Profile',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (role == 'creator') ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceSoft,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: accentSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.storefront_rounded, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _studio?['name']?.toString() ?? '$name Studio',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Collections, drops, and featured works',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final slug = _studio?['slug']?.toString();
                              AnalyticsService.track('studio_enter_tap', params: {
                                'surface': 'public_profile',
                                'slug': slug ?? '',
                                'artist_id': widget.userId,
                              });
                              if (slug != null && slug.isNotEmpty) {
                                context.push('/shop/$slug');
                              } else {
                                context.push('/shop');
                              }
                            },
                            child: Text(
                              'View studio',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isOwn && _isFollowing && _suggestedProfiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SuggestedProfilesRail(profiles: _suggestedProfiles),
                  ],
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      labelColor: accent,
                      unselectedLabelColor: textTertiary,
                      indicatorColor: accent,
                      indicatorWeight: 3,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(text: 'Portfolio'),
                        Tab(text: 'Threads'),
                        Tab(text: 'About'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _GalleryTab(paintings: _paintings),
            _ThreadsTab(threads: _threads),
            _AboutTab(
              profile: _profile!,
              followersCount: _followersCount,
              followingCount: _followingCount,
              artworksCount: _paintings.length,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIdentityBlock extends StatelessWidget {
  final String name;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final String artistType;
  final bool isVerified;

  const _ProfileIdentityBlock({
    required this.name,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.artistType,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final accent = AppColors.accentOf(context);
    final accentSoft = AppColors.accentSoftOf(context);
    final border = AppColors.borderOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: accentSoft,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.cover,
                  ),
                )
              : Center(
                  child: Text(
                    name.isEmpty ? 'A' : name[0].toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isVerified)
                    Icon(Icons.verified_rounded, color: accent, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                username.isEmpty ? artistType : '@$username',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      artistType,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if ((bio ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoftOf(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        'Artist profile',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if ((bio ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _CollapsibleBio(text: bio!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CollapsibleBio extends StatefulWidget {
  final String text;
  const _CollapsibleBio({required this.text});

  @override
  State<_CollapsibleBio> createState() => _CollapsibleBioState();
}

class _CollapsibleBioState extends State<_CollapsibleBio> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryOf(context);
    final accent = AppColors.accentOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        if (widget.text.length > 90)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(top: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _expanded ? 'Show less' : 'Show more',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final surfaceSoft = AppColors.surfaceSoftOf(context);
    final border = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTab extends StatelessWidget {
  final List<Map<String, dynamic>> paintings;
  const _GalleryTab({required this.paintings});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryOf(context);
    final textTertiary = AppColors.textTertiaryOf(context);
    final border = AppColors.borderOf(context);
    final surface = AppColors.surfaceOf(context);

    if (paintings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette_outlined, color: textTertiary, size: 40),
            const SizedBox(height: 12),
            Text(
              'No artworks yet',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: paintings.length,
      itemBuilder: (_, i) {
        final p = paintings[i];
        final imageUrl = p['image_url'] as String?;
        return InkWell(
          onTap: () => context.push('/artwork/${p['id']}'),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: AppColors.cardShadows(context, hovered: false),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      Icons.palette_outlined,
                      color: textTertiary,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ThreadsTab extends StatelessWidget {
  final List<Map<String, dynamic>> threads;
  const _ThreadsTab({required this.threads});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryOf(context);
    final textTertiary = AppColors.textTertiaryOf(context);

    if (threads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, color: textTertiary, size: 40),
            const SizedBox(height: 12),
            Text(
              'No threads yet',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      itemCount: threads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _PublicProfileThreadCard(thread: threads[i]),
    );
  }
}

class _PublicProfileThreadCard extends StatefulWidget {
  final Map<String, dynamic> thread;

  const _PublicProfileThreadCard({required this.thread});

  @override
  State<_PublicProfileThreadCard> createState() =>
      _PublicProfileThreadCardState();
}

class _PublicProfileThreadCardState extends State<_PublicProfileThreadCard> {
  late bool _liked;
  late int _likesCount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.thread['is_liked'] == true;
    _likesCount = (widget.thread['likes_count'] as int?) ?? 0;
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    final paintingId = widget.thread['id']?.toString();
    if (paintingId == null || paintingId.isEmpty) return;
    final previousLiked = _liked;
    final previousCount = _likesCount;

    setState(() {
      _busy = true;
      _liked = !previousLiked;
      _likesCount = previousCount + (previousLiked ? -1 : 1);
    });

    try {
      final nextLiked = await PaintingRepository.toggleLike(paintingId);
      if (!mounted) return;
      setState(() {
        _liked = nextLiked;
        _likesCount = previousCount +
            (nextLiked == previousLiked ? 0 : (nextLiked ? 1 : -1));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _likesCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update like')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryOf(context);
    final textTertiary = AppColors.textTertiaryOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final border = AppColors.borderOf(context);
    final surface = AppColors.surfaceOf(context);
    final t = widget.thread;
    final profile = t['profiles'] as Map<String, dynamic>? ?? {};
    final authorName =
        (profile['display_name'] ?? profile['username'] ?? 'Artist').toString();
    final handle = (profile['username'] ?? authorName)
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '');
    final avatarUrl = SupabaseMediaUrl.resolve(
      profile['profile_picture_url'] as String?,
    );
    final postText = ((t['description'] ?? '').toString().trim().isNotEmpty
            ? t['description']
            : t['title'])
        .toString();
    final imageUrl = SupabaseMediaUrl.resolve(t['image_url'] as String?);
    final createdAt = DateTime.tryParse((t['created_at'] ?? '').toString());
    final tag = (t['category'] ?? t['medium'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentSoftOf(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: avatarUrl.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.person_outline, size: 18, color: textTertiary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (profile['is_verified'] == true)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.info,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$handle - ${createdAt == null ? 'now' : _profileRelativeTime(createdAt)}',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (postText.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              postText,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          if (tag.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accentSoftOf(context),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: AppColors.accentOf(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 18, color: textTertiary),
              const SizedBox(width: 20),
              InkWell(
                onTap: _toggleLike,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: _liked ? AppColors.error : textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_likesCount',
                        style: TextStyle(
                          color: _liked ? AppColors.error : textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.share_outlined, size: 18, color: textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}

String _profileRelativeTime(DateTime date) {
  final diff = DateTime.now().difference(date).abs();
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

class _SuggestedProfilesRail extends StatelessWidget {
  final List<Map<String, dynamic>> profiles;

  const _SuggestedProfilesRail({required this.profiles});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textTertiary = AppColors.textTertiaryOf(context);
    final border = AppColors.borderOf(context);
    final surface = AppColors.surfaceOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested for you',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final profile = profiles[i];
              final name =
                  (profile['display_name'] ?? profile['username'] ?? 'Artist')
                      .toString();
              final handle = (profile['username'] ?? 'artist').toString();
              final avatar = SupabaseMediaUrl.resolve(
                profile['profile_picture_url'] as String?,
              );
              final followers =
                  (profile['followers_count'] as num?)?.toInt() ?? 0;

              return InkWell(
                onTap: () =>
                    context.push('/public-profile/${profile['id']}'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 172,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: textTertiary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.accentSoftOf(context),
                        foregroundImage:
                            avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? Text(
                                name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.accentOf(context),
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        followers > 0 ? '$followers followers' : 'Creator',
                        style: TextStyle(
                          color: textTertiary,
                          fontSize: 11.5,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              context.push('/public-profile/${profile['id']}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.textPrimaryOf(context),
                            foregroundColor: AppColors.canvasOf(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Follow'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  final int followersCount;
  final int followingCount;
  final int artworksCount;

  const _AboutTab({
    required this.profile,
    required this.followersCount,
    required this.followingCount,
    required this.artworksCount,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textTertiary = AppColors.textTertiaryOf(context);
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About the artist',
            style: TextStyle(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Profile details, links, and activity snapshot.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                if (profile['artist_type'] != null)
                  _AboutRow(
                    Icons.palette_outlined,
                    'Artist type',
                    _friendlyArtistType(profile['artist_type'] as String),
                  ),
                if (profile['location'] != null)
                  _AboutRow(Icons.location_on_outlined, 'Location', profile['location'] as String),
                if (profile['website'] != null || profile['website_url'] != null)
                  _AboutRow(
                    Icons.link_outlined,
                    'Website',
                    (profile['website'] ?? profile['website_url']) as String,
                  ),
                _AboutRow(Icons.grid_view_rounded, 'Artworks', '$artworksCount pieces'),
                _AboutRow(Icons.people_outline_rounded, 'Followers', '$followersCount'),
                _AboutRow(
                  Icons.person_add_alt_1_outlined,
                  'Following',
                  '$followingCount',
                  isLast: true,
                ),
              ],
            ),
          ),
          if ((profile['bio'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Bio',
              style: TextStyle(
                color: textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              profile['bio'] as String,
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _friendlyArtistType(String value) {
  final normalized = value.trim().replaceAll('_', ' ').replaceAll('-', ' ');
  if (normalized.isEmpty) return '';
  return normalized
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _AboutRow(this.icon, this.label, this.value, {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final border = AppColors.borderOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: border, width: 0.6),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

