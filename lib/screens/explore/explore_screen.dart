import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _paintings = [];
  List<Map<String, dynamic>> _featuredArtists = [];
  bool _loading = true;

  String _searchTerm = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'name': 'All', 'icon': '🎨', 'color': '#8b5cf6'},
    {'id': 'artwork', 'name': 'Visual Art', 'icon': '🖼️', 'color': '#3b82f6'},
    {'id': 'singing', 'name': 'Music', 'icon': '🎵', 'color': '#10b981'},
    {'id': 'dancer', 'name': 'Dance', 'icon': '💃', 'color': '#ef4444'},
    {'id': 'author', 'name': 'Books', 'icon': '📚', 'color': '#f59e0b'},
    {'id': 'writer', 'name': 'Writing', 'icon': '✍️', 'color': '#059669'},
    {'id': 'theater', 'name': 'Theater', 'icon': '🎭', 'color': '#dc2626'},
    {'id': 'comedian', 'name': 'Comedy', 'icon': '😄', 'color': '#f59e0b'},
    {'id': 'creator', 'name': 'Digital', 'icon': '✨', 'color': '#6366f1'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchPaintings();
    _fetchFeaturedArtists();
  }

  Future<void> _fetchPaintings() async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;

      final response = await _supabase
          .from('paintings')
          .select('''
            *,
            profiles:artist_id (
              id,
              username,
              display_name,
              profile_picture_url,
              artist_type
            )
          ''')
          .order('created_at', ascending: false)
          .limit(20);

      if (response.isEmpty) {
        setState(() {
          _paintings = [];
          _loading = false;
        });
        return;
      }

      final paintingsData = List<Map<String, dynamic>>.from(response);

      final paintingsWithLikes = await Future.wait(
        paintingsData.map((painting) async {
          final likesResponse = await _supabase
              .from('painting_likes')
              .select('id')
              .eq('painting_id', painting['id']);

          final likesCount = likesResponse.length;

          bool isLiked = false;
          if (user?.id != null) {
            final userLikeResponse = await _supabase
                .from('painting_likes')
                .select('id')
                .eq('painting_id', painting['id'])
                .eq('user_id', user!.id)
                .maybeSingle();

            isLiked = userLikeResponse != null;
          }

          return {
            ...painting,
            'likes_count': likesCount,
            'is_liked': isLiked,
          };
        }),
      );

      setState(() {
        _paintings = paintingsWithLikes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _paintings = [];
        _loading = false;
      });
    }
  }

  Future<void> _fetchFeaturedArtists() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select(
              'id, username, display_name, profile_picture_url, followers_count, artist_type')
          .order('followers_count', ascending: false)
          .limit(6);

      setState(() {
        _featuredArtists = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        _featuredArtists = [];
      });
    }
  }

  Future<void> _searchArtists(String term) async {
    if (term.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }

    setState(() => _searchLoading = true);

    try {
      final response = await _supabase
          .from('profiles')
          .select(
              'id, username, display_name, profile_picture_url, followers_count, artist_type')
          .or('username.ilike.%$term%,display_name.ilike.%$term%')
          .limit(20);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
        _searchLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
    }
  }

  Future<void> _handleLikePainting(String paintingId) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like artwork')),
      );
      return;
    }

    final index = _paintings.indexWhere((p) => p['id'] == paintingId);
    if (index == -1) return;

    final item = _paintings[index];
    final wasLiked = item['is_liked'];

    setState(() {
      _paintings[index] = {
        ...item,
        'is_liked': !wasLiked,
        'likes_count':
            (item['likes_count'] as int) + (wasLiked ? -1 : 1),
      };
    });

    try {
      if (wasLiked) {
        await _supabase
            .from('painting_likes')
            .delete()
            .eq('painting_id', paintingId)
            .eq('user_id', user.id);
      } else {
        await _supabase.from('painting_likes').insert({
          'painting_id': paintingId,
          'user_id': user.id,
        });
      }
    } catch (_) {
      setState(() => _paintings[index] = item);
    }
  }

  // ---------------------------- RETRO UI ELEMENTS ----------------------------

  PreferredSizeWidget _retroAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.black.withOpacity(0.4),
      title: const Text(
        "Explore",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
      centerTitle: true,
    );
  }

  BoxDecoration _retroBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFF0f0c29),
          Color(0xFF302b63),
          Color(0xFF24243e),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  Widget _glassContainer({
    required Widget child,
    double radius = 18,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1.3,
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  // ---------------------------- CARDS ----------------------------

  Widget _paintingCard(Map<String, dynamic> painting) {
    final profile = painting['profiles'] ?? {};

    return _glassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: painting['image_url'] ?? '',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 160,
                    color: Colors.white12,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 1),
                    ),
                  ),
                ),
              ),

              // category badge
              Positioned(
                top: 10,
                left: 10,
                child: _glassContainer(
                  radius: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    painting['category'] ?? 'Art',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),

              // like button
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => _handleLikePainting(painting['id']),
                  child: _glassContainer(
                    radius: 20,
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      painting['is_liked'] ? Icons.favorite : Icons.favorite_border,
                      color: painting['is_liked'] ? Colors.pink : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  painting['title'] ?? "Untitled",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  "by ${profile['display_name'] ?? profile['username'] ?? 'Unknown'}",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (painting['price'] != null)
                      Text(
                        "₹${painting['price']}",
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      "${painting['likes_count']} likes",
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _artistCard(Map<String, dynamic> artist) {
    return GestureDetector(
      onTap: () => context.push('/public-profile/${artist['id']}'),
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.purpleAccent,
                  backgroundImage: artist['profile_picture_url'] != null
                      ? CachedNetworkImageProvider(artist['profile_picture_url'])
                      : null,
                  child: artist['profile_picture_url'] == null
                      ? Text(
                          (artist['display_name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              artist['display_name'] ?? artist['username'] ?? 'Unknown',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "${artist['followers_count'] ?? 0} followers",
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(Map<String, String> cat) {
    final color = Color(int.parse(cat['color']!.substring(1), radix: 16) + 0xFF000000);

    return _glassContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(cat['icon']!, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(
            cat['name']!,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------- BUILD ----------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _retroAppBar(),
      body: Container(
        decoration: _retroBackground(),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.purpleAccent),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SEARCH BAR
                      _glassContainer(
                        radius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Search artists, creators, artworks...",
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: Colors.white54),
                          ),
                          onChanged: (value) {
                            setState(() => _searchTerm = value);
                            _searchArtists(value);
                          },
                        ),
                      ),

                      const SizedBox(height: 28),

                      // SEARCH RESULTS OR FEATURED ARTISTS
                      if (_searchTerm.trim().isNotEmpty &&
                          _searchResults.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "🔍 Search Results",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _searchResults.length,
                                itemBuilder: (_, i) =>
                                    _artistCard(_searchResults[i]),
                              ),
                            ),
                          ],
                        )
                      else if (_featuredArtists.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "⭐ Featured Artists",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _featuredArtists.length,
                                itemBuilder: (_, i) =>
                                    _artistCard(_featuredArtists[i]),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 28),

                      // CATEGORIES
                      const Text(
                        "🎯 Browse by Category",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (_, i) =>
                            _categoryCard(_categories[i]),
                      ),

                      const SizedBox(height: 28),

                      // RECENT ARTWORK
                      const Text(
                        "🎨 Recent Artwork",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      _paintings.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text(
                                  "No artwork yet",
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ),
                            )
                          : GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _paintings.length,
                              itemBuilder: (_, i) =>
                                  _paintingCard(_paintings[i]),
                            ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
