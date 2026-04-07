import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/config/supabase_client.dart';
import '../../core/utils/supabase_media_url.dart';
import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../widgets/cards/painting_card.dart';
import '../../widgets/feed/marketplace_media.dart';

class FeedScreen extends StatefulWidget {
  final bool useShellTopBar;

  const FeedScreen({super.key, this.useShellTopBar = false});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();
  int _selectedChip = 0;
  bool _recentActivityLoading = true;
  String? _recentActivityError;
  List<_RecentActivityItem> _recentActivities = const [];
  bool _showingMoreFeed = false;

  static const _chips = [
    'All',
    'Trending',
    'Verified',
    'Live Drops',
    'Photography',
    'Digital',
    'Abstract',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadFeed(refresh: true);
      _loadRecentActivity();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.88) {
      context.read<FeedProvider>().loadMore();
    }
  }

  /// Opens Explore inside the main tab shell when embedded; otherwise pushes explore route.
  void _openExploreTab() {
    if (widget.useShellTopBar) {
      context.read<MainTabProvider>().setIndex(1);
      context.go('/main');
    } else {
      context.push('/explore');
    }
  }

  List<_CollectionItem> _buildCollectionItems(List<PaintingModel> paintings) {
    if (paintings.isEmpty) return _fallbackCollections;

    final Map<String, _CollectionAccumulator> grouped = {};
    for (final p in paintings) {
      final key = (p.category?.trim().isNotEmpty ?? false)
          ? p.category!.trim()
          : 'Artyug Curated';
      final item = grouped.putIfAbsent(
        key,
        () => _CollectionAccumulator(name: key, cover: p.resolvedImageUrl),
      );
      item.count += 1;
      item.likes += p.likesCount;
      if (p.price != null) item.volume += p.price!;
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) =>
          (b.likes + (b.volume * 0.1)).compareTo(a.likes + (a.volume * 0.1)));

    return sorted
        .take(6)
        .map(
          (e) => _CollectionItem(
            title: '${e.name} Collection',
            volume:
                '${e.count} items • ${e.likes} likes • ₹${e.volume.toStringAsFixed(0)} volume',
            cover: e.cover,
          ),
        )
        .toList();
  }

  List<_ArtistItem> _buildArtistItems(List<PaintingModel> paintings) {
    if (paintings.isEmpty) return _fallbackArtists;

    final Map<String, _ArtistAccumulator> grouped = {};
    for (final p in paintings) {
      final key = p.artistId;
      final item = grouped.putIfAbsent(
        key,
        () => _ArtistAccumulator(
          id: key,
          name: p.artistDisplayName ?? 'Artyug Artist',
          avatar: p.resolvedArtistAvatarUrl ??
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300',
        ),
      );
      item.works += 1;
      item.likes += p.likesCount;
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) => b.likes.compareTo(a.likes));

    return sorted
        .take(8)
        .map(
          (e) => _ArtistItem(
            name: e.name,
            stat: '${e.works} works • ${e.likes} likes',
            avatar: e.avatar,
          ),
        )
        .toList();
  }

  List<_CommunityItem> _buildCommunityItems(List<PaintingModel> paintings) {
    if (paintings.isEmpty) return _fallbackCommunities;

    final categoryCount = <String, int>{};
    for (final p in paintings) {
      final key = (p.category?.trim().isNotEmpty ?? false)
          ? p.category!.trim()
          : 'General Art';
      categoryCount[key] = (categoryCount[key] ?? 0) + 1;
    }

    final sorted = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(5)
        .map(
          (entry) => _CommunityItem(
            name: '${entry.key} Guild',
            description:
                'Collectors and creators discussing ${entry.key.toLowerCase()} trends and drops.',
            members: '${(entry.value * 120) + 900} members',
          ),
        )
        .toList();
  }

  Future<void> _loadRecentActivity() async {
    if (!mounted) return;
    setState(() {
      _recentActivityLoading = true;
      _recentActivityError = null;
    });

    try {
      final rows = await SupabaseClientHelper.db.rpc(
        'artyug_recent_activity',
        params: {'limit_count': 8},
      );

      final data = (rows as List).cast<Map<String, dynamic>>();
      final items = data.map((row) {
        final hash = row['certificate_blockchain_hash'] as String?;
        return _RecentActivityItem(
          orderId: row['id'] as String,
          artworkId: row['artwork_id'] as String?,
          artworkTitle:
              (row['artwork_title'] as String?)?.trim().isNotEmpty == true
                  ? (row['artwork_title'] as String).trim()
                  : 'Untitled Artwork',
          artworkMediaUrl: row['artwork_media_url'] as String?,
          buyerName: (row['buyer_name'] as String?)?.trim().isNotEmpty == true
              ? (row['buyer_name'] as String).trim()
              : 'Collector',
          amount: (row['amount'] as num?)?.toDouble(),
          currency: (row['currency'] as String?) ?? 'INR',
          purchasedAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'] as String)
              : null,
          solanaExplorerUrl: _buildExplorerUrl(hash),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _recentActivities = items;
        _recentActivityLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentActivityLoading = false;
        _recentActivityError = 'Could not load recent purchases right now.';
      });
    }
  }

  List<PaintingModel> _ecoFeedPreview(List<PaintingModel> all) {
    // Only show artworks with valid media in the main feed.
    final withMedia = all.where((p) => p.resolvedImageUrl.trim().isNotEmpty);
    return withMedia.take(7).toList();
  }

  void _openEcosystemShowMore(BuildContext context, FeedProvider feed) async {
    if (_showingMoreFeed) return;
    setState(() => _showingMoreFeed = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _EcosystemShowMoreDialog(feed: feed),
      );
    } finally {
      if (mounted) setState(() => _showingMoreFeed = false);
    }
  }

  String? _buildExplorerUrl(String? blockchainHash) {
    final hash = blockchainHash?.trim();
    if (hash == null || hash.isEmpty) return null;
    if (hash.startsWith('http://') || hash.startsWith('https://')) return hash;
    if (hash.startsWith('0x')) return null;
    final isBase58 = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{43,128}$').hasMatch(hash);
    if (!isBase58) return null;
    return 'https://explorer.solana.com/tx/$hash?cluster=${AppConfig.chainMode.name}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<FeedProvider>(
        builder: (context, feed, _) {
          final ecoPreview = _ecoFeedPreview(feed.paintings);
          final collectionItems = _buildCollectionItems(feed.paintings);
          final artistItems = _buildArtistItems(feed.paintings);
          final communityItems = _buildCommunityItems(feed.paintings);

          final width = MediaQuery.sizeOf(context).width;
          final hPad = width < 360
              ? 16.0
              : width < 600
                  ? 18.0
                  : 24.0;
          final topPad = widget.useShellTopBar ? 8.0 : 20.0;
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          final scrollBottomPad =
              bottomInset + (widget.useShellTopBar ? 28.0 : 20.0);

          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                feed.loadFeed(refresh: true),
                _loadRecentActivity(),
              ]);
            },
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceOf(context),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (!widget.useShellTopBar) _buildStandaloneAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 0),
                    child: _DiscoveryHero(
                      onExplore: _openExploreTab,
                      onUpload: () => context.push('/upload'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
                    child: _QuickActionsRow(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                    child: _ChipStrip(
                      chips: _chips,
                      selected: _selectedChip,
                      onTap: (index) => setState(() => _selectedChip = index),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 10),
                    child: _SectionHeader(
                      title: 'Ecosystem Feed',
                      subtitle:
                          'Fresh artworks from Artyug creators and communities',
                      actionLabel: 'Show more',
                      onActionTap: () => _openEcosystemShowMore(context, feed),
                    ),
                  ),
                ),
                if (feed.loading && feed.paintings.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: _LoadingGrid(),
                    ),
                  )
                else if (feed.error != null && feed.paintings.isEmpty)
                  SliverToBoxAdapter(
                      child: _ErrorState(
                          onRetry: () => feed.loadFeed(refresh: true)))
                else if (feed.paintings.isEmpty)
                  SliverToBoxAdapter(
                      child:
                          _EmptyState(onUpload: () => context.push('/upload')))
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
                      child: _FeedGrid(
                        paintings: ecoPreview,
                        onLike: (paintingId) => feed.toggleLike(paintingId),
                      ),
                    ),
                  ),
                if (!feed.loading && feed.paintings.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 16),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openEcosystemShowMore(context, feed),
                          icon: const Icon(Icons.grid_view_rounded, size: 18),
                          label: const Text('Show more'),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: feed.loadingMore
                          ? const CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 2, hPad, 0),
                    child: _SectionHeader(
                      title: 'Recent Activity',
                      subtitle:
                          'Latest artwork purchases with collector and Solana proof links',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _RecentActivityStrip(
                    horizontalPadding: hPad,
                    loading: _recentActivityLoading,
                    error: _recentActivityError,
                    items: _recentActivities,
                    onRetry: _loadRecentActivity,
                    onOpenArtwork: (artworkId) {
                      if (artworkId != null && artworkId.isNotEmpty) {
                        context.push('/artwork/$artworkId');
                      }
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
                    child: _SectionHeader(
                      title: 'Trending Collections',
                      subtitle:
                          'High-momentum sets collecting attention this week',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HorizontalCollections(
                    horizontalPadding: hPad,
                    collections: collectionItems,
                    onTap: _openExploreTab,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                    child: _SectionHeader(
                      title: 'Featured Artists',
                      subtitle:
                          'Verified voices with strong community engagement',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HorizontalArtists(
                    horizontalPadding: hPad,
                    artists: artistItems,
                    onTap: _openExploreTab,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                    child: _SectionHeader(
                      title: 'Live Drops & Highlights',
                      subtitle:
                          'Time-sensitive listings and curated showcase moments',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                    child: _LiveDropsGrid(paintings: feed.paintings),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                    child: _SectionHeader(
                      title: 'Popular Guilds & Communities',
                      subtitle:
                          'Collective spaces where creators and collectors connect',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CommunitiesRow(
                    horizontalPadding: hPad,
                    communities: communityItems,
                    onTap: () => context.push('/guild'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(hPad, 22, hPad, scrollBottomPad),
                    child: _AuthenticitySpotlight(
                      onVerifyTap: () => context.push('/authenticity-center'),
                      onNfcTap: () => context.push('/nfc-scan'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _buildStandaloneAppBar() {
    final user = context.read<AuthProvider>().user;
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(
        'ARTYUG',
        style: TextStyle(
          color: AppColors.textPrimaryOf(context),
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded,
              color: AppColors.textPrimaryOf(context)),
          onPressed: _openExploreTab,
        ),
        IconButton(
          icon: Icon(Icons.notifications_none_rounded,
              color: AppColors.textPrimaryOf(context)),
          onPressed: () => context.push('/notifications'),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: user?.userMetadata?['avatar_url'] != null
                ? NetworkImage(user!.userMetadata!['avatar_url'])
                : null,
            child: user?.userMetadata?['avatar_url'] == null
                ? const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 16)
                : null,
          ),
        ),
      ],
    );
  }
}

class _DiscoveryHero extends StatelessWidget {
  final VoidCallback onExplore;
  final VoidCallback onUpload;

  const _DiscoveryHero({required this.onExplore, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final pad = compact ? 18.0 : 24.0;
    final titleSize = compact ? 24.0 : (width < 900 ? 28.0 : 31.0);
    final bodySize = compact ? 13.5 : 14.0;

    final primaryBtn = SizedBox(
      width: compact ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: onExplore,
        icon: const Icon(Icons.travel_explore_rounded, size: 18),
        label: const Text('Explore Marketplace'),
      ),
    );
    final secondaryBtn = SizedBox(
      width: compact ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: onUpload,
        icon: const Icon(Icons.upload_rounded, size: 18),
        label: const Text('List Artwork'),
      ),
    );

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradientOf(context),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: AppColors.borderStrongOf(context)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Discover Digital Collectibles on Artyug',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'A premium marketplace for verified creators, authenticated artworks, and high-intent collectors.',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: bodySize,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                primaryBtn,
                const SizedBox(height: 10),
                secondaryBtn,
              ],
            )
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: 540,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover Digital Collectibles on Artyug',
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A premium marketplace for verified creators, authenticated artworks, and high-intent collectors.',
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: bodySize,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    primaryBtn,
                    const SizedBox(width: 10),
                    secondaryBtn,
                  ],
                ),
              ],
            ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  static const _actions = <({IconData icon, String label, String route})>[
    (
      icon: Icons.workspace_premium_rounded,
      label: 'Certificates',
      route: '/certificates',
    ),
    (
      icon: Icons.verified_user_rounded,
      label: 'Verify Authenticity',
      route: '/authenticity-center',
    ),
    (
      icon: Icons.groups_rounded,
      label: 'Guilds',
      route: '/guild',
    ),
    (
      icon: Icons.event_rounded,
      label: 'Live Events',
      route: '/events',
    ),
    (
      icon: Icons.dashboard_customize_rounded,
      label: 'Creator Dashboard',
      route: '/creator-dashboard',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;

    if (!compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final a in _actions)
            _ActionChip(
              icon: a.icon,
              label: a.label,
              onTap: () => context.push(a.route),
              dense: false,
            ),
        ],
      );
    }

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = _actions[i];
          return _ActionChip(
            icon: a.icon,
            label: a.label,
            onTap: () => context.push(a.route),
            dense: true,
          );
        },
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = dense ? 10.0 : 8.0;
    final h = dense ? 14.0 : 12.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: h, vertical: v),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: dense ? 17 : 16,
                  color: AppColors.textSecondaryOf(context)),
              SizedBox(width: dense ? 7 : 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: dense ? 12.5 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipStrip extends StatelessWidget {
  final List<String> chips;
  final int selected;
  final ValueChanged<int> onTap;

  const _ChipStrip(
      {required this.chips, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return SizedBox(
      height: compact ? 44 : 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = selected == index;
          return ChoiceChip(
            selected: active,
            showCheckmark: false,
            visualDensity:
                compact ? VisualDensity.compact : VisualDensity.standard,
            label: Text(
              chips[index],
              style: TextStyle(
                fontSize: compact ? 12.5 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onSelected: (_) => onTap(index),
          );
        },
      ),
    );
  }
}

class _FeedGrid extends StatelessWidget {
  final List<PaintingModel> paintings;
  final ValueChanged<String> onLike;

  const _FeedGrid({required this.paintings, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1380
            ? 4
            : width >= 1000
                ? 3
                : width >= 680
                    ? 2
                    : 1;
        final spacing = width < 400 ? 12.0 : 16.0;
        final tileWidth = (width - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: paintings
              .map(
                (painting) => SizedBox(
                  width: tileWidth,
                  child: PaintingCard(
                    painting: painting,
                    isLiked: painting.isLikedByMe,
                    onLike: () => onLike(painting.id),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 3
            : width >= 680
                ? 2
                : 1;
        final spacing = width < 400 ? 12.0 : 16.0;
        final tileWidth = (width - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            columns * 2,
            (_) => SizedBox(
              width: tileWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: const AspectRatio(
                  aspectRatio: 4 / 3,
                  child: MarketplaceShimmer(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: AppColors.textPrimaryOf(context),
      fontSize: MediaQuery.sizeOf(context).width < 360 ? 19.0 : 22.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    );

    if (actionLabel != null && onActionTap != null) {
      return LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 320) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onActionTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _RecentActivityStrip extends StatelessWidget {
  final double horizontalPadding;
  final bool loading;
  final String? error;
  final List<_RecentActivityItem> items;
  final VoidCallback onRetry;
  final ValueChanged<String?> onOpenArtwork;

  const _RecentActivityStrip({
    required this.horizontalPadding,
    required this.loading,
    required this.error,
    required this.items,
    required this.onRetry,
    required this.onOpenArtwork,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 186,
        child: ListView.separated(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => Container(
            width: 330,
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: const MarketplaceShimmer(),
          ),
        ),
      );
    }

    if (error != null && items.isEmpty) {
      return Padding(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  error!,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Text(
            'No completed purchases yet. The latest activity will appear here automatically.',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 186,
      child: ListView.separated(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _RecentActivityCard(
            item: item,
            onTapArtwork: () => onOpenArtwork(item.artworkId),
          );
        },
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final _RecentActivityItem item;
  final VoidCallback onTapArtwork;

  const _RecentActivityCard({
    required this.item,
    required this.onTapArtwork,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapArtwork,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 340,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 98,
              child: MarketplaceMediaFrame(
                imageUrl: SupabaseMediaUrl.resolve(item.artworkMediaUrl),
                aspectRatio: 4 / 3,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.artworkTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Purchased by ${item.buyerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.displayPriceAndTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  if (item.solanaExplorerUrl != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(item.solanaExplorerUrl!);
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('View Solana link'),
                      ),
                    )
                  else
                    Text(
                      'Solana proof pending',
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11.5,
                      ),
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

class _HorizontalCollections extends StatelessWidget {
  final double horizontalPadding;
  final List<_CollectionItem> collections;
  final VoidCallback onTap;

  const _HorizontalCollections({
    required this.horizontalPadding,
    required this.collections,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = collections[index];
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: 240,
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MarketplaceMediaFrame(
                      imageUrl: item.cover,
                      aspectRatio: 16 / 9,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(item.volume,
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HorizontalArtists extends StatelessWidget {
  final double horizontalPadding;
  final List<_ArtistItem> artists;
  final VoidCallback onTap;

  const _HorizontalArtists({
    required this.horizontalPadding,
    required this.artists,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final artist = artists[index];
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                      radius: 24, backgroundImage: NetworkImage(artist.avatar)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                artist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.textPrimaryOf(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ),
                            const Icon(Icons.verified_rounded,
                                size: 15, color: AppColors.info),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(artist.stat,
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LiveDropsGrid extends StatelessWidget {
  final List<PaintingModel> paintings;

  const _LiveDropsGrid({required this.paintings});

  @override
  Widget build(BuildContext context) {
    final picks = paintings.take(6).toList();
    if (picks.isEmpty) {
      return Text('Live drops will appear once creators start listing.',
          style: TextStyle(color: AppColors.textSecondaryOf(context)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200
            ? 3
            : width >= 760
                ? 2
                : 1;
        final spacing = 12.0;
        final tileWidth = (width - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: picks
              .map(
                (painting) => SizedBox(
                  width: tileWidth,
                  child: PaintingCard(
                    painting: painting,
                    isLiked: painting.isLikedByMe,
                    onLike: () =>
                        context.read<FeedProvider>().toggleLike(painting.id),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CommunitiesRow extends StatelessWidget {
  final double horizontalPadding;
  final List<_CommunityItem> communities;
  final VoidCallback onTap;

  const _CommunitiesRow({
    required this.horizontalPadding,
    required this.communities,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 162,
      child: ListView.separated(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        scrollDirection: Axis.horizontal,
        itemCount: communities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final community = communities[index];
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 250,
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(community.name,
                        style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(community.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12)),
                    const Spacer(),
                    Text(community.members,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthenticitySpotlight extends StatelessWidget {
  final VoidCallback onVerifyTap;
  final VoidCallback onNfcTap;

  const _AuthenticitySpotlight(
      {required this.onVerifyTap, required this.onNfcTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderStrongOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('Authenticity Spotlight',
                  style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Artyug certificates, QR verification, and NFC proof workflows keep collector confidence high.',
            style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 13,
                height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                  onPressed: onVerifyTap,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Verify Certificate')),
              OutlinedButton.icon(
                  onPressed: onNfcTap,
                  icon: const Icon(Icons.nfc_rounded, size: 18),
                  label: const Text('Scan NFC')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded,
              color: AppColors.textTertiaryOf(context), size: 38),
          const SizedBox(height: 10),
          Text('Could not load marketplace feed',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Check your connection and try again.',
              style: TextStyle(color: AppColors.textSecondaryOf(context))),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;

  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.palette_rounded,
                color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 14),
          Text('No artworks yet',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Publish your first piece and start collecting momentum.',
              style: TextStyle(color: AppColors.textSecondaryOf(context))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Upload Artwork')),
        ],
      ),
    );
  }
}

class _CollectionItem {
  final String title;
  final String volume;
  final String cover;

  const _CollectionItem(
      {required this.title, required this.volume, required this.cover});
}

class _RecentActivityItem {
  final String orderId;
  final String? artworkId;
  final String artworkTitle;
  final String? artworkMediaUrl;
  final String buyerName;
  final double? amount;
  final String currency;
  final DateTime? purchasedAt;
  final String? solanaExplorerUrl;

  const _RecentActivityItem({
    required this.orderId,
    required this.artworkId,
    required this.artworkTitle,
    required this.artworkMediaUrl,
    required this.buyerName,
    required this.amount,
    required this.currency,
    required this.purchasedAt,
    required this.solanaExplorerUrl,
  });

  String get displayPriceAndTime {
    final amountText = amount == null
        ? 'Amount unavailable'
        : '₹${amount!.toStringAsFixed(0)}';
    final timeText = _formatRelativeTime(purchasedAt);
    return '$amountText • $timeText';
  }

  static String _formatRelativeTime(DateTime? date) {
    if (date == null) return 'recently';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _ArtistItem {
  final String name;
  final String stat;
  final String avatar;

  const _ArtistItem(
      {required this.name, required this.stat, required this.avatar});
}

class _CommunityItem {
  final String name;
  final String description;
  final String members;

  const _CommunityItem(
      {required this.name, required this.description, required this.members});
}

class _CollectionAccumulator {
  final String name;
  final String cover;
  int count = 0;
  int likes = 0;
  double volume = 0;

  _CollectionAccumulator({
    required this.name,
    required this.cover,
  });
}

class _ArtistAccumulator {
  final String id;
  final String name;
  final String avatar;
  int works = 0;
  int likes = 0;

  _ArtistAccumulator({
    required this.id,
    required this.name,
    required this.avatar,
  });
}

const _fallbackCollections = [
  _CollectionItem(
    title: 'Orange Signature Drops',
    volume: '2.1K volume this week',
    cover: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=900',
  ),
  _CollectionItem(
    title: 'Urban Fragments',
    volume: '1.5K volume this week',
    cover: 'https://images.unsplash.com/photo-1578301978693-85fa9c0320b9?w=900',
  ),
  _CollectionItem(
    title: 'Future Miniatures',
    volume: '980 volume this week',
    cover: 'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=900',
  ),
  _CollectionItem(
    title: 'Artyug Originals',
    volume: '3.4K total collectors',
    cover: 'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?w=900',
  ),
];

const _fallbackArtists = [
  _ArtistItem(
    name: 'Rhea Sharma',
    stat: '12 featured works',
    avatar:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
  ),
  _ArtistItem(
    name: 'Aarav Menon',
    stat: '8 live drops',
    avatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300',
  ),
  _ArtistItem(
    name: 'Noor Arora',
    stat: 'Top verified this week',
    avatar:
        'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=300',
  ),
  _ArtistItem(
    name: 'Siddhant Rao',
    stat: '24 collector follows',
    avatar:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
  ),
];

const _fallbackCommunities = [
  _CommunityItem(
    name: 'Artyug Pixel Guild',
    description:
        'Daily curation of digital and generative artwork from emerging artists.',
    members: '3,240 members',
  ),
  _CommunityItem(
    name: 'Verified Collectors Circle',
    description:
        'Certificate-first collectors sharing high-trust listings and discoveries.',
    members: '1,180 members',
  ),
  _CommunityItem(
    name: 'Live Drops Arena',
    description: 'Follow upcoming timed releases and artist launch calendars.',
    members: '2,030 members',
  ),
];

class _EcosystemShowMoreDialog extends StatefulWidget {
  final FeedProvider feed;

  const _EcosystemShowMoreDialog({required this.feed});

  @override
  State<_EcosystemShowMoreDialog> createState() =>
      _EcosystemShowMoreDialogState();
}

class _EcosystemShowMoreDialogState extends State<_EcosystemShowMoreDialog> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent * 0.88) {
      widget.feed.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final pad = w < 600 ? 16.0 : 20.0;
    final maxW = w < 720 ? w - 24 : 720.0;
    final maxH = h * 0.82;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 14, pad, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ecosystem Feed',
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All artworks (including unavailable previews)',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: _controller,
                padding: EdgeInsets.all(pad),
                child: _FeedGrid(
                  paintings: widget.feed.paintings,
                  onLike: (paintingId) => widget.feed.toggleLike(paintingId),
                ),
              ),
            ),
            if (widget.feed.loadingMore)
              const Padding(
                padding: EdgeInsets.only(bottom: 14, top: 6),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
