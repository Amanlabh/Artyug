import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_media_url.dart';
import '../../repositories/painting_repository.dart';
import '../../widgets/artyug_search_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Explore Screen — Editorial cream/orange design system
// ─────────────────────────────────────────────────────────────────────────────

String? _explorePaintingImageUrl(Map<String, dynamic> painting) {
  var u = SupabaseMediaUrl.resolve(painting['image_url'] as String?);
  if (u.isNotEmpty) return u;
  final extras = painting['additional_images'] as List<dynamic>?;
  if (extras == null) return null;
  for (final e in extras) {
    u = SupabaseMediaUrl.resolve(e.toString());
    if (u.isNotEmpty) return u;
  }
  return null;
}

class ExploreScreen extends StatefulWidget {
  /// When true (tab inside [MainTabsScreen]), skip the full [SliverAppBar] so the
  /// shell keeps the menu + bottom nav; use a compact title row instead.
  final bool embedInShell;

  const ExploreScreen({super.key, this.embedInShell = false});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _paintings = [];
  List<Map<String, dynamic>> _artists = [];
  List<Map<String, dynamic>> _studios = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  final String _activeCategory = 'all';
  String _studioCategory = 'all';
  String _studioSort = 'trending';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchPaintings(), _fetchArtists(), _fetchStudios()]);
  }

  Future<void> _fetchPaintings() async {
    try {
      final rawPaintings = await _supabase
          .from('paintings')
          .select(
              'id, artist_id, title, description, image_url, price, is_for_sale, is_sold, category, medium, dimensions, additional_images')
          .order('created_at', ascending: false)
          .limit(30);

      final paintings = List<Map<String, dynamic>>.from(rawPaintings);
      final artistIds = paintings
          .map((p) => p['artist_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> artistMap = {};
      if (artistIds.isNotEmpty) {
        final rawArtists = await _supabase
            .from('profiles')
            .select('id, username, display_name, profile_picture_url')
            .inFilter('id', artistIds);
        artistMap = {
          for (final row in List<Map<String, dynamic>>.from(rawArtists))
            (row['id'] as String): row
        };
      }

      final merged = paintings
          .map((p) => {
                ...p,
                'profiles': artistMap[p['artist_id']] ?? <String, dynamic>{},
              })
          .toList();
      setState(() {
        _paintings = merged;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      debugPrint('[Explore] _fetchPaintings failed: $e');
      setState(() {
        _loading = false;
        _loadError = 'Could not load artworks from Supabase.';
      });
    }
  }

  Future<void> _fetchArtists() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select(
              'id, username, display_name, profile_picture_url, avatar_url, artist_type, is_verified')
          .order('created_at', ascending: false)
          .limit(10);
      setState(() {
        _artists = List<Map<String, dynamic>>.from(res);
      });
    } catch (_) {}
  }

  Future<void> _fetchStudios() async {
    try {
      final raw = await _supabase
          .from('shops')
          .select(
              'id, name, slug, description, avatar_url, cover_image_url, category, created_at, likes_count, views_count, owner_id')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(28);

      final rows = List<Map<String, dynamic>>.from(raw);
      final ownerIds = rows
          .map((e) => e['owner_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final profilesById = <String, Map<String, dynamic>>{};

      if (ownerIds.isNotEmpty) {
        final profiles = await _supabase
            .from('profiles')
            .select('id, display_name, profile_picture_url')
            .inFilter('id', ownerIds);
        for (final p in List<Map<String, dynamic>>.from(profiles)) {
          profilesById[p['id'] as String] = p;
        }
      }

      for (final row in rows) {
        final shopId = row['id'] as String;
        try {
          final worksCount = await _supabase
              .from('paintings')
              .select('id')
              .eq('shop_id', shopId)
              .count(CountOption.exact);
          row['artworks_count'] = worksCount.count;
        } catch (_) {
          row['artworks_count'] = 0;
        }
        try {
          final collectionsCount = await _supabase
              .from('collections')
              .select('id')
              .eq('shop_id', shopId)
              .count(CountOption.exact);
          row['collections_count'] = collectionsCount.count;
        } catch (_) {
          row['collections_count'] = 0;
        }
        row['profile'] = profilesById[row['owner_id']] ?? <String, dynamic>{};
      }

      if (!mounted) return;
      setState(() => _studios = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _studios = const []);
    }
  }

  Future<void> _search(String term) async {
    if (term.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select(
              'id, username, display_name, profile_picture_url, avatar_url, artist_type, is_verified')
          .or('username.ilike.%$term%,display_name.ilike.%$term%')
          .limit(20);
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(res);
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_activeCategory == 'all') return _paintings;
    return _paintings.where((p) {
      final cat = (p['category'] ?? '').toString().toLowerCase();
      return cat == _activeCategory || cat.contains(_activeCategory);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredStudios {
    final term = _searchCtrl.text.trim().toLowerCase();
    var list = List<Map<String, dynamic>>.from(_studios);
    if (_studioCategory != 'all') {
      list = list
          .where((s) => (s['category'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_studioCategory))
          .toList();
    }
    if (term.isNotEmpty) {
      list = list.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final desc = (s['description'] ?? '').toString().toLowerCase();
        final artist =
            ((s['profile'] as Map<String, dynamic>?)?['display_name'] ?? '')
                .toString()
                .toLowerCase();
        return name.contains(term) || desc.contains(term) || artist.contains(term);
      }).toList();
    }

    list.sort((a, b) {
      switch (_studioSort) {
        case 'newest':
          final ad = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
              DateTime(1970);
          final bd = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
              DateTime(1970);
          return bd.compareTo(ad);
        case 'most_works':
          return ((b['artworks_count'] as int? ?? 0))
              .compareTo(a['artworks_count'] as int? ?? 0);
        case 'most_followed':
          return ((b['likes_count'] as int? ?? 0))
              .compareTo(a['likes_count'] as int? ?? 0);
        case 'trending':
        default:
          final as = ((a['views_count'] as int? ?? 0) * 1) +
              ((a['likes_count'] as int? ?? 0) * 3) +
              ((a['artworks_count'] as int? ?? 0) * 4) +
              ((a['collections_count'] as int? ?? 0) * 2);
          final bs = ((b['views_count'] as int? ?? 0) * 1) +
              ((b['likes_count'] as int? ?? 0) * 3) +
              ((b['artworks_count'] as int? ?? 0) * 4) +
              ((b['collections_count'] as int? ?? 0) * 2);
          return bs.compareTo(as);
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = _searchCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.canvas(context),
      body: RefreshIndicator(
        onRefresh: _fetchAll,
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceOf(context),
        child: CustomScrollView(
          slivers: [
            if (!widget.embedInShell)
              SliverAppBar(
                backgroundColor: AppColors.canvas(context),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                floating: true,
                snap: true,
                title: Text('Explore',
                    style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 22)),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                      height: 1,
                      color:
                          AppColors.borderOf(context).withValues(alpha: 0.5)),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        'Explore',
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  widget.embedInShell ? 8 : 16,
                  16,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Search bar (neon pill — matches global Search) ─
                    ArtyugSearchBar(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      onChanged: _search,
                      hintText: 'Search artists, creators, artworks…',
                      trailing: _searching
                          ? const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _ExploreMarketplaceHero(
                      onUpload: () => context.push('/upload'),
                    ),
                    const SizedBox(height: 10),
                    _ExploreQuickActions(embedInShell: widget.embedInShell),

                    // Search results ────────────────────────────────
                    if (showSearch) ...[
                      const SizedBox(height: 12),
                      if (_searchResults.isEmpty && !_searching)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('No results found',
                                style: TextStyle(
                                    color: AppColors.textSecondaryOf(context),
                                    fontSize: 14)),
                          ),
                        )
                      else
                        ...(_searchResults
                            .map((a) => _ArtistRow(artist: a))
                            .toList()),
                    ],

                    if (!showSearch) ...[
                      if (_loadError != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.borderOf(context)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _loadError!,
                                  style: TextStyle(
                                    color: AppColors.textSecondaryOf(context),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // ── Category chips ────────────────────────────────
                      const SizedBox(height: 20),

                      // ── Featured artists row ──────────────────────────
                      if (_artists.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('CREATORS',
                                style: TextStyle(
                                    color: AppColors.textTertiaryOf(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2)),
                            TextButton(
                              onPressed: () => context.push('/search?q=artist'),
                              child: const Text('View all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _artists.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 16),
                            itemBuilder: (_, i) =>
                                _ArtistPill(artist: _artists[i]),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('FEATURED GALLERIES',
                              style: TextStyle(
                                  color: AppColors.textTertiaryOf(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2)),
                          TextButton(
                            onPressed: () => context.push('/shop'),
                            child: const Text('View all galleries'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _studioFilterChip('All', 'all'),
                            _studioFilterChip('Painting', 'painting'),
                            _studioFilterChip('Digital', 'digital'),
                            _studioFilterChip('Photography', 'photography'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('${_filteredStudios.length} studios',
                              style: TextStyle(
                                  color: AppColors.textTertiaryOf(context),
                                  fontSize: 12)),
                          const Spacer(),
                          DropdownButton<String>(
                            value: _studioSort,
                            underline: const SizedBox.shrink(),
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(context)),
                            dropdownColor: AppColors.surfaceOf(context),
                            items: const [
                              DropdownMenuItem(
                                  value: 'trending', child: Text('Trending')),
                              DropdownMenuItem(
                                  value: 'newest', child: Text('Newest')),
                              DropdownMenuItem(
                                  value: 'most_works',
                                  child: Text('Most Works')),
                              DropdownMenuItem(
                                  value: 'most_followed',
                                  child: Text('Most Followed')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _studioSort = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_filteredStudios.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.borderOf(context)),
                          ),
                          child: Text(
                            'No studios match your current filters.',
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 13),
                          ),
                        )
                      else
                        SizedBox(
                          height: 254,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filteredStudios.length.clamp(0, 10),
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) => _StudioDiscoveryCard(
                              studio: _filteredStudios[i],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // ── Section label ─────────────────────────────────
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ARTWORKS',
                                style: TextStyle(
                                    color: AppColors.textTertiaryOf(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2)),
                            Text('${_filtered.length} pieces',
                                style: TextStyle(
                                    color: AppColors.textTertiaryOf(context),
                                    fontSize: 12)),
                          ]),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),

            // ── Artwork grid ─────────────────────────────────────────
            if (!showSearch)
              _loading
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2),
                        ),
                      ),
                    )
                  : _filtered.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.palette_outlined,
                                      color: AppColors.textTertiaryOf(context),
                                      size: 40),
                                  const SizedBox(height: 12),
                                  Text('No artworks in this category',
                                      style: TextStyle(
                                          color: AppColors.textSecondaryOf(
                                              context),
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _ArtworkCard(painting: _filtered[i]),
                              childCount: _filtered.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.78,
                            ),
                          ),
                        ),
          ],
        ),
      ),
    );
  }

  Widget _studioFilterChip(String label, String id) {
    final active = _studioCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _studioCategory = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.borderOf(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textPrimaryOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioDiscoveryCard extends StatelessWidget {
  final Map<String, dynamic> studio;

  const _StudioDiscoveryCard({required this.studio});

  @override
  Widget build(BuildContext context) {
    final name = (studio['name'] as String?)?.trim().isNotEmpty == true
        ? (studio['name'] as String).trim()
        : 'Studio';
    final slug = (studio['slug'] as String?)?.trim();
    final avatar = (studio['avatar_url'] as String?)?.trim();
    final cover = SupabaseMediaUrl.resolve(studio['cover_image_url'] as String?);
    final profile = studio['profile'] as Map<String, dynamic>?;
    final by = (profile?['display_name'] as String?)?.trim().isNotEmpty == true
        ? (profile!['display_name'] as String).trim()
        : 'Creator';
    final works = (studio['artworks_count'] as int?) ?? 0;
    final collections = (studio['collections_count'] as int?) ?? 0;
    final category = (studio['category'] as String?)?.trim();

    return GestureDetector(
      onTap: () =>
          context.push(slug != null && slug.isNotEmpty ? '/shop/$slug' : '/shop'),
      child: Container(
        width: 306,
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: cover.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.surfaceMutedOf(context),
                      child: Center(
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.16),
                          backgroundImage: (avatar != null && avatar.isNotEmpty)
                              ? CachedNetworkImageProvider(avatar)
                              : null,
                          child: (avatar == null || avatar.isEmpty)
                              ? Text(
                                  name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(82, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Follow'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (category != null && category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoftOf(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: AppColors.accentOf(context),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    by,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$works works - $collections collections',
                    style: TextStyle(
                      color: AppColors.textTertiaryOf(context),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistPill extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _ArtistPill({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['display_name'] ?? artist['username'] ?? 'Artist';
    final initial = name[0].toUpperCase();
    final avatarUrl = SupabaseMediaUrl.resolve(
      (artist['profile_picture_url'] ?? artist['avatar_url']) as String?,
    );
    final isVerified = artist['is_verified'] == true ||
        artist['artist_is_verified'] == true;

    return GestureDetector(
      onTap: () => context.push('/public-profile/${artist['id']}'),
      child: Column(children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2), width: 2),
              ),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(initial,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
                    ),
            ),
            if (isVerified)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─── Artist Row (search result) ───────────────────────────────────────────────
class _ArtistRow extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _ArtistRow({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['display_name'] ?? artist['username'] ?? 'Artist';
    final initial = name[0].toUpperCase();
    final avatarUrl = SupabaseMediaUrl.resolve(
      (artist['profile_picture_url'] ?? artist['avatar_url']) as String?,
    );
    final type = artist['artist_type'] as String? ?? '';
    final isVerified = artist['is_verified'] == true ||
        artist['artist_is_verified'] == true;

    return GestureDetector(
      onTap: () => context.push('/public-profile/${artist['id']}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: AppColors.borderOf(context), width: 0.5))),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                        imageUrl: avatarUrl, fit: BoxFit.cover))
                : Center(
                    child: Text(initial,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: AppColors.info,
                      ),
                    ],
                  ],
                ),
                if (type.isNotEmpty)
                  Text(type,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18, color: AppColors.textTertiaryOf(context)),
        ]),
      ),
    );
  }
}

// ─── Artwork Card ─────────────────────────────────────────────────────────────
class _ArtworkCard extends StatefulWidget {
  final Map<String, dynamic> painting;
  const _ArtworkCard({required this.painting});

  @override
  State<_ArtworkCard> createState() => _ArtworkCardState();
}

class _ArtworkCardState extends State<_ArtworkCard> {
  bool _expanded = false;
  late bool _liked;
  late int _likesCount;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.painting['is_liked'] == true;
    _likesCount = (widget.painting['likes_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() {
      _likeBusy = true;
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
      if (_likesCount < 0) _likesCount = 0;
    });
    try {
      await PaintingRepository.toggleLike(widget.painting['id'].toString());
      widget.painting['is_liked'] = _liked;
      widget.painting['likes_count'] = _likesCount;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likesCount += _liked ? 1 : -1;
        if (_likesCount < 0) _likesCount = 0;
      });
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final painting = widget.painting;
    final profile = painting['profiles'] as Map<String, dynamic>? ?? {};
    final artistName =
        profile['display_name'] ?? profile['username'] ?? 'Artist';
    final imageUrl = _explorePaintingImageUrl(painting);
    final title = painting['title'] as String? ?? 'Untitled';
    final description = (painting['description'] as String? ?? '').trim();
    final medium = (painting['medium'] as String? ?? '').trim();
    final dimensions = (painting['dimensions'] as String? ?? '').trim();
    final price = painting['price'] ?? painting['price_inr'];
    final available =
        (painting['is_for_sale'] == true || painting['is_available'] == true) &&
            painting['is_sold'] != true;
    final details = [
      if (medium.isNotEmpty) medium,
      if (dimensions.isNotEmpty) dimensions,
    ].join('  |  ');
    final priceLabel = _formatPrice(price);
    final showReadMore = description.length > 72;
    final visibleDescription = _expanded || !showReadMore
        ? description
        : '${description.substring(0, 72).trimRight()}...';

    return GestureDetector(
      onTap: () => context.push('/artwork/${painting['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.34,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) =>
                          Container(color: AppColors.surfaceMutedOf(context)),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surfaceMutedOf(context),
                        child: Center(
                          child: Icon(
                            Icons.palette_outlined,
                            color: AppColors.textTertiaryOf(context),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceMutedOf(context),
                      child: Center(
                        child: Icon(
                          Icons.palette_outlined,
                          color: AppColors.textTertiaryOf(context),
                          size: 32,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            priceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _ActionIcon(
                          icon: _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _liked ? AppColors.error : null,
                          onTap: _toggleLike,
                        ),
                        const SizedBox(width: 6),
                        _ActionIcon(
                          icon: Icons.add_shopping_cart_outlined,
                          onTap: () {
                            if (available) {
                              context.push('/checkout/${painting['id']}');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11.5,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textTertiaryOf(context),
                          fontSize: 10.8,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        visibleDescription,
                        maxLines: _expanded ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      if (showReadMore)
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _expanded ? 'Read less' : 'Read more',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        _likesCount > 0 ? '$_likesCount likes' : 'Like this artwork',
                        style: TextStyle(
                          color: AppColors.textTertiaryOf(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: available
                            ? () => context.push('/checkout/${painting['id']}')
                            : () => context.push('/artwork/${painting['id']}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: available
                              ? AppColors.primary
                              : AppColors.surfaceMutedOf(context),
                          foregroundColor: available
                              ? Colors.white
                              : AppColors.textSecondaryOf(context),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          available ? 'Buy now' : 'View artwork',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic raw) {
    if (raw == null) return 'Price on request';
    if (raw is int) return 'Rs $raw';
    if (raw is double) {
      if (raw == raw.roundToDouble()) return 'Rs ${raw.toInt()}';
      return 'Rs ${raw.toStringAsFixed(0)}';
    }
    return 'Rs $raw';
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surfaceMutedOf(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Icon(
          icon,
          size: 17,
          color: color ?? AppColors.textPrimaryOf(context),
        ),
      ),
    );
  }
}

class _ExploreQuickActions extends StatelessWidget {
  final bool embedInShell;

  const _ExploreQuickActions({required this.embedInShell});

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(Icons.people_alt_rounded, 'Artists', () => context.push('/search?q=artist')),
          const SizedBox(width: 8),
          chip(Icons.storefront_rounded, 'Studios', () => context.push('/shop')),
          const SizedBox(width: 8),
          chip(Icons.gavel_rounded, 'Auctions', () => context.push('/auctions')),
          const SizedBox(width: 8),
          chip(Icons.verified_user_rounded, 'Authenticity', () => context.push('/authenticity-center')),
          const SizedBox(width: 8),
          chip(Icons.nfc_rounded, 'NFC Scan', () => context.push('/nfc-scan')),
        ],
      ),
    );
  }
}

class _ExploreMarketplaceHero extends StatelessWidget {
  final VoidCallback onUpload;

  const _ExploreMarketplaceHero({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover Digital Collectibles on Artyug',
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A premium marketplace for verified creators, authenticated artworks, and high-intent collectors.',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('List Artwork'),
            ),
          ),
        ],
      ),
    );
  }
}


