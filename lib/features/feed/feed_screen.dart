import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/config/supabase_client.dart';
import '../../core/utils/supabase_media_url.dart';
import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/feed_view_mode_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/studio_service.dart';
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
  bool _recentActivityLoading = true;
  String? _recentActivityError;
  List<_RecentActivityItem> _recentActivities = const [];
  bool _showingMoreFeed = false;
  List<Map<String, dynamic>> _featuredStudios = const [];
  final Set<String> _prefetchedImageUrls = <String>{};
  String _smartSort = 'Newest';
  List<Map<String, dynamic>> _liveAuctions = const [];
  bool _liveAuctionsLoading = true;
  List<String> _followedArtistIds = const [];
  List<String> _followedStudioIds = const [];
  List<String> _recentViewedArtworkIds = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadFeed(refresh: true);
      _loadRecentActivity();
      _loadFeaturedStudios();
      _loadSmartHomeData();
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
            id: e.id,
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

      // First pass: use hash returned by RPC.
      final provisional = data
          .map(
            (row) => _RecentActivityItem(
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
              solanaExplorerUrl:
                  _buildExplorerUrl(row['certificate_blockchain_hash'] as String?),
            ),
          )
          .toList();

      // Second pass: if RPC join hash is missing, try certificates lookup by order_id.
      final missingOrderIds = provisional
          .where((e) => e.solanaExplorerUrl == null)
          .map((e) => e.orderId)
          .toList();

      Map<String, String?> fallbackHashByOrder = const {};
      if (missingOrderIds.isNotEmpty) {
        try {
          final certRows = await SupabaseClientHelper.db
              .from('certificates')
              .select('order_id, blockchain_hash')
              .inFilter('order_id', missingOrderIds);

          fallbackHashByOrder = {
            for (final row in (certRows as List).cast<Map<String, dynamic>>())
              (row['order_id']?.toString() ?? ''):
                  row['blockchain_hash']?.toString(),
          };
        } catch (_) {
          fallbackHashByOrder = const {};
        }
      }

      final items = provisional
          .map(
            (e) => e.solanaExplorerUrl != null
                ? e
                : _RecentActivityItem(
                    orderId: e.orderId,
                    artworkId: e.artworkId,
                    artworkTitle: e.artworkTitle,
                    artworkMediaUrl: e.artworkMediaUrl,
                    buyerName: e.buyerName,
                    amount: e.amount,
                    currency: e.currency,
                    purchasedAt: e.purchasedAt,
                    solanaExplorerUrl:
                        _buildExplorerUrl(fallbackHashByOrder[e.orderId]),
                  ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _recentActivities = items;
        _recentActivityLoading = false;
      });
    } catch (_) {
      await _loadRecentActivityFallbackFromOrders();
    }
  }

  Future<void> _loadFeaturedStudios() async {
    final rows = await StudioService.getFeaturedStudios(limit: 8);
    if (!mounted) return;
    setState(() => _featuredStudios = rows);
  }

  Future<void> _loadSmartHomeData() async {
    await Future.wait([
      _loadLiveAuctions(),
      _loadFollowGraph(),
      _loadRecentViewed(),
    ]);
  }

  Future<void> _loadLiveAuctions() async {
    try {
      final rows = await SupabaseClientHelper.db
          .from('auctions')
          .select('id, painting_id, current_highest_bid, end_time, status, bid_increment')
          .inFilter('status', ['active', 'live'])
          .order('end_time', ascending: true)
          .limit(10);
      if (!mounted) return;
      setState(() {
        _liveAuctions = List<Map<String, dynamic>>.from(rows as List);
        _liveAuctionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveAuctions = const [];
        _liveAuctionsLoading = false;
      });
    }
  }

  Future<void> _loadFollowGraph() async {
    try {
      final uid = SupabaseClientHelper.db.auth.currentUser?.id;
      if (uid == null) return;
      final followRows = await SupabaseClientHelper.db
          .from('follows')
          .select('following_id')
          .eq('follower_id', uid)
          .limit(120);
      final artistIds = (followRows as List)
          .map((e) => (e as Map<String, dynamic>)['following_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      List<String> studioIds = const [];
      if (artistIds.isNotEmpty) {
        final studioRows = await SupabaseClientHelper.db
            .from('shops')
            .select('id, owner_id')
            .inFilter('owner_id', artistIds)
            .eq('is_active', true)
            .limit(120);
        studioIds = (studioRows as List)
            .map((e) => (e as Map<String, dynamic>)['id'] as String?)
            .whereType<String>()
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _followedArtistIds = artistIds;
        _followedStudioIds = studioIds;
      });
    } catch (_) {}
  }

  Future<void> _loadRecentViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('recent_viewed_artworks') ?? const [];
      if (!mounted) return;
      setState(() => _recentViewedArtworkIds = ids);
    } catch (_) {}
  }

  Future<void> _rememberViewedArtwork(String id) async {
    if (id.isEmpty) return;
    final next = [id, ..._recentViewedArtworkIds.where((e) => e != id)].take(20).toList();
    if (mounted) {
      setState(() => _recentViewedArtworkIds = next);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_viewed_artworks', next);
    } catch (_) {}
  }

  Future<void> _loadRecentActivityFallbackFromOrders() async {
    try {
      final rows = await SupabaseClientHelper.db
          .from('orders')
          .select(
              'id, artwork_id, artwork_title, artwork_media_url, buyer_name, amount, currency, created_at')
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(8);

      final data = List<Map<String, dynamic>>.from(rows as List);
      final items = data
          .map(
            (row) => _RecentActivityItem(
              orderId: row['id'] as String,
              artworkId: row['artwork_id'] as String?,
              artworkTitle:
                  (row['artwork_title'] as String?)?.trim().isNotEmpty == true
                      ? (row['artwork_title'] as String).trim()
                      : 'Untitled Artwork',
              artworkMediaUrl: row['artwork_media_url'] as String?,
              buyerName:
                  (row['buyer_name'] as String?)?.trim().isNotEmpty == true
                      ? (row['buyer_name'] as String).trim()
                      : 'Collector',
              amount: (row['amount'] as num?)?.toDouble(),
              currency: (row['currency'] as String?) ?? 'INR',
              purchasedAt: row['created_at'] != null
                  ? DateTime.tryParse(row['created_at'] as String)
                  : null,
              solanaExplorerUrl: null,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _recentActivities = items;
        _recentActivityLoading = false;
        _recentActivityError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentActivities = const [];
        _recentActivityLoading = false;
        _recentActivityError = null;
      });
    }
  }

  List<PaintingModel> _ecoFeedPreview(List<PaintingModel> all) {
    return _sortSmart(all.toList()).take(12).toList();
  }

  void _prefetchFromPaintings(List<PaintingModel> paintings) {
    if (!mounted) return;
    final urls = paintings
        .map((p) => p.resolvedImageUrl.trim())
        .where((u) => u.isNotEmpty && !_prefetchedImageUrls.contains(u))
        .take(3)
        .toList();
    if (urls.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final url in urls) {
        precacheImage(
          NetworkImage(url),
          context,
          onError: (_, __) {},
        );
        _prefetchedImageUrls.add(url);
      }
    });
  }

  List<PaintingModel> _applySmartFilters(List<PaintingModel> paintings) {
    return paintings;
  }

  List<PaintingModel> _sortSmart(List<PaintingModel> paintings) {
    final copy = List<PaintingModel>.from(paintings);
    switch (_smartSort) {
      case 'Newest':
        copy.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        break;
      case 'Price: Low-High':
        copy.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
        break;
      case 'Price: High-Low':
        copy.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
        break;
      case 'Auction Ending Soon':
        copy.sort((a, b) => (a.listingType == 'auction' ? 0 : 1).compareTo(b.listingType == 'auction' ? 0 : 1));
        break;
      default:
        copy.sort((a, b) {
          final as = (a.likesCount * 3) + (a.viewsCount) + (a.bidsCount * 5) + (a.purchasesCount * 8);
          final bs = (b.likesCount * 3) + (b.viewsCount) + (b.bidsCount * 5) + (b.purchasesCount * 8);
          return bs.compareTo(as);
        });
    }
    return copy;
  }

  void _openEcosystemShowMore(
    BuildContext context,
    FeedProvider feed, {
    required List<PaintingModel> paintings,
  }) async {
    if (_showingMoreFeed) return;
    setState(() => _showingMoreFeed = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _EcosystemShowMoreDialog(
          feed: feed,
          paintings: paintings,
        ),
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
    return AppConfig.buildSolanaExplorerUrl(hash, mode: AppConfig.chainMode);
  }

  @override
  Widget build(BuildContext context) {
    final isProMode = context.watch<FeedViewModeProvider>().isProMode;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<FeedProvider>(
        builder: (context, feed, _) {
          final ecoPreview = _ecoFeedPreview(feed.paintings);
          final smartPaintings = _sortSmart(_applySmartFilters(feed.paintings));
          final collectionItems = _buildCollectionItems(smartPaintings);
          final artistItems = _buildArtistItems(smartPaintings);
          final communityItems = _buildCommunityItems(smartPaintings);
          final becauseYouFollow = smartPaintings
              .where((p) => _followedArtistIds.contains(p.artistId) || (_followedStudioIds.contains(p.shopId)))
              .take(8)
              .toList();
          final continueExploringSeed = smartPaintings
              .where((p) => _recentViewedArtworkIds.contains(p.id))
              .take(8)
              .toList();
          final continueExploring = continueExploringSeed.isNotEmpty
              ? continueExploringSeed
              : smartPaintings
                  .where((p) => !becauseYouFollow.any((b) => b.id == p.id))
                  .take(8)
                  .toList();
          final topVerified = smartPaintings
              .where((p) => p.isVerifiedArtwork || (p.artistIsVerified ?? false) || p.hasNfcAttached)
              .take(8)
              .toList();
          final liveAuctionRows = _liveAuctions.where((a) {
            final pid = a['painting_id']?.toString();
            return pid != null && smartPaintings.any((p) => p.id == pid);
          }).take(8).toList();

          _prefetchFromPaintings(ecoPreview);
          _prefetchFromPaintings(becauseYouFollow);
          _prefetchFromPaintings(continueExploring);
          _prefetchFromPaintings(topVerified);

          final width = MediaQuery.sizeOf(context).width;
          final hPad = width < 360
              ? 16.0
              : width < 600
                  ? 18.0
                  : 24.0;
          final topPad = widget.useShellTopBar ? 18.0 : 20.0;
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          final scrollBottomPad =
              bottomInset + (widget.useShellTopBar ? 104.0 : 28.0);

          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                feed.loadFeed(refresh: true),
                _loadRecentActivity(),
                _loadSmartHomeData(),
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
                    child: _SectionHeader(
                      title: 'Featured Art',
                      subtitle: 'Curated highlights from verified and trending creators',
                      actionLabel: 'View all',
                      onActionTap: _openExploreTab,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FeaturedArtRail(
                    horizontalPadding: hPad,
                    paintings: () {
                      // Pin "Nutan Labh" artworks first in the featured rail
                      const featuredArtist = 'nutan labh';
                      final pinned = smartPaintings
                          .where((p) =>
                              (p.artistDisplayName ?? '')
                                  .toLowerCase()
                                  .contains(featuredArtist))
                          .toList();
                      final rest = smartPaintings
                          .where((p) =>
                              !(p.artistDisplayName ?? '')
                                  .toLowerCase()
                                  .contains(featuredArtist))
                          .toList();
                      return [...pinned, ...rest].take(10).toList();
                    }(),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SmartFilterHeaderDelegate(
                    minExtentValue: 58,
                    maxExtentValue: 58,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 8),
                      child: _SmartFilterBar(
                        sort: _smartSort,
                        onSort: (v) => setState(() => _smartSort = v),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 10),
                    child: _SectionHeader(
                      title: 'Ecosystem Feed',
                      subtitle: 'Fresh artworks from Artyug creators and communities',
                      actionLabel: 'Show more',
                      onActionTap: () => _openEcosystemShowMore(
                        context,
                        feed,
                        paintings: smartPaintings,
                      ),
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
                      child: _EcosystemSplitFeed(
                        paintings: ecoPreview,
                        onLike: (paintingId) => feed.toggleLike(paintingId),
                        onArtworkTap: (paintingId) =>
                            _rememberViewedArtwork(paintingId),
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
                              _openEcosystemShowMore(
                                context,
                                feed,
                                paintings: smartPaintings,
                              ),
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
                if (isProMode)
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
                if (isProMode)
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
                if (isProMode)
                  SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
                    child: _SectionHeader(
                      title: 'Trending Collections',
                      subtitle:
                          'High-momentum sets collecting attention this week',
                      actionLabel: 'View all',
                      onActionTap: _openExploreTab,
                    ),
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: _HorizontalCollections(
                    horizontalPadding: hPad,
                    collections: collectionItems.take(8).toList(),
                    onTap: _openExploreTab,
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                    child: _SectionHeader(
                      title: 'Featured Artists',
                      subtitle:
                          'Verified voices with strong community engagement',
                      actionLabel: 'View all',
                      onActionTap: _openExploreTab,
                    ),
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: _HorizontalArtists(
                    horizontalPadding: hPad,
                    artists: artistItems.take(8).toList(),
                    onTap: (artist) => context.push('/public-profile/${artist.id}'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 0),
                    child: _SectionHeader(
                      title: 'Because You Follow',
                      subtitle: 'Personalized from your followed artists and studios',
                      actionLabel: 'View all',
                      onActionTap: () => context.push('/search?q=artist'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                    child: _CompactArtworkRail(
                      paintings: becauseYouFollow,
                      emptyLabel: 'Follow more artists to personalize this rail.',
                      onOpenExplore: () => context.push('/search?q=artist'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 0),
                    child: _SectionHeader(
                      title: 'Live Auctions Now',
                      subtitle: 'Watch countdowns and jump into quick bidding',
                      actionLabel: 'View all',
                      onActionTap: () => context.push('/auctions'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                    child: _LiveAuctionsNowRail(
                      loading: _liveAuctionsLoading,
                      rows: liveAuctionRows,
                      paintings: smartPaintings,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 0),
                    child: _SectionHeader(
                      title: 'Continue Exploring',
                      subtitle: 'Resume where you left off',
                      actionLabel: 'View all',
                      onActionTap: _openExploreTab,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                    child: _CompactArtworkRail(
                      paintings: continueExploring,
                      emptyLabel: 'Explore artworks and we will remember your trail here.',
                      onOpenExplore: _openExploreTab,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 0),
                    child: _SectionHeader(
                      title: 'Top Verified This Week',
                      subtitle: 'Verification and provenance-first highlights',
                      actionLabel: 'View all',
                      onActionTap: _openExploreTab,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                    child: _CompactArtworkRail(
                      paintings: topVerified,
                      emptyLabel: 'No verified highlights yet this week.',
                      onOpenExplore: _openExploreTab,
                    ),
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                    child: _SectionHeader(
                      title: 'Featured Studios',
                      subtitle: 'Signature creator studios with active collections',
                      actionLabel: 'View all',
                      onActionTap: () => context.push('/shop'),
                    ),
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: _FeaturedStudiosStrip(
                    horizontalPadding: hPad,
                    studios: _featuredStudios.take(8).toList(),
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                    child: _SectionHeader(
                      title: 'Live Drops & Highlights',
                      subtitle:
                          'Time-sensitive listings and curated showcase moments',
                      actionLabel: 'View all',
                      onActionTap: _openExploreTab,
                    ),
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                    child: _LiveDropsGrid(paintings: feed.paintings),
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                    child: _SectionHeader(
                      title: 'Popular Guilds & Communities',
                      subtitle:
                          'Collective spaces where creators and collectors connect',
                      actionLabel: 'View all',
                      onActionTap: () => context.push('/guild'),
                    ),
                  ),
                ),
                if (isProMode)
                  SliverToBoxAdapter(
                  child: _CommunitiesRow(
                    horizontalPadding: hPad,
                    communities: communityItems.take(8).toList(),
                    onTap: () => context.push('/guild'),
                  ),
                ),
                if (isProMode)
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

class _FeaturedStudiosStrip extends StatelessWidget {
  final double horizontalPadding;
  final List<Map<String, dynamic>> studios;

  const _FeaturedStudiosStrip({
    required this.horizontalPadding,
    required this.studios,
  });

  @override
  Widget build(BuildContext context) {
    if (studios.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Text(
            'No featured studios available yet.',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        scrollDirection: Axis.horizontal,
        itemCount: studios.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final s = studios[i];
          final profile = s['profiles'] as Map<String, dynamic>?;
          final name = (s['name'] as String?)?.trim().isNotEmpty == true
              ? (s['name'] as String).trim()
              : 'Studio';
          final by = (profile?['display_name'] as String?)?.trim().isNotEmpty == true
              ? (profile!['display_name'] as String).trim()
              : 'Creator';
          final creatorAvatar = (profile?['profile_picture_url'] as String?)?.trim();
          final creatorVerified = profile?['is_verified'] == true;
          final slug = s['slug']?.toString();
          final avatar = (s['avatar_url'] as String?)?.trim();
          final works = (s['artworks_count'] as num?)?.toInt() ?? 0;
          final collections = (s['collections_count'] as num?)?.toInt() ?? 0;
          final category = (s['category'] as String?)?.trim();

          return InkWell(
            onTap: () {
              if (slug != null && slug.isNotEmpty) {
                context.push('/shop/$slug');
              } else {
                context.push('/shop');
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: 290,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  _AvatarWithFallback(
                    url: avatar ?? '',
                    radius: 30,
                    label: name,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 9,
                                  backgroundColor:
                                      AppColors.surfaceSoftOf(context),
                                  backgroundImage: (creatorAvatar != null &&
                                          creatorAvatar.isNotEmpty)
                                      ? NetworkImage(creatorAvatar)
                                      : null,
                                  child: (creatorAvatar == null ||
                                          creatorAvatar.isEmpty)
                                      ? Text(
                                          by.substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                            color: AppColors.textSecondaryOf(context),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        )
                                      : null,
                                ),
                                if (creatorVerified)
                                  Positioned(
                                    right: -1,
                                    bottom: -1,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.info,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 6,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'by $by',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondaryOf(context),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$works works • $collections collections',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (category != null && category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
class _SmartFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minExtentValue;
  final double maxExtentValue;

  _SmartFilterHeaderDelegate({
    required this.child,
    required this.minExtentValue,
    required this.maxExtentValue,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.94),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SmartFilterHeaderDelegate oldDelegate) => true;
}

class _SmartFilterBar extends StatelessWidget {
  final String sort;
  final ValueChanged<String> onSort;

  const _SmartFilterBar({
    required this.sort,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniDropdown(
            label: 'Sort & filter',
            value: sort,
            values: const [
              'Newest',
              'Trending',
              'Price: Low-High',
              'Price: High-Low',
              'Auction Ending Soon',
            ],
            onChanged: onSort,
          ),
        ),
      ],
    );
  }
}
class _MiniDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _MiniDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: TextStyle(color: AppColors.textPrimaryOf(context), fontSize: 12, fontWeight: FontWeight.w600),
          dropdownColor: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          items: values.map((v) => DropdownMenuItem(value: v, child: Text('$label: $v'))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
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
                  child: _EcosystemArtworkCard(
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

class _EcosystemSplitFeed extends StatelessWidget {
  final List<PaintingModel> paintings;
  final ValueChanged<String> onLike;
  final ValueChanged<String>? onArtworkTap;

  const _EcosystemSplitFeed({
    required this.paintings,
    required this.onLike,
    this.onArtworkTap,
  });

  @override
  Widget build(BuildContext context) {
    final latestFirst = List<PaintingModel>.from(paintings)
      ..sort(
        (a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)),
      );
    final threads = latestFirst.take(8).toList();
    final forSale = latestFirst
        .where((p) => p.isAvailable || p.price != null || p.listingType == 'auction')
        .toList();
    final gallery = latestFirst
        .where((p) => !(p.isAvailable || p.price != null || p.listingType == 'auction'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniFeedHeader(
          title: 'Threads',
          subtitle: 'Latest creator thoughts, process notes, and story-first posts',
        ),
        const SizedBox(height: 10),
        if (threads.isEmpty)
          const _MiniFeedEmpty(label: 'No threads yet. Ask creators to share their latest process.')
        else
          _ThreadGrid(
            paintings: threads,
            onLike: onLike,
            onTap: (id) => onArtworkTap?.call(id),
          ),
        const SizedBox(height: 18),
        _MiniFeedHeader(
          title: 'For Sale',
          subtitle: 'Listings with price, buy, or auction context',
        ),
        const SizedBox(height: 10),
        if (forSale.isEmpty)
          const _MiniFeedEmpty(label: 'No active listings in this filter right now.')
        else
          SizedBox(
            height: 340,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: forSale.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = forSale[i];
                return SizedBox(
                  width: 280,
                  child: _EcosystemArtworkCard(
                    painting: p,
                    isLiked: p.isLikedByMe,
                    onLike: () => onLike(p.id),
                    onTap: () => onArtworkTap?.call(p.id),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 18),
        _MiniFeedHeader(
          title: 'Art Drops',
          subtitle: 'Image-first creator posts without price pressure',
        ),
        const SizedBox(height: 10),
        if (gallery.isEmpty)
          const _MiniFeedEmpty(label: 'No gallery drops in this filter right now.')
        else
          _GalleryDropGrid(
            paintings: gallery.take(6).toList(),
            onLike: onLike,
            onTap: (id) => onArtworkTap?.call(id),
          ),
      ],
    );
  }
}

// ── Thread Grid — 2 columns, bigger images, bio visible ─────────────────────
class _ThreadGrid extends StatelessWidget {
  final List<PaintingModel> paintings;
  final ValueChanged<String> onLike;
  final ValueChanged<String>? onTap;

  const _ThreadGrid({
    required this.paintings,
    required this.onLike,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: paintings.map((p) {
            final bio = (p.description ?? '').trim().isNotEmpty
                ? p.description!.trim()
                : '${(p.medium ?? '').trim()} ${(p.category ?? '').trim()}'.trim();
            return SizedBox(
              width: tileWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  onTap?.call(p.id);
                  context.push('/artwork/${p.id}', extra: p);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bigger image — nearly square
                      MarketplaceMediaFrame(
                        imageUrl: p.resolvedImageUrl,
                        aspectRatio: 1.0,
                        borderRadius: BorderRadius.zero,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Artwork title
                            Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimaryOf(context),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Artist row with avatar + name
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 9,
                                  backgroundColor: AppColors.accentSoftOf(context),
                                  foregroundImage: p.resolvedArtistAvatarUrl != null &&
                                          p.resolvedArtistAvatarUrl!.trim().isNotEmpty
                                      ? NetworkImage(p.resolvedArtistAvatarUrl!)
                                      : null,
                                  child: Text(
                                    ((p.artistDisplayName ?? 'A').trim().isNotEmpty
                                            ? (p.artistDisplayName ?? 'A').trim().substring(0, 1)
                                            : 'A')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: AppColors.accentOf(context),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    p.artistDisplayName ?? 'Artyug Artist',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (p.artistIsVerified ?? false)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 3),
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 12,
                                      color: AppColors.info,
                                    ),
                                  ),
                              ],
                            ),
                            // Bio / description
                            if (bio.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondaryOf(context),
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            // Footer: time + likes
                            Row(
                              children: [
                                Text(
                                  p.createdAt == null ? 'Just now' : _relativeTime(p.createdAt!),
                                  style: TextStyle(
                                    color: AppColors.textTertiaryOf(context),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () => onLike(p.id),
                                  child: Row(
                                    children: [
                                      Icon(
                                        p.isLikedByMe
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 13,
                                        color: p.isLikedByMe
                                            ? AppColors.primary
                                            : AppColors.textSecondaryOf(context),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${p.likesCount}',
                                        style: TextStyle(
                                          color: AppColors.textSecondaryOf(context),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EcosystemArtworkCard extends StatelessWidget {
  final PaintingModel painting;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback? onTap;

  const _EcosystemArtworkCard({
    required this.painting,
    required this.isLiked,
    required this.onLike,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final description = (painting.description ?? '').trim().isNotEmpty
        ? painting.description!.trim()
        : '${(painting.medium ?? '').trim()} ${(painting.category ?? '').trim()}'
            .trim();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        onTap?.call();
        context.push('/artwork/${painting.id}', extra: painting);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarketplaceMediaFrame(
              imageUrl: painting.resolvedImageUrl,
              aspectRatio: 1.08,
              borderRadius: BorderRadius.zero,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    painting.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.accentSoftOf(context),
                        foregroundImage: painting.resolvedArtistAvatarUrl !=
                                    null &&
                                painting.resolvedArtistAvatarUrl!.trim().isNotEmpty
                            ? NetworkImage(painting.resolvedArtistAvatarUrl!)
                            : null,
                        child: Text(
                          ((painting.artistDisplayName ?? 'A').trim().isNotEmpty
                                  ? (painting.artistDisplayName ?? 'A')
                                      .trim()
                                      .substring(0, 1)
                                  : 'A')
                              .toUpperCase(),
                          style: TextStyle(
                            color: AppColors.accentOf(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          painting.artistDisplayName ?? 'Artyug Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      if (painting.artistIsVerified ?? false)
                        const Padding(
                          padding: EdgeInsets.only(left: 3),
                          child: Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: AppColors.info,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        painting.createdAt == null
                            ? 'Just now'
                            : _relativeTime(painting.createdAt!),
                        style: TextStyle(
                          color: AppColors.textTertiaryOf(context),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: isLiked
                                  ? AppColors.primary
                                  : AppColors.textSecondaryOf(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${painting.likesCount}',
                              style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _MiniFeedHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MiniFeedHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimaryOf(context),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _MiniFeedEmpty extends StatelessWidget {
  final String label;

  const _MiniFeedEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Text(
        label,
        style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12.5),
      ),
    );
  }
}

class _GalleryDropGrid extends StatelessWidget {
  final List<PaintingModel> paintings;
  final ValueChanged<String>? onTap;
  final ValueChanged<String>? onLike;

  const _GalleryDropGrid({required this.paintings, this.onTap, this.onLike});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 760 ? 3 : 2;
        final spacing = 10.0;
        final tileWidth = (c.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: paintings.map((p) {
            return SizedBox(
              width: tileWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  onTap?.call(p.id);
                  AnalyticsService.track('ecosystem_gallery_drop_tap', params: {'artwork_id': p.id});
                  context.push('/artwork/${p.id}', extra: p);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarketplaceMediaFrame(
                        imageUrl: p.resolvedImageUrl,
                        aspectRatio: 1,
                        borderRadius: BorderRadius.zero,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimaryOf(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 9,
                                  backgroundColor:
                                      AppColors.accentSoftOf(context),
                                  foregroundImage: p.resolvedArtistAvatarUrl !=
                                              null &&
                                          p.resolvedArtistAvatarUrl!
                                              .trim()
                                              .isNotEmpty
                                      ? NetworkImage(
                                          p.resolvedArtistAvatarUrl!,
                                        )
                                      : null,
                                  child: Text(
                                    ((p.artistDisplayName ?? 'A')
                                                .trim()
                                                .isNotEmpty
                                            ? (p.artistDisplayName ?? 'A')
                                                .trim()
                                                .substring(0, 1)
                                            : 'A')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: AppColors.accentOf(context),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    p.artistDisplayName ?? 'Artyug Artist',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (p.artistIsVerified ?? false)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: AppColors.info,
                                    ),
                                  ),
                              ],
                            ),
                            if ((p.description ?? '').trim().isNotEmpty ||
                                (p.medium ?? '').trim().isNotEmpty ||
                                (p.category ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                (p.description ?? '').trim().isNotEmpty
                                    ? p.description!.trim()
                                    : '${(p.medium ?? '').trim()} ${(p.category ?? '').trim()}'
                                        .trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondaryOf(context),
                                  fontSize: 11.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            const SizedBox(height: 5),
                            Text(
                              p.createdAt == null ? 'Just now' : _relativeTime(p.createdAt!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textTertiaryOf(context),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () => onLike?.call(p.id),
                                  child: Row(
                                    children: [
                                      Icon(
                                        p.isLikedByMe
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 15,
                                        color: p.isLikedByMe
                                            ? AppColors.primary
                                            : AppColors.textSecondaryOf(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${p.likesCount}',
                                        style: TextStyle(
                                          color: AppColors.textSecondaryOf(context),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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

class _CompactArtworkRail extends StatelessWidget {
  final List<PaintingModel> paintings;
  final String emptyLabel;
  final VoidCallback onOpenExplore;

  const _CompactArtworkRail({
    required this.paintings,
    required this.emptyLabel,
    required this.onOpenExplore,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 420 ? 272.0 : 288.0;
    if (paintings.isEmpty) {
      return _SmartEmptyCard(label: emptyLabel, cta: 'Explore', onTap: onOpenExplore);
    }
    return SizedBox(
      height: 324,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paintings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = paintings[i];
          return SizedBox(
            width: cardWidth,
            child: PaintingCard(
              painting: p,
              isLiked: p.isLikedByMe,
              showBuyButton: true,
              onTap: () => AnalyticsService.track('home_rail_artwork_tap', params: {'section': 'compact', 'artwork_id': p.id}),
            ),
          );
        },
      ),
    );
  }
}

class _LiveAuctionsNowRail extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> rows;
  final List<PaintingModel> paintings;

  const _LiveAuctionsNowRail({required this.loading, required this.rows, required this.paintings});

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox(height: 110, child: MarketplaceShimmer());
    if (rows.isEmpty) {
      return _SmartEmptyCard(label: 'No live auctions right now.', cta: 'Browse auctions', onTap: () => context.push('/auctions'));
    }
    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = rows[i];
          final pid = a['painting_id']?.toString();
          final p = paintings.where((e) => e.id == pid).cast<PaintingModel?>().firstWhere((e) => e != null, orElse: () => null);
          final endAt = DateTime.tryParse((a['end_time'] ?? '').toString());
          final remain = endAt == null ? '--' : _relativeTime(endAt);
          final high = (a['current_highest_bid'] as num?)?.toDouble() ?? 0;
          final image = p?.resolvedImageUrl.trim() ?? '';
          return Container(
            width: 290,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 86,
                  height: double.infinity,
                  child: image.isNotEmpty
                      ? MarketplaceMediaFrame(
                          imageUrl: image,
                          aspectRatio: 1,
                          borderRadius: BorderRadius.zero,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accentSoftOf(context),
                                AppColors.surfaceSoftOf(context),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.gavel_rounded,
                              color: AppColors.accentOf(context),
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p?.title ?? 'Live auction', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimaryOf(context), fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Current bid: ₹${high.toStringAsFixed(0)}', style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Ends in $remain', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      AnalyticsService.track('home_live_auction_quick_bid_tap', params: {'auction_id': a['id']?.toString()});
                      context.push('/auction/${a['id']}');
                    },
                    child: const Text('Quick Bid'),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _SmartEmptyCard extends StatelessWidget {
  final String label;
  final String cta;
  final VoidCallback onTap;

  const _SmartEmptyCard({required this.label, required this.cta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 13))),
          TextButton(onPressed: onTap, child: Text(cta)),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final d = time.difference(DateTime.now());
  final past = d.isNegative;
  final abs = d.abs();
  if (abs.inMinutes < 60) return '${abs.inMinutes}m ${past ? 'ago' : 'left'}';
  if (abs.inHours < 24) return '${abs.inHours}h ${past ? 'ago' : 'left'}';
  return '${abs.inDays}d ${past ? 'ago' : 'left'}';
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

class _FeaturedArtRail extends StatelessWidget {
  final double horizontalPadding;
  final List<PaintingModel> paintings;

  const _FeaturedArtRail({
    required this.horizontalPadding,
    required this.paintings,
  });

  @override
  Widget build(BuildContext context) {
    if (paintings.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Text(
            'Featured artworks will appear here as creators publish new drops.',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 228,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        scrollDirection: Axis.horizontal,
        itemCount: paintings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final p = paintings[index];
          final cover = p.resolvedImageUrl.trim();
          return GestureDetector(
            onTap: () => context.push('/artwork/${p.id}', extra: p),
            child: Container(
              width: 310,
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MarketplaceMediaFrame(
                    imageUrl: cover,
                    aspectRatio: 16 / 9,
                    borderRadius: BorderRadius.zero,
                    showGradientOverlay: true,
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.artistDisplayName ?? 'Artyug Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE9E9EC),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
  final ValueChanged<_ArtistItem> onTap;

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
            onTap: () => onTap(artist),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AvatarWithFallback(
                    url: artist.avatar,
                    radius: 24,
                    label: artist.name,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                artist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimaryOf(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                size: 15, color: AppColors.info),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          artist.stat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
  final String id;
  final String name;
  final String stat;
  final String avatar;

  const _ArtistItem(
      {required this.id, required this.name, required this.stat, required this.avatar});
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
    id: 'fallback-rhea-sharma',
    name: 'Rhea Sharma',
    stat: '12 featured works',
    avatar:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
  ),
  _ArtistItem(
    id: 'fallback-aarav-menon',
    name: 'Aarav Menon',
    stat: '8 live drops',
    avatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300',
  ),
  _ArtistItem(
    id: 'fallback-noor-arora',
    name: 'Noor Arora',
    stat: 'Top verified this week',
    avatar:
        'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=300',
  ),
  _ArtistItem(
    id: 'fallback-siddhant-rao',
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
  final List<PaintingModel> paintings;

  const _EcosystemShowMoreDialog({
    required this.feed,
    required this.paintings,
  });

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
                  paintings: (List<PaintingModel>.from(widget.paintings)
                    ..sort(
                      (a, b) => (b.createdAt ?? DateTime(2000))
                          .compareTo(a.createdAt ?? DateTime(2000)),
                    )),
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


/// A [CircleAvatar] that gracefully falls back to an initial-letter placeholder
/// when the network image URL is empty or fails to load.
class _AvatarWithFallback extends StatelessWidget {
  final String url;
  final double radius;
  final String label;

  const _AvatarWithFallback({
    required this.url,
    required this.radius,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    final hasUrl = url.trim().isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: ClipOval(
        child: hasUrl
            ? Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _InitialLabel(
                  initial: initial,
                  radius: radius,
                ),
              )
            : _InitialLabel(initial: initial, radius: radius),
      ),
    );
  }
}

class _InitialLabel extends StatelessWidget {
  final String initial;
  final double radius;
  const _InitialLabel({required this.initial, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: AppColors.primary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

