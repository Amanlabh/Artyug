import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../components/clickable_name.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _community;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _postsLoading = false;
  bool _isMember = false;
  int _memberCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCommunityData();
    _fetchPosts();
  }

  Future<void> _fetchCommunityData() async {
    setState(() => _loading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // Fetch community data
      final communityResponse = await _supabase
          .from('communities')
          .select('*')
          .eq('id', widget.communityId)
          .maybeSingle();

      if (communityResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Community not found')),
          );
          context.pop();
        }
        return;
      }

      // Fetch creator profile
      final creatorId = communityResponse['creator_id'] as String;
      final profileResponse = await _supabase
          .from('profiles')
          .select('id, username, display_name, profile_picture_url')
          .eq('id', creatorId)
          .maybeSingle();

      // Get member count
      final memberCountResponse = await _supabase
          .from('community_members')
          .select('id')
          .eq('community_id', widget.communityId);

      final memberCount = (memberCountResponse as List).length;

      // Check if user is a member
      final membershipResponse = await _supabase
          .from('community_members')
          .select('id')
          .eq('community_id', widget.communityId)
          .eq('user_id', user.id)
          .maybeSingle();

      final isMember = membershipResponse != null;

      setState(() {
        _community = {
          ...communityResponse,
          'profiles': profileResponse ?? {},
        };
        _memberCount = memberCount;
        _isMember = isMember;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading community: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _fetchPosts() async {
    setState(() => _postsLoading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        setState(() {
          _posts = [];
          _postsLoading = false;
        });
        return;
      }

      final response = await _supabase
          .from('community_posts')
          .select('*')
          .eq('community_id', widget.communityId)
          .order('created_at', ascending: false)
          .limit(50);

      if (response.isEmpty) {
        setState(() {
          _posts = [];
          _postsLoading = false;
        });
        return;
      }

      final postsData = List<Map<String, dynamic>>.from(response);
      final authorIds =
          postsData.map((p) => p['author_id'] as String).toSet().toList();

      final profilesResponse = await _supabase
          .from('profiles')
          .select(
              'id, username, display_name, profile_picture_url, is_verified, artist_type')
          .inFilter('id', authorIds);

      final profilesData = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (var p in profilesData) p['id']: p};

      final postsWithStats = await Future.wait(
        postsData.map((post) async {
          final likesResponse = await _supabase
              .from('post_likes')
              .select('id')
              .eq('post_id', post['id']);

          final commentsResponse = await _supabase
              .from('post_comments')
              .select('id')
              .eq('post_id', post['id']);

          bool isLiked = false;
          final userLikeResponse = await _supabase
              .from('post_likes')
              .select('id')
              .eq('post_id', post['id'])
              .eq('user_id', user.id)
              .maybeSingle();
          isLiked = userLikeResponse != null;

          return {
            ...post,
            'author': profilesMap[post['author_id']] ?? {},
            'likes_count': likesResponse.length,
            'comments_count': commentsResponse.length,
            'is_liked': isLiked,
            'images': post['images'] != null
                ? List<String>.from(post['images'])
                : <String>[],
          };
        }),
      );

      setState(() {
        _posts = postsWithStats;
        _postsLoading = false;
      });
    } catch (e) {
      setState(() {
        _posts = [];
        _postsLoading = false;
      });
    }
  }

  Future<void> _handleJoinLeave() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join communities')),
      );
      return;
    }

    try {
      if (_isMember) {
        // Leave community
        await _supabase
            .from('community_members')
            .delete()
            .eq('community_id', widget.communityId)
            .eq('user_id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the community')),
          );
        }
      } else {
        // Join community
        await _supabase.from('community_members').insert({
          'community_id': widget.communityId,
          'user_id': user.id,
          'role': 'member',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have joined the community!')),
          );
        }
      }

      _fetchCommunityData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${_isMember ? 'leave' : 'join'} community')),
        );
      }
    }
  }

  Future<void> _handleLikePost(String postId) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    final index = _posts.indexWhere((p) => p['id'] == postId);
    if (index == -1) return;

    final post = _posts[index];
    final wasLiked = post['is_liked'];

    setState(() {
      _posts[index] = {
        ...post,
        'is_liked': !wasLiked,
        'likes_count': (post['likes_count'] as int) + (wasLiked ? -1 : 1),
      };
    });

    try {
      if (wasLiked) {
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
      } else {
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
      }
    } catch (e) {
      setState(() => _posts[index] = post);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like')),
        );
      }
    }
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

  Widget _buildCommunityHeader() {
    if (_community == null) return const SizedBox();

    final profile = _community!['profiles'] ?? {};
    final creatorName = profile['display_name'] ?? profile['username'] ?? 'Unknown';

    return _glassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.2),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: _community!['cover_image_url'] != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: _community!['cover_image_url'],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.purpleAccent.withOpacity(0.2),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.purpleAccent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          (_community!['name'] ?? 'C')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ],
          ),

          // Community Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Community Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: _community!['cover_image_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: CachedNetworkImage(
                                imageUrl: _community!['cover_image_url'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                (_community!['name'] ?? 'C')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _community!['name'] ?? 'Community',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClickableName(
                            name: creatorName,
                            userId: profile['id'],
                            showPrefix: true,
                            textStyle: const TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_community!['description'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _community!['description'],
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.people, size: 18, color: Colors.purpleAccent),
                    const SizedBox(width: 6),
                    Text(
                      '$_memberCount member${_memberCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_isMember) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
                      const SizedBox(width: 6),
                      const Text(
                        'Joined',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _buildRetroButton(
                    onPressed: _handleJoinLeave,
                    text: _isMember ? 'Leave Community' : 'Join Community',
                    icon: _isMember ? Icons.exit_to_app : Icons.add,
                    isDanger: _isMember,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroButton({
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    bool isDanger = false,
  }) {
    Color buttonColor = isDanger ? Colors.red : Colors.purpleAccent;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: buttonColor.withOpacity(0.4),
          width: 1.5,
        ),
        gradient: LinearGradient(
          colors: [
            buttonColor,
            buttonColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final author = post['author'] ?? {};
    final images = post['images'] ?? <String>[];
    final authorName = author['display_name'] ?? author['username'] ?? 'Unknown';

    return _glassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.purpleAccent,
                backgroundImage: author['profile_picture_url'] != null
                    ? CachedNetworkImageProvider(author['profile_picture_url'])
                    : null,
                child: author['profile_picture_url'] == null
                    ? Text(
                        authorName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClickableName(
                      name: authorName,
                      userId: author['id'],
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (post['created_at'] != null)
                      Text(
                        _formatDate(post['created_at']),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Post Content
          if (post['title'] != null)
            Text(
              post['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

          if (post['content'] != null) ...[
            if (post['title'] != null) const SizedBox(height: 8),
            Text(
              post['content'],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],

          // Images
          if (images.isNotEmpty && images[0] is String && (images[0] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: images[0],
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: Colors.white12,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.purpleAccent,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              GestureDetector(
                onTap: () => _handleLikePost(post['id']),
                child: Row(
                  children: [
                    Icon(
                      post['is_liked'] ? Icons.favorite : Icons.favorite_border,
                      color: post['is_liked'] ? Colors.pink : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post['likes_count']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  const Icon(
                    Icons.comment_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${post['comments_count']}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black.withOpacity(0.4),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Community',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
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

          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            )
          else
            RefreshIndicator(
              onRefresh: () async {
                await _fetchCommunityData();
                await _fetchPosts();
              },
              color: Colors.purpleAccent,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCommunityHeader(),
                    const SizedBox(height: 24),
                    const Text(
                      'Posts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_postsLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: Colors.purpleAccent,
                          ),
                        ),
                      )
                    else if (_posts.isEmpty)
                      _glassContainer(
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.forum_outlined,
                                  size: 64,
                                  color: Colors.white54,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No posts yet',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Be the first to share something!',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ..._posts.map((post) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildPostCard(post),
                          )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


