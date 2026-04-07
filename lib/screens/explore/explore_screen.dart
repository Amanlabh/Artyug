import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_media_url.dart';
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
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  String _activeCategory = 'all';
  String? _loadError;

  final _categories = [
    {'id': 'all', 'name': 'All', 'emoji': 'A'},
    {'id': 'painting', 'name': 'Painting', 'emoji': 'P'},
    {'id': 'digital', 'name': 'Digital', 'emoji': 'D'},
    {'id': 'photography', 'name': 'Photography', 'emoji': 'Ph'},
    {'id': 'sculpture', 'name': 'Sculpture', 'emoji': 'S'},
    {'id': 'drawing', 'name': 'Drawing', 'emoji': 'Dr'},
    {'id': 'print', 'name': 'Print', 'emoji': 'Pr'},
    {'id': 'other', 'name': 'Other', 'emoji': 'O'},
  ];

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
    await Future.wait([_fetchPaintings(), _fetchArtists()]);
  }

  Future<void> _fetchPaintings() async {
    try {
      final rawPaintings = await _supabase
          .from('paintings')
          .select(
              'id, artist_id, title, image_url, price, is_for_sale, is_sold, category')
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
              'id, username, display_name, profile_picture_url, artist_type')
          .order('created_at', ascending: false)
          .limit(10);
      setState(() {
        _artists = List<Map<String, dynamic>>.from(res);
      });
    } catch (_) {}
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
              'id, username, display_name, profile_picture_url, artist_type')
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

                    // ── Search results ────────────────────────────────
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
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final cat = _categories[i];
                            final active = _activeCategory == cat['id'];
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _activeCategory = cat['id']!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                      color: active
                                          ? AppColors.primary
                                          : AppColors.borderOf(context)),
                                ),
                                child: Row(children: [
                                  Text(cat['emoji']!,
                                      style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 5),
                                  Text(cat['name']!,
                                      style: TextStyle(
                                          color: active
                                              ? Colors.white
                                              : AppColors.textPrimaryOf(
                                                  context),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Featured artists row ──────────────────────────
                      if (_artists.isNotEmpty) ...[
                        Text('CREATORS',
                            style: TextStyle(
                                color: AppColors.textTertiaryOf(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
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
                              childAspectRatio: 0.75,
                            ),
                          ),
                        ),
          ],
        ),
      ),
    );
  }
}

// ─── Artist Pill (horizontal scroll) ─────────────────────────────────────────
class _ArtistPill extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _ArtistPill({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['display_name'] ?? artist['username'] ?? 'Artist';
    final initial = name[0].toUpperCase();
    final avatarUrl = SupabaseMediaUrl.resolve(
      artist['profile_picture_url'] as String?,
    );

    return GestureDetector(
      onTap: () => context.push('/public-profile/${artist['id']}'),
      child: Column(children: [
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
      artist['profile_picture_url'] as String?,
    );
    final type = artist['artist_type'] as String? ?? '';

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
                Text(name,
                    style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
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
class _ArtworkCard extends StatelessWidget {
  final Map<String, dynamic> painting;
  const _ArtworkCard({required this.painting});

  @override
  Widget build(BuildContext context) {
    final profile = painting['profiles'] as Map<String, dynamic>? ?? {};
    final artistName =
        profile['display_name'] ?? profile['username'] ?? 'Artist';
    final imageUrl = _explorePaintingImageUrl(painting);
    final title = painting['title'] as String? ?? 'Untitled';
    final price = painting['price'] ?? painting['price_inr'];
    final available =
        (painting['is_for_sale'] == true || painting['is_available'] == true) &&
            painting['is_sold'] != true;

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
            // Image
            Expanded(
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
                            child: Icon(Icons.palette_outlined,
                                color: AppColors.textTertiaryOf(context))),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceMutedOf(context),
                      child: Center(
                          child: Icon(Icons.palette_outlined,
                              color: AppColors.textTertiaryOf(context),
                              size: 32)),
                    ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 11)),
                  if (available && price != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('₹$price',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text('Buy',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
