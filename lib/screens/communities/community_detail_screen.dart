import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../components/clickable_name.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

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
  bool _isCreator = false;
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

      final creatorId = communityResponse['creator_id'] as String;
      final profileResponse = await _supabase
          .from('profiles')
          .select('id, username, display_name, profile_picture_url')
          .eq('id', creatorId)
          .maybeSingle();

      final memberCountResponse = await _supabase
          .from('community_members')
          .select('id')
          .eq('community_id', widget.communityId);

      final membershipResponse = await _supabase
          .from('community_members')
          .select('id')
          .eq('community_id', widget.communityId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _community = {
          ...communityResponse,
          'profiles': profileResponse ?? {},
        };
        _memberCount = (memberCountResponse as List).length;
        _isMember = membershipResponse != null;
        _isCreator = communityResponse['creator_id'] == user.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading community: ${e.toString()}')),
      );
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
            'id, username, display_name, profile_picture_url, is_verified, artist_type',
          )
          .inFilter('id', authorIds);

      final profilesData = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (final p in profilesData) p['id']: p};

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

          final userLikeResponse = await _supabase
              .from('post_likes')
              .select('id')
              .eq('post_id', post['id'])
              .eq('user_id', user.id)
              .maybeSingle();

          return {
            ...post,
            'author': profilesMap[post['author_id']] ?? {},
            'likes_count': likesResponse.length,
            'comments_count': commentsResponse.length,
            'is_liked': userLikeResponse != null,
            'images': post['images'] != null
                ? List<String>.from(post['images'])
                : <String>[],
          };
        }),
      );

      if (!mounted) return;
      setState(() {
        _posts = postsWithStats;
        _postsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to ${_isMember ? 'leave' : 'join'} community',
          ),
        ),
      );
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
    final wasLiked = post['is_liked'] as bool? ?? false;

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
    } catch (_) {
      setState(() => _posts[index] = post);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update like')),
      );
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

  Widget _surfaceCard({
    required Widget child,
    double radius = 18,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  Widget _metaPill({
    required IconData icon,
    required String label,
    bool accent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: accent ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent ? AppColors.primary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String text,
    required bool filled,
    IconData? icon,
  }) {
    final background = filled ? AppColors.primary : AppColors.surfaceHigh;
    final foreground = filled ? Colors.white : AppColors.textPrimary;
    final side = filled ? AppColors.primary : AppColors.borderStrong;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: side),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityHeader() {
    if (_community == null) return const SizedBox();

    final profile = _community!['profiles'] ?? {};
    final creatorName =
        profile['display_name'] ?? profile['username'] ?? 'Unknown';
    final coverUrl = (_community!['cover_image_url'] as String?)?.trim();
    final initials = (_community!['name'] ?? 'C')[0].toUpperCase();

    return _surfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 176,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceHigh,
                      AppColors.surfaceVariant,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.surfaceHigh,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surfaceHigh,
                          ),
                        ),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.32),
                              AppColors.surfaceHigh,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.48),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8448), AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: coverUrl != null && coverUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: CachedNetworkImage(
                                imageUrl: coverUrl,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _community!['name'] ?? 'Community',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Official guild space',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.95,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClickableName(
                  name: creatorName,
                  userId: profile['id'],
                  showPrefix: true,
                  textStyle: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_community!['description'] != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _community!['description'],
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaPill(
                      icon: Icons.people_outline_rounded,
                      label:
                          '$_memberCount member${_memberCount == 1 ? '' : 's'}',
                    ),
                    if (_isMember)
                      _metaPill(
                        icon: Icons.check_circle_rounded,
                        label: 'Joined',
                        accent: true,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        onPressed: _handleJoinLeave,
                        text: _isMember ? 'Leave community' : 'Join community',
                        icon: _isMember
                            ? Icons.logout_rounded
                            : Icons.add_rounded,
                        filled: !_isMember,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        onPressed: () {
                          final n = Uri.encodeComponent(
                            (_community!['name'] as String?) ?? 'Guild',
                          );
                          context.push(
                            '/community-chat/${widget.communityId}?name=$n',
                          );
                        },
                        text: 'Open main chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        filled: false,
                      ),
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

  Widget _buildPostCard(Map<String, dynamic> post) {
    final author = post['author'] ?? {};
    final images = post['images'] ?? <String>[];
    final authorName =
        author['display_name'] ?? author['username'] ?? 'Unknown';

    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                backgroundImage: author['profile_picture_url'] != null
                    ? CachedNetworkImageProvider(author['profile_picture_url'])
                    : null,
                child: author['profile_picture_url'] == null
                    ? Text(
                        authorName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
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
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (post['created_at'] != null)
                      Text(
                        _formatDate(post['created_at']),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (post['title'] != null)
            Text(
              post['title'],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (post['content'] != null) ...[
            if (post['title'] != null) const SizedBox(height: 8),
            Text(
              post['content'],
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
          if (images.isNotEmpty &&
              images[0] is String &&
              (images[0] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: images[0],
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: AppColors.surfaceHigh,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.surfaceHigh,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.textTertiary,
                    size: 34,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => _handleLikePost(post['id']),
                child: Row(
                  children: [
                    Icon(
                      post['is_liked'] == true
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: post['is_liked'] == true
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post['likes_count']}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${post['comments_count']}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
    final title = (_community?['name'] as String?) ?? 'Community';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isCreator)
            IconButton(
              tooltip: 'Edit community',
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.textPrimary,
              ),
              onPressed: () async {
                final refreshed = await context.push<bool>(
                  '/edit-community/${widget.communityId}',
                );
                if (refreshed == true && mounted) {
                  _fetchCommunityData();
                  _fetchPosts();
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: AppColors.background),
          ),
          Positioned(
            top: -90,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else
            RefreshIndicator(
              onRefresh: () async {
                await _fetchCommunityData();
                await _fetchPosts();
              },
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCommunityHeader(),
                    const SizedBox(height: 24),
                    const Text(
                      'Posts',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_postsLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (_posts.isEmpty)
                      _surfaceCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(36),
                            child: Column(
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Icon(
                                    Icons.forum_outlined,
                                    size: 34,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No posts yet',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Be the first to share something with this guild.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ..._posts.map(
                        (post) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildPostCard(post),
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
}
