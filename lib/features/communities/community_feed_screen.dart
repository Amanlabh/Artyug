import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Community Feed Screen
// Shows posts from a specific community / guild.
// Supports: creating posts, liking, replying to posts.
// Design: cream/orange/black editorial-brutalist.
// ─────────────────────────────────────────────────────────────────────────────

class CommunityFeedScreen extends StatefulWidget {
  final String communityId;
  final String? communityName;

  const CommunityFeedScreen({
    super.key,
    required this.communityId,
    this.communityName,
  });

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final _supabase = Supabase.instance.client;
  final _scrollCtrl = ScrollController();
  final _postCtrl = TextEditingController();

  List<CommunityPost> _posts = [];
  bool _loading = true;
  bool _posting = false;
  bool _showCompose = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      // Try community_posts table, fall back to demo data
      final res = await _supabase
          .from('community_posts')
          .select('''
            id, content, image_url, created_at, like_count, reply_count,
            author:profiles!author_id(id, display_name, username, profile_picture_url)
          ''')
          .eq('community_id', widget.communityId)
          .order('created_at', ascending: false)
          .limit(30);

      final posts = (res as List).map((j) {
        final author = j['author'] as Map<String, dynamic>?;
        return CommunityPost(
          id: j['id'] as String,
          content: j['content'] as String? ?? '',
          imageUrl: j['image_url'] as String?,
          createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
              DateTime.now(),
          likeCount: j['like_count'] as int? ?? 0,
          replyCount: j['reply_count'] as int? ?? 0,
          authorId: author?['id'] as String? ?? '',
          authorName: author?['display_name'] as String? ??
              author?['username'] as String? ??
              'Artist',
          authorUsername: author?['username'] as String? ?? '',
          authorAvatarUrl: author?['profile_picture_url'] as String?,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
        });
      }
    } catch (_) {
      // Demo fallback
      if (mounted) {
        setState(() {
          _posts = CommunityPost.demoData(widget.communityId);
          _loading = false;
        });
      }
    }
  }

  Future<void> _createPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _posting = true);
    try {
      await _supabase.from('community_posts').insert({
        'community_id': widget.communityId,
        'author_id': user.id,
        'content': text,
        'like_count': 0,
        'reply_count': 0,
      });
      _postCtrl.clear();
      setState(() { _showCompose = false; _posting = false; });
      await _loadPosts();
    } catch (_) {
      // Optimistic fallback: show the post in UI immediately
      final newPost = CommunityPost(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        content: text,
        createdAt: DateTime.now(),
        likeCount: 0,
        replyCount: 0,
        authorId: user.id,
        authorName: user.email?.split('@')[0] ?? 'You',
        authorUsername: '',
        authorAvatarUrl: null,
      );
      _postCtrl.clear();
      setState(() {
        _posts.insert(0, newPost);
        _showCompose = false;
        _posting = false;
      });
    }
  }

  Future<void> _toggleLike(CommunityPost post) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() {
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx >= 0) {
        final old = _posts[idx];
        _posts[idx] = old.copyWith(
          likeCount: old.liked ? old.likeCount - 1 : old.likeCount + 1,
          liked: !old.liked,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final communityName = widget.communityName ?? 'Guild';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              communityName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'Community Feed',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _loadPosts,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      body: Column(
        children: [
          // ── Compose bar ───────────────────────────────────────────
          _ComposeBar(
            controller: _postCtrl,
            expanded: _showCompose,
            posting: _posting,
            onTap: () => setState(() => _showCompose = true),
            onDismiss: () {
              setState(() => _showCompose = false);
              _postCtrl.clear();
            },
            onPost: _createPost,
          ),

          // ── Posts ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2))
                : _posts.isEmpty
                    ? _EmptyFeed(
                        onCompose: () => setState(() => _showCompose = true))
                    : RefreshIndicator(
                        onRefresh: _loadPosts,
                        color: AppColors.primary,
                        child: ListView.separated(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _PostCard(
                            post: _posts[i],
                            onLike: () => _toggleLike(_posts[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _showCompose
          ? null
          : FloatingActionButton(
              onPressed: () => setState(() => _showCompose = true),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              child: const Icon(Icons.edit_outlined),
            ),
    );
  }
}

// ─── Compose Bar ──────────────────────────────────────────────────────────────

class _ComposeBar extends StatelessWidget {
  final TextEditingController controller;
  final bool expanded;
  final bool posting;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback onPost;

  const _ComposeBar({
    required this.controller,
    required this.expanded,
    required this.posting,
    required this.onTap,
    required this.onDismiss,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 1000,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Share something with the guild...',
                    hintStyle: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 14),
                    border: InputBorder.none,
                    counterStyle: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: posting ? null : onPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: posting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Post',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            )
          : GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        color: AppColors.textTertiary, size: 16),
                    SizedBox(width: 10),
                    Text(
                      'Share something with the guild...',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;

  const _PostCard({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(post.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author row ─────────────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/public-profile/${post.authorId}'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: post.authorAvatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: post.authorAvatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _AuthorInitial(post.authorName),
                          ),
                        )
                      : _AuthorInitial(post.authorName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context
                          .push('/public-profile/${post.authorId}'),
                      child: Text(
                        post.authorName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Options dots (future: edit/delete if own post)
              Icon(Icons.more_horiz_rounded,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),

          const SizedBox(height: 12),

          // ── Content ────────────────────────────────────────────────
          Text(
            post.content,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          // ── Image (if any) ─────────────────────────────────────────
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    height: 200, color: AppColors.surfaceVariant),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

          // ── Actions ────────────────────────────────────────────────
          Row(
            children: [
              _ActionBtn(
                icon: post.liked
                    ? Icons.favorite
                    : Icons.favorite_border_rounded,
                count: post.likeCount,
                active: post.liked,
                onTap: onLike,
              ),
              const SizedBox(width: 20),
              _ActionBtn(
                icon: Icons.chat_bubble_outline_rounded,
                count: post.replyCount,
                active: false,
                onTap: () {}, // future: expand reply thread
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: active ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              count > 0 ? '$count' : '',
              style: TextStyle(
                color: active ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Author Initial ───────────────────────────────────────────────────────────

class _AuthorInitial extends StatelessWidget {
  final String name;
  const _AuthorInitial(this.name);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ─── Empty Feed ───────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  final VoidCallback onCompose;
  const _EmptyFeed({required this.onCompose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🏛️', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 20),
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
              'Be the first to share something\nwith this guild',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCompose,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Write First Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class CommunityPost {
  final String id;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;
  final int replyCount;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String? authorAvatarUrl;
  final bool liked;

  const CommunityPost({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.likeCount,
    required this.replyCount,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl,
    this.liked = false,
  });

  CommunityPost copyWith({int? likeCount, bool? liked}) => CommunityPost(
        id: id,
        content: content,
        imageUrl: imageUrl,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        replyCount: replyCount,
        authorId: authorId,
        authorName: authorName,
        authorUsername: authorUsername,
        authorAvatarUrl: authorAvatarUrl,
        liked: liked ?? this.liked,
      );

  static List<CommunityPost> demoData(String communityId) => [
        CommunityPost(
          id: 'demo-1',
          content:
              'Just finished my latest abstract series — oil on linen. '
              'The process took 3 months exploring negative space. Sharing '
              'some WIP shots next week!',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          likeCount: 14,
          replyCount: 3,
          authorId: 'demo-user-1',
          authorName: 'Priya Sharma',
          authorUsername: 'priya_creates',
        ),
        CommunityPost(
          id: 'demo-2',
          content:
              'Hot take: authenticity certificates on physical art will be '
              'standard in 5 years. Artyug is ahead of the curve. '
              'What do you think?',
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          likeCount: 31,
          replyCount: 9,
          authorId: 'demo-user-2',
          authorName: 'Ravi Menon',
          authorUsername: 'ravi_art',
        ),
        CommunityPost(
          id: 'demo-3',
          content:
              'First sale on Artyug 🎉 A collector from Bangalore bought my '
              'watercolour series. The certificate flow is smooth and the '
              'QR verification is impressive.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          likeCount: 52,
          replyCount: 12,
          authorId: 'demo-user-3',
          authorName: 'Aarav Patel',
          authorUsername: 'aarav.art',
        ),
        CommunityPost(
          id: 'demo-4',
          content:
              'Looking for collaborators on a generative art + traditional '
              'print hybrid project. DM if interested — we\'re planning to '
              'mint on Solana devnet as a proof of concept.',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          likeCount: 8,
          replyCount: 2,
          authorId: 'demo-user-4',
          authorName: 'Ananya Krishnan',
          authorUsername: 'ananya.lens',
        ),
      ];
}
