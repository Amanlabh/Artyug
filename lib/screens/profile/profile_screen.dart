
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _paintings = [];
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  String _activeTab = 'gallery';
  bool _isFollowing = false;
  bool _followLoading = false;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
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
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();

      setState(() {
        _profile = response as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchPaintings(String userId) async {
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
          .eq('artist_id', userId)
          .order('created_at', ascending: false);

      final paintingsData = List<Map<String, dynamic>>.from(response);

      final paintingsWithLikes = await Future.wait(
        paintingsData.map((painting) async {
          final likesResponse = await _supabase
              .from('painting_likes')
              .select('id')
              .eq('painting_id', painting['id']);

          final likesCount = (likesResponse as List).length;

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
      });
    } catch (e) {
      setState(() {
        _paintings = [];
      });
    }
  }

  Future<void> _fetchThreads(String userId) async {
    try {
      final response = await _supabase
          .from('community_posts')
          .select('*')
          .eq('author_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _threads = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        _threads = [];
      });
    }
  }

  Future<void> _fetchFollowStats(String userId) async {
    try {
      final followersResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('following_id', userId);

      final followingResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', userId);

      setState(() {
        _followersCount = (followersResponse as List).length;
        _followingCount = (followingResponse as List).length;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  // ----------------- DN3 THEME HELPERS -----------------

  Widget glassContainer({required Widget child, double radius = 20}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.purpleAccent.withOpacity(0.35),
              width: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget neonText(String text,
      {double size = 14, FontWeight weight = FontWeight.w600}) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.purpleAccent,
        fontSize: size,
        fontWeight: weight,
      ),
    );
  }

  // ----------------- UI COMPONENTS (DN3) -----------------

  Widget _buildPaintingItem(Map<String, dynamic> painting) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xff0f0f0f),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: painting['image_url'] != null
                ? CachedNetworkImage(
                    imageUrl: painting['image_url'] as String,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey[850],
                    child: const Center(
                      child: Text("🎨", style: TextStyle(fontSize: 48)),
                    ),
                  ),
          ),

          // Likes badge
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.purpleAccent.withOpacity(0.45), width: 1),
              ),
              child: Row(
                children: [
                  Text(
                    painting['is_liked'] == true ? "❤️" : "🤍",
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${painting['likes_count'] ?? 0}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadCard(Map<String, dynamic> thread) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: glassContainer(
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thread['title'] != null && thread['title'].toString().trim().isNotEmpty)
                Text(
                  thread['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              if (thread['content'] != null && thread['content'].toString().trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    thread['content'] as String,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),

              if (thread['images'] != null &&
                  thread['images'] is List &&
                  (thread['images'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: (thread['images'] as List).length,
                      itemBuilder: (context, index) => Container(
                        margin: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: (thread['images'] as List)[index] as String,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return glassContainer(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            neonText("About", size: 20),
            const SizedBox(height: 14),

            Text(
              _profile?['bio'] as String? ?? "No bio added.",
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem("Followers", _followersCount),
                _statItem("Following", _followingCount),
                _statItem("Artworks", _paintings.length),
              ],
            ),

            if (_profile?['artist_type'] != null) ...[
              const SizedBox(height: 24),
              neonText("Artist Type: ${''}${_profile!['artist_type']}")
            ],

            if (_profile?['location'] != null) ...[
              const SizedBox(height: 12),
              neonText("Location: ${_profile!['location']}")
            ],

            if (_profile?['website'] != null) ...[
              const SizedBox(height: 12),
              neonText("Website: ${_profile!['website']}")
            ],
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, int value) {
    return Column(
      children: [
        Text(
          "$value",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final active = _activeTab == tab;

    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.purpleAccent.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? Colors.purpleAccent
                : Colors.purpleAccent.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.purpleAccent : Colors.white60,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'gallery':
        return _paintings.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Text(
                  "🎨 No artwork yet",
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _paintings.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                ),
                itemBuilder: (_, i) => _buildPaintingItem(_paintings[i]),
              );

      case 'threads':
        return _threads.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Text(
                  "💭 No threads yet",
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                children:
                    _threads.map((t) => _buildThreadCard(t)).toList(),
              );

      case 'about':
        return _buildAboutSection();

      default:
        return const SizedBox();
    }
  }

  Widget _buildProfileHeader() {
    return glassContainer(
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.purpleAccent,
              backgroundImage: _profile?['profile_picture_url'] != null
                  ? CachedNetworkImageProvider(_profile!['profile_picture_url'] as String)
                  : null,
              child: _profile?['profile_picture_url'] == null
                  ? Text(
                      (_profile?['display_name'] ??
                              _profile?['username'] ??
                              "?")
                          .toString()[0]
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 34),
                    )
                  : null,
            ),

            const SizedBox(height: 14),

            // Name
            Text(
              _profile?['display_name'] ?? _profile?['username'] ?? "Unknown",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // Username
            Text(
              "@${_profile?['username'] ?? ''}",
              style: const TextStyle(color: Colors.white54),
            ),

            // Bio
            if (_profile?['bio'] != null) ...[
              const SizedBox(height: 14),
              Text(
                _profile!['bio'] as String,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 18),

            // Edit Button
            ElevatedButton(
              onPressed: () => context.push('/edit-profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                "Edit Profile",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8b5cf6)),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Profile not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff000000),

      appBar: AppBar(
        backgroundColor: const Color(0xff000000),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.purpleAccent),
            onPressed: () => context.push('/settings'),
          )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Glass header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _buildProfileHeader(),
            ),

            const SizedBox(height: 22),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton('gallery', 'Gallery')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTabButton('threads', 'Threads')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTabButton('about', 'About')),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tab content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }
}
