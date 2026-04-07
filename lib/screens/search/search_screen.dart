import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/artyug_search_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global Search Screen
// Searches paintings, artist profiles, and community posts in parallel.
// Debounced at 350 ms to avoid hammering Supabase on every keystroke.
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  /// Optional initial query — e.g. passed from the top-bar search box.
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late TabController _tabs;

  // Results
  List<Map<String, dynamic>> _artworks = [];
  List<Map<String, dynamic>> _artists = [];
  List<Map<String, dynamic>> _posts = [];

  bool _searching = false;
  String _query = '';
  bool _hasSearched = false;

  // Debounce
  DateTime? _lastInput;
  static const _debounce = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _query = _sanitizeIlikeQuery(value);
    _lastInput = DateTime.now();
    Future.delayed(_debounce, () {
      if (_lastInput == null) return;
      final elapsed = DateTime.now().difference(_lastInput!);
      if (elapsed >= _debounce) _runSearch();
    });
  }

  /// Strip characters that break PostgREST `or=(...)` / `ilike` filters.
  static String _sanitizeIlikeQuery(String raw) {
    return raw
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[%_,\\()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _runSearch() async {
    final q = _sanitizeIlikeQuery(_controller.text);
    _query = q;

    if (q.isEmpty) {
      setState(() {
        _artworks = [];
        _artists = [];
        _posts = [];
        _hasSearched = false;
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    final pattern = '%$q%';

    List<Map<String, dynamic>> artworks = [];
    List<Map<String, dynamic>> artists = [];
    List<Map<String, dynamic>> posts = [];
    final errors = <String>[];

    try {
      try {
        artworks = await _searchArtworks(pattern);
      } catch (e, st) {
        debugPrint('[SearchScreen] artworks: $e\n$st');
        errors.add('Artworks: $e');
      }
      try {
        artists = await _searchArtists(pattern);
      } catch (e, st) {
        debugPrint('[SearchScreen] artists: $e\n$st');
        errors.add('Artists: $e');
      }
      try {
        posts = await _searchPosts(pattern);
      } catch (e, st) {
        debugPrint('[SearchScreen] posts: $e\n$st');
        errors.add('Posts: $e');
      }

      if (mounted) {
        setState(() {
          _artworks = artworks;
          _artists = artists;
          _posts = posts;
          _searching = false;
          _hasSearched = true;
        });
        if (errors.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errors.length == 3
                    ? 'Search had issues. Check your connection and Supabase policies.'
                    : 'Part of search failed: ${errors.first}',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, st) {
      debugPrint('[SearchScreen] _runSearch: $e\n$st');
      if (mounted) setState(() => _searching = false);
    }
  }

  static const _paintingSelect = '''
          id, title, image_url, price, medium, category, description, style_tags, created_at,
          is_for_sale, is_sold,
          profiles!paintings_artist_id_fkey(display_name)
        ''';

  Future<List<Map<String, dynamic>>> _searchArtworks(String pattern) async {
    final orClause =
        'title.ilike.$pattern,medium.ilike.$pattern,description.ilike.$pattern,category.ilike.$pattern';

    final byFields = await _supabase
        .from('paintings')
        .select(_paintingSelect)
        .or(orClause)
        .order('created_at', ascending: false)
        .limit(30);

    final profs = await _supabase
        .from('profiles')
        .select('id')
        .or(
          'display_name.ilike.$pattern,username.ilike.$pattern,artist_type.ilike.$pattern,bio.ilike.$pattern',
        )
        .limit(40);

    final artistIds = (profs as List)
        .map((e) => e['id'] as String?)
        .whereType<String>()
        .toList();

    if (artistIds.isEmpty) {
      return List<Map<String, dynamic>>.from(byFields as List);
    }

    final byArtist = await _supabase
        .from('paintings')
        .select(_paintingSelect)
        .inFilter('artist_id', artistIds)
        .order('created_at', ascending: false)
        .limit(30);

    final byId = <String, Map<String, dynamic>>{};
    for (final row in [...byFields as List, ...byArtist as List]) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['id'] as String?;
      if (id != null) byId[id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final ta = a['created_at'] as String? ?? '';
        final tb = b['created_at'] as String? ?? '';
        return tb.compareTo(ta);
      });
    if (merged.length <= 30) return merged;
    return merged.sublist(0, 30);
  }

  Future<List<Map<String, dynamic>>> _searchArtists(String pattern) async {
    final res = await _supabase
        .from('profiles')
        .select('id, username, display_name, profile_picture_url, bio, artist_type, is_verified')
        .or(
          'display_name.ilike.$pattern,username.ilike.$pattern,bio.ilike.$pattern,artist_type.ilike.$pattern',
        )
        .order('display_name', ascending: true)
        .limit(30);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> _searchPosts(String pattern) async {
    final res = await _supabase
        .from('community_posts')
        .select('id, title, content, created_at, profiles!community_posts_author_id_fkey(display_name, username)')
        .or('title.ilike.$pattern,content.ilike.$pattern')
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res as List);
  }

  int get _totalResults => _artworks.length + _artists.length + _posts.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary, size: 24),
                    onPressed: () => context.pop(),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: ArtyugSearchBar(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: widget.initialQuery == null ||
                          widget.initialQuery!.isEmpty,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _runSearch(),
                      hintText:
                          'Search artists, creators, artworks, posts…',
                      trailing: _searching
                          ? const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_hasSearched)
            Material(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                dividerColor: AppColors.border,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(text: 'Artworks (${_artworks.length})'),
                  Tab(text: 'Artists (${_artists.length})'),
                  Tab(text: 'Posts (${_posts.length})'),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      );
    }

    if (!_hasSearched) {
      return _EmptyPrompt(query: _query);
    }

    if (_totalResults == 0) {
      return _NoResults(query: _query);
    }

    return TabBarView(
      controller: _tabs,
      children: [
        _ArtworksTab(artworks: _artworks),
        _ArtistsTab(artists: _artists),
        _PostsTab(posts: _posts),
      ],
    );
  }
}

// ─── Artworks Tab ─────────────────────────────────────────────────────────────

class _ArtworksTab extends StatelessWidget {
  final List<Map<String, dynamic>> artworks;
  const _ArtworksTab({required this.artworks});

  @override
  Widget build(BuildContext context) {
    if (artworks.isEmpty) {
      return const _EmptyTab(label: 'No artworks found');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: artworks.length,
      itemBuilder: (_, i) {
        final a = artworks[i];
        final imageUrl = a['image_url'] as String?;
        final title = a['title'] as String? ?? 'Untitled';
        final artistName =
            (a['profiles'] as Map<String, dynamic>?)?['display_name']
                as String? ??
            'Artist';
        final price = a['price'];
        final priceText = price is num
            ? '₹${price.toStringAsFixed(0)}'
            : (price != null ? '₹$price' : null);
        final sold = a['is_sold'] == true;

        return GestureDetector(
          onTap: () => context.push('/artwork/${a['id']}'),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Container(
                              color: AppColors.surfaceVariant,
                              child: const Center(
                                  child: Icon(Icons.palette_outlined,
                                      color: AppColors.textTertiary, size: 32)),
                            ),
                      if (sold)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Sold',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      if (priceText != null) ...[
                        const SizedBox(height: 4),
                        Text(priceText,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Artists Tab ──────────────────────────────────────────────────────────────

class _ArtistsTab extends StatelessWidget {
  final List<Map<String, dynamic>> artists;
  const _ArtistsTab({required this.artists});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const _EmptyTab(label: 'No artists found');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: artists.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final p = artists[i];
        final name = p['display_name'] as String? ??
            p['username'] as String? ??
            'Artist';
        final username = p['username'] as String? ?? '';
        final avatarUrl = p['profile_picture_url'] as String?;
        final bio = p['bio'] as String?;
        final isVerified = p['is_verified'] == true;
        final artistType = p['artist_type'] as String?;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18))
                : null,
          ),
          title: Row(children: [
            Text(name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            if (isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified,
                  color: AppColors.primary, size: 15),
            ],
          ]),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@$username',
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 12)),
              if (artistType != null)
                Text(artistType,
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 11)),
              if (bio != null && bio.isNotEmpty)
                Text(bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          onTap: () => context.push('/public-profile/${p['id']}'),
        );
      },
    );
  }
}

// ─── Posts Tab ────────────────────────────────────────────────────────────────

class _PostsTab extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  const _PostsTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const _EmptyTab(label: 'No posts found');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final post = posts[i];
        final title = post['title'] as String?;
        final content = post['content'] as String? ?? '';
        final author =
            (post['profiles'] as Map<String, dynamic>?)?['display_name']
                as String? ??
            'User';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title.isNotEmpty)
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              const SizedBox(height: 4),
              Text(content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4)),
              const SizedBox(height: 6),
              Text('by $author',
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Empty States ─────────────────────────────────────────────────────────────

class _EmptyPrompt extends StatelessWidget {
  final String query;
  const _EmptyPrompt({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              color: AppColors.textTertiary.withValues(alpha: 0.65),
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'Search Artyug',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Find artworks by title or medium, artists by name, or community posts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.95),
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                color: AppColors.textTertiary, size: 56),
            const SizedBox(height: 16),
            Text('No results for "$query"',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Try different keywords or check spelling.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String label;
  const _EmptyTab({required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14)),
      );
}
