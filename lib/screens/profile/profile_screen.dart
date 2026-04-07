import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Screen — My Profile
// Design: cream bg, orange accent, black text. Editorial-brutalist.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _paintings = [];
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  String _activeTab = 'gallery';
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    await Future.wait([
      _fetchProfile(user.id),
      _fetchPaintings(user.id),
      _fetchThreads(user.id),
      _fetchFollowStats(user.id),
    ]);
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();
      setState(() {
        _profile = Map<String, dynamic>.from(res);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchPaintings(String userId) async {
    try {
      final res = await _supabase
          .from('paintings')
          .select('id, title, image_url, price_inr, is_available')
          .eq('artist_id', userId)
          .order('created_at', ascending: false);
      setState(() => _paintings = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _fetchThreads(String userId) async {
    try {
      final res = await _supabase
          .from('community_posts')
          .select('id, title, content, created_at')
          .eq('author_id', userId)
          .order('created_at', ascending: false);
      setState(() => _threads = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _fetchFollowStats(String userId) async {
    try {
      final followers = await _supabase
          .from('follows')
          .select('id')
          .eq('following_id', userId);
      final following = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', userId);
      setState(() {
        _followersCount = (followers as List).length;
        _followingCount = (following as List).length;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.canvas(context),
        body: const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    final displayName = _profile?['display_name'] ??
        _profile?['username'] ??
        Provider.of<AuthProvider>(context, listen: false)
            .user
            ?.email
            ?.split('@')[0] ??
        'Artist';

    final username = _profile?['username'] ?? '';
    final role = _profile?['role'] as String? ?? '';
    final bio = _profile?['bio'] as String?;
    final avatarUrl = _profile?['profile_picture_url'] as String?;
    final coverUrl = _profile?['cover_image_url'] as String?;
    final initial = displayName[0].toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.canvas(context),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.canvas(context),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            floating: true,
            snap: true,
            title: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: 'My Profile',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ]),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined,
                    color: AppColors.textPrimaryOf(context), size: 22),
                onPressed: () => context.push('/settings'),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                  height: 1,
                  color: AppColors.borderOf(context).withValues(alpha: 0.5)),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header card (banner + row — matches edit profile) ─
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (coverUrl != null && coverUrl.isNotEmpty)
                          SizedBox(
                            height: 108,
                            width: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.12),
                                border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    width: 2),
                              ),
                              child: avatarUrl != null
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: avatarUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                            ),
                            // Verified dot
                            if (_profile?['is_verified'] == true)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 16),

                        // Name + username + role badge + bio
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name row
                              Row(children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      color: AppColors.textPrimaryOf(context),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),

                              if (username.isNotEmpty)
                                Text('@$username',
                                    style: TextStyle(
                                        color: AppColors.textSecondaryOf(context),
                                        fontSize: 13)),

                              if (role.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: role == 'creator'
                                        ? AppColors.primary.withValues(alpha: 0.1)
                                        : AppColors.info.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: role == 'creator'
                                          ? AppColors.primary.withValues(alpha: 0.3)
                                          : AppColors.info.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    role == 'creator' ? '🎨 Creator' : '🖼 Collector',
                                    style: TextStyle(
                                      color: role == 'creator'
                                          ? AppColors.primary
                                          : AppColors.info,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],

                              if (bio != null && bio.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  bio,
                                  style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 13,
                                      height: 1.4),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

                  const SizedBox(height: 12),

                  // ── Stats row ───────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                            label: 'Artworks',
                            value: '${_paintings.length}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                            label: 'Followers',
                            value: '$_followersCount'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                            label: 'Following',
                            value: '$_followingCount'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Edit Profile button ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/edit-profile'),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimaryOf(context),
                            side: BorderSide(color: AppColors.borderOf(context)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Upload CTA for creators
                      if (role == 'creator')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/upload'),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Upload Art'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Tabs ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMutedOf(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _TabBtn(
                            label: 'Gallery',
                            active: _activeTab == 'gallery',
                            onTap: () =>
                                setState(() => _activeTab = 'gallery')),
                        _TabBtn(
                            label: 'Threads',
                            active: _activeTab == 'threads',
                            onTap: () =>
                                setState(() => _activeTab = 'threads')),
                        _TabBtn(
                            label: 'About',
                            active: _activeTab == 'about',
                            onTap: () =>
                                setState(() => _activeTab = 'about')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Tab content ──────────────────────────────────────
                  _buildTabContent(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'gallery':
        if (_paintings.isEmpty) {
          return _EmptyState(
            icon: Icons.palette_outlined,
            title: 'No artworks yet',
            subtitle: 'Upload your first piece to start your gallery',
            action: ElevatedButton.icon(
              onPressed: () => context.push('/upload'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Upload Artwork'),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _paintings.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) => _PaintingTile(painting: _paintings[i]),
        );

      case 'threads':
        if (_threads.isEmpty) {
          return const _EmptyState(
            icon: Icons.forum_outlined,
            title: 'No threads yet',
            subtitle: 'Share your thoughts in the community',
          );
        }
        return Column(
          children: _threads.map((t) => _ThreadCard(thread: t)).toList(),
        );

      case 'about':
        return _AboutSection(
          profile: _profile,
          paintings: _paintings.length,
          followers: _followersCount,
          following: _followingCount,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Tab Button ───────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceOf(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active
                  ? AppColors.textPrimaryOf(context)
                  : AppColors.textSecondaryOf(context),
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Painting Tile ────────────────────────────────────────────────────────────
class _PaintingTile extends StatelessWidget {
  final Map<String, dynamic> painting;
  const _PaintingTile({required this.painting});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/artwork/${painting['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceMutedOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (painting['image_url'] != null)
              CachedNetworkImage(
                imageUrl: painting['image_url'] as String,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppColors.surfaceMutedOf(context)),
                errorWidget: (_, __, ___) => Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.textTertiaryOf(context)),
                ),
              )
            else
              Center(
                child: Icon(Icons.palette_outlined,
                    color: AppColors.textTertiaryOf(context), size: 32),
              ),

            // Price tag
            if (painting['is_available'] == true &&
                painting['price_inr'] != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '₹${painting['price_inr']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Thread Card ──────────────────────────────────────────────────────────────
class _ThreadCard extends StatelessWidget {
  final Map<String, dynamic> thread;
  const _ThreadCard({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thread['title'] != null)
            Text(thread['title'] as String,
                style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          if (thread['content'] != null) ...[
            const SizedBox(height: 6),
            Text(
              thread['content'] as String,
              style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 13,
                  height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── About Section ────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final int paintings;
  final int followers;
  final int following;
  const _AboutSection(
      {required this.profile,
      required this.paintings,
      required this.followers,
      required this.following});

  @override
  Widget build(BuildContext context) {
    final bio = profile?['bio'] as String?;
    final location = profile?['location'] as String?;
    final website =
        (profile?['website'] ?? profile?['website_url']) as String?;
    final artistType = profile?['artist_type'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ABOUT',
              style: TextStyle(
                  color: AppColors.textTertiaryOf(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),

          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(bio,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 14,
                    height: 1.5)),
          ] else ...[
            const SizedBox(height: 12),
            Text('No bio added yet.',
                style: TextStyle(
                    color: AppColors.textTertiaryOf(context), fontSize: 14)),
          ],

          if (artistType != null) ...[
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.brush_outlined, label: artistType),
          ],
          if (location != null) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on_outlined, label: location),
          ],
          if (website != null) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.link_rounded, label: website),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondaryOf(context), size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: AppColors.textSecondaryOf(context), fontSize: 13)),
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const _EmptyState(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceMutedOf(context),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textSecondaryOf(context), size: 28),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(
                  color: AppColors.textSecondaryOf(context), fontSize: 13),
              textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
