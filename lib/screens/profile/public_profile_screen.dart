import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
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
    
    await Future.wait([
      _fetchProfile(widget.userId),
      _fetchPaintings(widget.userId),
      _fetchThreads(widget.userId),
      _fetchFollowStats(widget.userId),
    ]);

    if (user != null && user.id != widget.userId) {
      await _checkFollowStatus();
    }
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

  Future<void> _checkFollowStatus() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', user.id)
          .eq('following_id', widget.userId)
          .maybeSingle();

      setState(() {
        _isFollowing = response != null;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _handleFollow() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to follow users')),
      );
      return;
    }

    if (user.id == widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot follow yourself')),
      );
      return;
    }

    setState(() => _followLoading = true);

    try {
      if (_isFollowing) {
        // Unfollow
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', user.id)
            .eq('following_id', widget.userId);

        setState(() {
          _isFollowing = false;
          _followersCount--;
        });
      } else {
        // Follow
        await _supabase
            .from('follows')
            .insert({
              'follower_id': user.id,
              'following_id': widget.userId,
            });

        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update follow status')),
      );
    } finally {
      setState(() => _followLoading = false);
    }
  }

  Future<void> _handleMessage() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages')),
      );
      return;
    }

    if (user.id == widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself')),
      );
      return;
    }

    context.push('/chat/${widget.userId}');
  }

  Widget _buildPaintingItem(Map<String, dynamic> painting) {
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 24,
      margin: const EdgeInsets.all(8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: painting['image_url'] != null
                ? CachedNetworkImage(
                    imageUrl: painting['image_url'] as String,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(child: Text('🎨', style: TextStyle(fontSize: 40))),
                  ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    painting['is_liked'] == true ? '❤️' : '🤍',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${painting['likes_count'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadCard(Map<String, dynamic> thread) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thread['title'] != null && (thread['title'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  thread['title'] as String,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (thread['content'] != null && (thread['content'] as String).isNotEmpty)
              Text(
                thread['content'] as String,
                style: const TextStyle(fontSize: 14),
              ),
            if (thread['images'] != null && (thread['images'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (thread['images'] as List).length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: (thread['images'] as List)[index] as String,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'gallery':
        return _paintings.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Text('🎨', style: TextStyle(fontSize: 60)),
                      SizedBox(height: 16),
                      Text(
                        'No artwork yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                ),
                itemCount: _paintings.length,
                itemBuilder: (context, index) => _buildPaintingItem(_paintings[index]),
              );
      case 'threads':
        return _threads.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Text('💭', style: TextStyle(fontSize: 60)),
                      SizedBox(height: 16),
                      Text(
                        'No threads yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _threads.length,
                itemBuilder: (context, index) => _buildThreadCard(_threads[index]),
              );
      case 'about':
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _profile?['bio'] as String? ?? 'No bio added yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: _profile?['bio'] != null ? Colors.black87 : Colors.grey,
                    fontStyle: _profile?['bio'] == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$_followersCount',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Followers', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '$_followingCount',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Following', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${_paintings.length}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Artworks', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                if (_profile?['artist_type'] != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('Artist Type: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_profile!['artist_type'] as String),
                    ],
                  ),
                ],
                if (_profile?['location'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Location: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_profile!['location'] as String),
                    ],
                  ),
                ],
                if (_profile?['website'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Website: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_profile!['website'] as String),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final isOwnProfile = user?.id == widget.userId;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF8b5cf6),
                    backgroundImage: _profile!['profile_picture_url'] != null
                        ? CachedNetworkImageProvider(
                            _profile!['profile_picture_url'] as String)
                        : null,
                    child: _profile!['profile_picture_url'] == null
                        ? Text(
                            (_profile!['display_name'] as String? ??
                                    _profile!['username'] as String? ??
                                    '?')[0]
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 32),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _profile!['display_name'] as String? ??
                            _profile!['username'] as String? ??
                            'Unknown',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_profile!['is_verified'] == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1DA1F2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '✓',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${_profile!['username'] ?? ''}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (_profile!['bio'] != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _profile!['bio'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Action Buttons
                  if (isOwnProfile)
                    ElevatedButton(
                      onPressed: () => context.push('/edit-profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8b5cf6),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _followLoading ? null : _handleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? Colors.grey[300]
                                : const Color(0xFF8b5cf6),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: _followLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _handleMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10b981),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text('Message', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton('gallery', 'Gallery'),
                  ),
                  Expanded(
                    child: _buildTabButton('threads', 'Threads'),
                  ),
                  Expanded(
                    child: _buildTabButton('about', 'About'),
                  ),
                ],
              ),
            ),
            // Tab Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF8b5cf6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
