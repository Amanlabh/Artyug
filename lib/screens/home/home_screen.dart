import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh threads when screen comes into focus (e.g., after upload)
    _fetchThreads(0, false);
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
          final userLikeResponse = await _supabase
              .from('post_likes')
              .select('id')
              .eq('post_id', thread['id'])
              .eq('user_id', userId)
              .maybeSingle();
          isLiked = userLikeResponse != null;

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

  Future<void> _ensureProfileExists(String userId) async {
    try {
      final profileCheck = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (profileCheck == null) {
        await _supabase.from('profiles').insert({
          'id': userId,
          'username': 'user_${userId.substring(0, 8)}',
          'display_name': 'User',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Profile check/creation error: $e');
    }
  }

  Future<void> _handleLikeThread(String threadId) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to like')),
        );
      }
      return;
    }

    final index = _threads.indexWhere((t) => t['id'] == threadId);
    if (index == -1) return;

    final thread = _threads[index];
    final wasLiked = thread['is_liked'];

    // Optimistic update
    setState(() {
      _threads[index] = {
        ...thread,
        'is_liked': !wasLiked,
        'likes_count': (thread['likes_count'] as int) + (wasLiked ? -1 : 1),
      };
    });

    try {
      if (wasLiked) {
        // First check if the like exists to avoid errors
        final likeCheck = await _supabase
            .from('post_likes')
            .select('id')
            .eq('post_id', threadId)
            .eq('user_id', user.id)
            .maybeSingle();

        if (likeCheck != null) {
          await _supabase
              .from('post_likes')
              .delete()
              .eq('post_id', threadId)
              .eq('user_id', user.id);
        } else {
          // Like doesn't exist, revert the optimistic update
          throw Exception('Like not found');
        }
      } else {
        // For new likes, try to insert
        await _supabase.from('post_likes').insert({
          'post_id': threadId,
          'user_id': user.id,
        }).select().single();
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() => _threads[index] = thread);
        
        String errorMessage = 'Failed to update like';
        if (e is PostgrestException) {
          errorMessage = 'Database error: ${e.message}';
        } else if (e is Exception) {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        debugPrint('Like error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _showCommentDialog(String postId, String postTitle, bool isDarkMode) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment')),
        );
      }
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => _CommentDialog(
        postId: postId,
        postTitle: postTitle,
        isDarkMode: isDarkMode,
        user: user,
        supabase: _supabase,
        onCommentAdded: () => _fetchThreads(0, false),
        formatDate: _formatDate,
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: _buildRetroAppBar(user, isDarkMode),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: isDarkMode
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF0f0c29),
                        Color(0xFF302b63),
                        Color(0xFF24243e),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFf5f5f5),
                        Color(0xFFe8e8e8),
                        Color(0xFFfafafa),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            ),
          ),

          _loading
              ? Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent),
                )
              : _threads.isEmpty
                  ? _buildEmptyRetroState(isDarkMode)
                  : RefreshIndicator(
                      onRefresh: () => _fetchThreads(0, false),
                      color: Colors.purpleAccent,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _threads.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _threads.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.purpleAccent,
                                ),
                              ),
                            );
                          }
                          return _buildRetroThreadCard(_threads[index], isDarkMode);
                        },
                      ),
                    ),

          _buildFloatingMenu(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildRetroAppBar(user, bool isDarkMode) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode
          ? Colors.black.withOpacity(0.4)
          : Colors.white.withOpacity(0.9),
      centerTitle: true,
      title: Text(
        'Artयुग',
        style: TextStyle(
          color: isDarkMode ? Colors.white : const Color(0xFF1f2937),
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
            icon: Icon(
              Icons.chat_bubble_outline,
              color: isDarkMode ? Colors.white : const Color(0xFF1f2937),
            ),
            onPressed: () => context.push('/messages'),
          ),
      ],
    );
  }

  Widget _buildRetroThreadCard(Map<String, dynamic> thread, bool isDarkMode) {
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
          colors: isDarkMode
              ? [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.95),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(isDarkMode ? 0.25 : 0.15),
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
                _buildThreadHeader(author, thread, isDarkMode),
                const SizedBox(height: 10),

                if (thread['title'] != null)
                  Text(
                    thread['title'],
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : const Color(0xFF1f2937),
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
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : const Color(0xFF6b7280),
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
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                _buildThreadActions(thread, isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadHeader(author, thread, bool isDarkMode) {
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
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF1f2937),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _formatDate(thread['created_at']),
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : const Color(0xFF6b7280),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThreadActions(Map<String, dynamic> thread, bool isDarkMode) {
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
              style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF6b7280)),
            )
          ],
        ),
        GestureDetector(
          onTap: () => _showCommentDialog(thread['id'], thread['title'] ?? 'Post', isDarkMode),
          child: Row(
            children: [
              Icon(Icons.comment_outlined, color: isDarkMode ? Colors.white70 : const Color(0xFF6b7280)),
              const SizedBox(width: 4),
              Text(
                '${thread['comments_count']}',
                style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF6b7280)),
              ),
            ],
          ),
        ),
        Icon(Icons.share_outlined, color: isDarkMode ? Colors.white70 : const Color(0xFF6b7280)),
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
      onTap: () {
        _toggleMenu();
        if (label == "NFT") {
          context.push('/nft');
        } else if (label == "Settings") {
          context.push('/settings');
        } else if (label == "Premium") {
          context.push('/premium');
        } else if (label == "Alerts") {
          context.push('/notifications');
        }
      },
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

  Widget _buildEmptyRetroState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("🎛️", style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            "No threads yet",
            style: TextStyle(
              fontSize: 20,
              color: isDarkMode ? Colors.white : const Color(0xFF1f2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start the retro vibe!",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : const Color(0xFF6b7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentDialog extends StatefulWidget {
  final String postId;
  final String postTitle;
  final bool isDarkMode;
  final User user;
  final SupabaseClient supabase;
  final VoidCallback onCommentAdded;
  final String Function(String) formatDate;

  const _CommentDialog({
    required this.postId,
    required this.postTitle,
    required this.isDarkMode,
    required this.user,
    required this.supabase,
    required this.onCommentAdded,
    required this.formatDate,
  });

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final commentsResponse = await widget.supabase
          .from('post_comments')
          .select('id, content, created_at, author_id')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (commentsResponse.isNotEmpty) {
        final authorIds = (commentsResponse as List)
            .map((c) => c['author_id'] as String)
            .toSet()
            .toList();

        final profilesResponse = await widget.supabase
            .from('profiles')
            .select('id, username, display_name, profile_picture_url')
            .inFilter('id', authorIds);

        final profilesData = List<Map<String, dynamic>>.from(profilesResponse);
        final profilesMap = {for (var p in profilesData) p['id']: p};

        setState(() {
          _comments = (commentsResponse as List<dynamic>).map<Map<String, dynamic>>((comment) {
            final author = profilesMap[comment['author_id']] ?? {};
            return {
              ...comment as Map<String, dynamic>,
              'author': author,
            };
          }).toList();
        });
      } else {
        setState(() => _comments = []);
      }
    } catch (e) {
      setState(() => _comments = []);
    } finally {
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _postComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() => _postingComment = true);
    
    try {
      // First verify the post exists
      final postCheck = await widget.supabase
          .from('community_posts')
          .select('id')
          .eq('id', widget.postId)
          .maybeSingle();

      if (postCheck == null) {
        throw Exception('Post not found');
      }

      // Try to insert the comment
      await widget.supabase.from('post_comments').insert({
        'post_id': widget.postId,
        'author_id': widget.user.id,
        'content': comment,
      }).select().single();

      _commentController.clear();
      await _loadComments();
      widget.onCommentAdded();
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to post comment';
        
        if (e is PostgrestException) {
          errorMessage = 'Database error: ${e.message}';
          
          // Handle specific error cases
          if (e.message.contains('violates foreign key constraint')) {
            if (e.message.contains('post_id')) {
              errorMessage = 'Post not found';
            } else if (e.message.contains('author_id')) {
              errorMessage = 'User profile not found';
            }
          }
        } else if (e is Exception) {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        debugPrint('Comment error: $e');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _postingComment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.isDarkMode ? const Color(0xFF24243e) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF1f2937),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: widget.isDarkMode ? Colors.white70 : const Color(0xFF6b7280),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Comments List
            Expanded(
              child: _loadingComments
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.purpleAccent,
                      ),
                    )
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'No comments yet',
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : const Color(0xFF6b7280),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final author = comment['author'] as Map<String, dynamic>?;
                            final authorName = author?['display_name'] ??
                                author?['username'] ??
                                'Unknown';
                            final content = comment['content'] as String? ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.purpleAccent,
                                    backgroundImage: author?['profile_picture_url'] != null
                                        ? CachedNetworkImageProvider(
                                            author!['profile_picture_url'],
                                          )
                                        : null,
                                    child: author?['profile_picture_url'] == null
                                        ? Text(
                                            authorName[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          authorName,
                                          style: TextStyle(
                                            color: widget.isDarkMode
                                                ? Colors.white
                                                : const Color(0xFF1f2937),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          content,
                                          style: TextStyle(
                                            color: widget.isDarkMode
                                                ? Colors.white70
                                                : const Color(0xFF6b7280),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.formatDate(comment['created_at']),
                                          style: TextStyle(
                                            color: widget.isDarkMode
                                                ? Colors.white60
                                                : const Color(0xFF9ca3af),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Comment Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: widget.isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF1f2937),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.white60
                              : const Color(0xFF9ca3af),
                        ),
                        filled: true,
                        fillColor: widget.isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _postingComment ? null : _postComment,
                    icon: _postingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.purpleAccent,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.purpleAccent),
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
