import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  bool _menuVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchThreads(0, false);
    _scrollController.addListener(_onScroll);
  }

  void _toggleMenu() {
    setState(() => _menuVisible = !_menuVisible);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _page++;
    });
    await _fetchThreads(_page, true);
  }

  Future<void> _fetchThreads(int page, bool append) async {
    if (!append) setState(() => _loading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        setState(() {
          _threads = [];
          _loading = false;
        });
        return;
      }

      const pageSize = 20;
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final response = await _supabase
          .from('community_posts')
          .select('*')
          .order('created_at', ascending: false)
          .range(from, to);

      if (response.isEmpty) {
        setState(() {
          if (!append) _threads = [];
          _hasMore = false;
          _loading = false;
          _loadingMore = false;
        });
        return;
      }

      final threadsData = List<Map<String, dynamic>>.from(response);
      final authorIds =
          threadsData.map((t) => t['author_id'] as String).toSet().toList();

      final profilesResponse = await _supabase
          .from('profiles')
          .select(
              'id, username, display_name, profile_picture_url, is_verified, artist_type')
          .inFilter('id', authorIds);

      final profilesData = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (var p in profilesData) p['id']: p};

      final threadsWithStats = await Future.wait(
        threadsData.map((thread) async {
          final likesResponse = await _supabase
              .from('post_likes')
              .select('id')
              .eq('post_id', thread['id']);

          final commentsResponse = await _supabase
              .from('post_comments')
              .select('id')
              .eq('post_id', thread['id']);

          bool isLiked = false;
          final userId = user.id;
          if (userId != null) {
            final userLikeResponse = await _supabase
                .from('post_likes')
                .select('id')
                .eq('post_id', thread['id'])
                .eq('user_id', userId)
                .maybeSingle();
            isLiked = userLikeResponse != null;
          }

          return {
            ...thread,
            'author': profilesMap[thread['author_id']] ?? {},
            'likes_count': likesResponse.length,
            'comments_count': commentsResponse.length,
            'is_liked': isLiked,
            'images': thread['images'] != null
                ? List<String>.from(thread['images'])
                : <String>[],
          };
        }),
      );

      setState(() {
        if (append) {
          _threads = [..._threads, ...threadsWithStats];
        } else {
          _threads = threadsWithStats;
        }
        _hasMore = threadsData.length == pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _threads = [];
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _handleLikeThread(String threadId) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like')),
      );
      return;
    }

    final index = _threads.indexWhere((t) => t['id'] == threadId);
    if (index == -1) return;

    final thread = _threads[index];
    final wasLiked = thread['is_liked'];

    setState(() {
      _threads[index] = {
        ...thread,
        'is_liked': !wasLiked,
        'likes_count':
            (thread['likes_count'] as int) + (wasLiked ? -1 : 1),
      };
    });

    try {
      if (wasLiked) {
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', threadId)
            .eq('user_id', user.id);
      } else {
        await _supabase.from('post_likes').insert({
          'post_id': threadId,
          'user_id': user.id,
        });
      }
    } catch (e) {
      setState(() => _threads[index] = thread);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildRetroAppBar(user),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0f0c29),
                  Color(0xFF302b63),
                  Color(0xFF24243e),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent),
                )
              : _threads.isEmpty
                  ? _buildEmptyRetroState()
                  : RefreshIndicator(
                      onRefresh: () => _fetchThreads(0, false),
                      color: Colors.purpleAccent,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _threads.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _threads.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.purpleAccent,
                                ),
                              ),
                            );
                          }
                          return _buildRetroThreadCard(_threads[index]);
                        },
                      ),
                    ),

          _buildFloatingMenu(),
        ],
      ),
    );
  }

  // ------------------------ RETRO UI COMPONENTS ------------------------

  PreferredSizeWidget _buildRetroAppBar(user) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.black.withOpacity(0.4),
      centerTitle: true,
      title: const Text(
        'Artयुग',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      leading: user != null
          ? GestureDetector(
              onTap: () => context.push('/profile'),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.purpleAccent,
                  child: user.userMetadata?['avatar_url'] != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.userMetadata!['avatar_url'],
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.white),
                ),
              ),
            )
          : null,
      actions: [
        if (user != null)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () => context.push('/messages'),
          ),
      ],
    );
  }

  Widget _buildRetroThreadCard(Map<String, dynamic> thread) {
    final author = thread['author'];
    final images = thread['images'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.4),
          width: 1.5,
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThreadHeader(author, thread),
                const SizedBox(height: 10),

                if (thread['title'] != null)
                  Text(
                    thread['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                if (thread['content'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      thread['content'],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ),

                if (images != null && images.isNotEmpty && images[0] is String && (images[0] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: images[0] as String,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[800],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[800],
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                _buildThreadActions(thread),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadHeader(author, thread) {
    final displayName = (author != null && author['display_name'] != null && (author['display_name'] as String).isNotEmpty)
        ? author['display_name']
        : (author != null && author['username'] != null && (author['username'] as String).isNotEmpty)
            ? author['username']
            : 'Unknown';
    final profilePicUrl = author != null ? author['profile_picture_url'] : null;
    final authorId = author != null ? author['id'] : null;

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (authorId != null) {
              context.push('/public-profile/$authorId');
            }
          },
          child: CircleAvatar(
            backgroundColor: Colors.purpleAccent,
            backgroundImage: profilePicUrl != null && profilePicUrl is String && profilePicUrl.isNotEmpty
                ? CachedNetworkImageProvider(profilePicUrl)
                : null,
            child: (profilePicUrl == null || (profilePicUrl is String && profilePicUrl.isEmpty))
                ? Text(
                    displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _formatDate(thread['created_at']),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThreadActions(Map<String, dynamic> thread) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                thread['is_liked'] ? Icons.favorite : Icons.favorite_border,
                color: Colors.pinkAccent,
              ),
              onPressed: () => _handleLikeThread(thread['id']),
            ),
            Text(
              '${thread['likes_count']}',
              style: const TextStyle(color: Colors.white70),
            )
          ],
        ),
        Row(
          children: [
            Icon(Icons.comment_outlined, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              '${thread['comments_count']}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const Icon(Icons.share_outlined, color: Colors.white70),
      ],
    );
  }

  Widget _buildFloatingMenu() {
    return Positioned(
      right: 20,
      bottom: 40,
      child: Column(
        children: [
          if (_menuVisible) ...[
            _retroMenuItem(Icons.shopping_cart, "Cart"),
            const SizedBox(height: 12),
            _retroMenuItem(Icons.diamond, "Premium"),
            const SizedBox(height: 12),
            _retroMenuItem(Icons.image, "NFT"),
            const SizedBox(height: 12),
            _retroMenuItem(Icons.settings, "Settings"),
            const SizedBox(height: 12),
            _retroMenuItem(Icons.notifications, "Alerts"),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            backgroundColor: Colors.purpleAccent,
            onPressed: _toggleMenu,
            child: Icon(
              _menuVisible ? Icons.close : Icons.menu,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _retroMenuItem(IconData icon, String label) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.purpleAccent.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.purpleAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRetroState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("🎛️", style: TextStyle(fontSize: 60)),
          SizedBox(height: 16),
          Text(
            "No threads yet",
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            "Start the retro vibe!",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) return '${difference.inMinutes}m ago';
        return '${difference.inHours}h ago';
      }
      if (difference.inDays < 7) return '${difference.inDays}d ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
