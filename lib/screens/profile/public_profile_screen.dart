import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public Profile Screen — Editorial cream/orange design system
// ─────────────────────────────────────────────────────────────────────────────

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
    await Future.wait([
      _fetchProfile(),
      _fetchPaintings(),
      _fetchThreads(),
      _fetchFollowStats(),
    ]);
    final me = Provider.of<AuthProvider>(context, listen: false).user;
    if (me != null && me.id != widget.userId) {
      await _checkFollowStatus(me.id);
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .single();
      if (mounted) setState(() { _profile = res; _loading = false; });
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
      if (mounted) setState(() => _paintings = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _fetchThreads() async {
    try {
      final res = await _supabase
          .from('community_posts')
          .select('id, title, content, created_at')
          .eq('author_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) setState(() => _threads = List<Map<String, dynamic>>.from(res));
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
      if (mounted) setState(() {
        _followersCount = (followers as List).length;
        _followingCount = (following as List).length;
      });
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
        setState(() { _isFollowing = false; _followersCount--; });
      } else {
        await _supabase.from('follows').insert({
          'follower_id': me.id,
          'following_id': widget.userId,
        });
        setState(() { _isFollowing = true; _followersCount++; });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Provider.of<AuthProvider>(context).user;
    final isOwn = me?.id == widget.userId;

    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2)),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Profile not found',
            style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final name = _profile!['display_name'] as String? ??
        _profile!['username'] as String? ?? 'Artist';
    final username = _profile!['username'] as String? ?? '';
    final bio = _profile!['bio'] as String?;
    final avatarUrl = _profile!['profile_picture_url'] as String?;
    final isVerified = _profile!['is_verified'] == true;
    final artistType = _profile!['artist_type'] as String? ?? 'Creator';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text('@$username',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                  height: 1, color: AppColors.border.withOpacity(0.5)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.1),
                        border: Border.all(
                            color: AppColors.border, width: 2),
                      ),
                      child: avatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                  imageUrl: avatarUrl, fit: BoxFit.cover))
                          : Center(
                              child: Text(name[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 28))),
                    ),
                    const SizedBox(width: 20),

                    // Stats
                    Expanded(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Stat('${_paintings.length}', 'Works'),
                            _Stat('$_followersCount', 'Followers'),
                            _Stat('$_followingCount', 'Following'),
                          ]),
                    ),
                  ]),

                  const SizedBox(height: 14),

                  // Name + verified + type
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ),
                    if (isVerified)
                      const Icon(Icons.verified,
                          color: AppColors.primary, size: 18),
                  ]),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(artistType,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(bio,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.4)),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  if (isOwn)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.push('/edit-profile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Edit Profile',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    )
                  else
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _followLoading ? null : _handleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? AppColors.surface
                                : AppColors.primary,
                            foregroundColor: _isFollowing
                                ? AppColors.textPrimary
                                : Colors.white,
                            elevation: 0,
                            side: _isFollowing
                                ? const BorderSide(color: AppColors.border)
                                : null,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _followLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary))
                              : Text(_isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              context.push('/chat/${widget.userId}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Message',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),

                  const SizedBox(height: 16),

                  // Tab bar
                  TabBar(
                    controller: _tabs,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textTertiary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                    dividerColor: AppColors.border,
                    tabs: const [
                      Tab(text: 'Gallery'),
                      Tab(text: 'Threads'),
                      Tab(text: 'About'),
                    ],
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
            _AboutTab(profile: _profile!,
                followersCount: _followersCount,
                followingCount: _followingCount,
                artworksCount: _paintings.length),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Widget ──────────────────────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
      ]);
}

// ─── Gallery Tab ──────────────────────────────────────────────────────────────
class _GalleryTab extends StatelessWidget {
  final List<Map<String, dynamic>> paintings;
  const _GalleryTab({required this.paintings});

  @override
  Widget build(BuildContext context) {
    if (paintings.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.palette_outlined,
              color: AppColors.textTertiary, size: 40),
          SizedBox(height: 12),
          Text('No artworks yet',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: paintings.length,
      itemBuilder: (_, i) {
        final p = paintings[i];
        final imageUrl = p['image_url'] as String?;
        return GestureDetector(
          onTap: () => context.push('/artwork/${p['id']}'),
          child: imageUrl != null
              ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
              : Container(
                  color: AppColors.surfaceVariant,
                  child: const Center(
                      child: Icon(Icons.palette_outlined,
                          color: AppColors.textTertiary)),
                ),
        );
      },
    );
  }
}

// ─── Threads Tab ──────────────────────────────────────────────────────────────
class _ThreadsTab extends StatelessWidget {
  final List<Map<String, dynamic>> threads;
  const _ThreadsTab({required this.threads});

  @override
  Widget build(BuildContext context) {
    if (threads.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.forum_outlined,
              color: AppColors.textTertiary, size: 40),
          SizedBox(height: 12),
          Text('No threads yet',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: threads.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final t = threads[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((t['title'] ?? '').isNotEmpty)
                Text(t['title'] as String,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              if ((t['content'] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(t['content'] as String,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── About Tab ────────────────────────────────────────────────────────────────
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DETAILS',
            style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            if (profile['artist_type'] != null)
              _AboutRow(Icons.palette_outlined,
                  'Artist Type', profile['artist_type'] as String),
            if (profile['location'] != null)
              _AboutRow(Icons.location_on_outlined,
                  'Location', profile['location'] as String),
            if (profile['website'] != null || profile['website_url'] != null)
              _AboutRow(Icons.link_outlined, 'Website',
                  (profile['website'] ?? profile['website_url']) as String),
            _AboutRow(Icons.palette_outlined,
                'Artworks', '$artworksCount pieces', isLast: true),
          ]),
        ),
        const SizedBox(height: 20),
        if ((profile['bio'] ?? '').isNotEmpty) ...[
          const Text('BIO',
              style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text(profile['bio'] as String,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.6)),
        ],
      ]),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _AboutRow(this.icon, this.label, this.value, {this.isLast = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: isLast
            ? null
            : const BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: AppColors.border, width: 0.5))),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('$label  ',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
