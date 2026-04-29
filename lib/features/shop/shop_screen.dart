library;

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../../widgets/premium/premium_ui.dart';
import '../auction/auction_model.dart';
import '../auction/auction_service.dart';

class ShopScreen extends StatefulWidget {
  final bool embedInShell;
  const ShopScreen({super.key, this.embedInShell = false});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _client = Supabase.instance.client;
  final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final _sortOptions = const {
    'trending': 'Trending',
    'newest': 'Newest',
    'price_asc': 'Price: Low to High',
    'price_desc': 'Price: High to Low',
    'most_viewed': 'Most Viewed',
    'most_liked': 'Most Liked',
    'auction_ending': 'Auction Ending Soon',
  };

  final _mediumOptions = const [
    'All',
    'Painting',
    'Photography',
    'Sculpture',
    'Digital Art',
    'Illustration',
    'Mixed Media',
  ];

  final _priceRanges = const {
    'all': 'Any price',
    '0-10000': 'Below ₹10k',
    '10000-50000': '₹10k - ₹50k',
    '50000-200000': '₹50k - ₹2L',
    '200000+': '₹2L+',
  };

  List<PaintingModel> _allArtworks = [];
  List<PaintingModel> _filtered = [];
  List<PaintingModel> _trending = [];
  List<PaintingModel> _recent = [];
  List<AuctionModel> _endingSoonAuctions = [];
  List<Map<String, dynamic>> _featuredArtists = [];
  List<Map<String, dynamic>> _popularShops = [];

  bool _loading = true;
  String? _error;
  String _sortBy = 'trending';
  String _medium = 'All';
  String _priceRange = 'all';
  bool _availabilityOnly = true;
  bool _verifiedOnly = false;
  bool _nfcOnly = false;
  String _listingType = 'all';
  String _styleQuery = '';
  String _locationQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final artworks = await _fetchArtworks();
      final auctions = await _fetchEndingSoonAuctions();
      final artists = await _fetchFeaturedArtists();
      final shops = await _fetchPopularShops();

      if (!mounted) return;
      setState(() {
        _allArtworks = artworks;
        _trending = _sortByTrending(artworks).take(10).toList();
        _recent = List<PaintingModel>.from(artworks)
          ..sort((a, b) => (b.createdAt ?? DateTime(1970))
              .compareTo(a.createdAt ?? DateTime(1970)));
        _endingSoonAuctions = auctions.take(10).toList();
        _featuredArtists = artists;
        _popularShops = shops;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<PaintingModel>> _fetchArtworks() async {
    try {
      final rows = await _client.from('paintings').select('''
            id, artist_id, title, description, medium, dimensions, image_url, additional_images,
            price, is_for_sale, is_sold, style_tags, category, created_at, listing_type, status,
            is_verified, nfc_status, solana_tx_id, views_count, likes_count, bids_count, purchases_count,
            creator_location, shop_id, collection_id, currency,
            profiles:artist_id(display_name, profile_picture_url, is_verified)
          ''').order('created_at', ascending: false).limit(140);

      return _mapPaintings(rows as List<dynamic>);
    } catch (_) {
      // Backward-compatible fallback for environments missing new columns.
      final rows = await _client.from('paintings').select('''
            id, artist_id, title, description, medium, dimensions, image_url, additional_images,
            price, is_for_sale, is_sold, style_tags, category, created_at,
            profiles:artist_id(display_name, profile_picture_url, is_verified)
          ''').order('created_at', ascending: false).limit(140);
      return _mapPaintings(rows as List<dynamic>);
    }
  }

  List<PaintingModel> _mapPaintings(List<dynamic> rows) {
    return rows.map((e) {
      final json = e as Map<String, dynamic>;
      final profile = json['profiles'] as Map<String, dynamic>?;
      return PaintingModel.fromJson({
        ...json,
        'display_name': profile?['display_name'],
        'profile_picture_url': profile?['profile_picture_url'],
        'artist_is_verified': profile?['is_verified'],
        'is_verified_artwork': json['is_verified'],
      });
    }).toList();
  }

  Future<List<AuctionModel>> _fetchEndingSoonAuctions() async {
    try {
      final auctions = await AuctionService.getActiveAuctions(limit: 24);
      auctions.sort((a, b) => a.endTime.compareTo(b.endTime));
      return auctions;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFeaturedArtists() async {
    try {
      final rows = await _client
          .from('profiles')
          .select(
              'id, display_name, username, profile_picture_url, is_verified, artist_type, followers_count')
          .eq('role', 'creator')
          .order('followers_count', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPopularShops() async {
    try {
      final rows = await _client
          .from('shops')
          .select(
              'id, name, slug, description, avatar_url, cover_image_url, status, is_active')
          .order('created_at', ascending: false)
          .limit(12);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return [];
    }
  }

  List<PaintingModel> _sortByTrending(List<PaintingModel> input) {
    final sorted = List<PaintingModel>.from(input);
    sorted.sort((a, b) {
      final as = _score(a);
      final bs = _score(b);
      return bs.compareTo(as);
    });
    return sorted;
  }

  double _score(PaintingModel p) {
    final views = p.viewsCount;
    final likes = p.likesCount;
    final bids = p.bidsCount;
    final purchases = p.purchasesCount;
    final ageDays =
        DateTime.now().difference(p.createdAt ?? DateTime.now()).inDays;
    final recencyBoost = (30 - ageDays).clamp(0, 30);
    return (views * 1) +
        (likes * 3) +
        (bids * 5) +
        (purchases * 10) +
        recencyBoost.toDouble();
  }

  void _applyFilters() {
    var list = List<PaintingModel>.from(_allArtworks);

    if (_availabilityOnly) {
      list = list.where((p) => p.isAvailable).toList();
    }

    if (_medium != 'All') {
      list = list
          .where((p) => (p.medium ?? p.category ?? '')
              .toLowerCase()
              .contains(_medium.toLowerCase()))
          .toList();
    }

    if (_styleQuery.trim().isNotEmpty) {
      final q = _styleQuery.trim().toLowerCase();
      list = list.where((p) {
        final tags = (p.styleTags ?? []).map((e) => e.toLowerCase());
        final category = (p.category ?? '').toLowerCase();
        return tags.any((t) => t.contains(q)) || category.contains(q);
      }).toList();
    }

    if (_locationQuery.trim().isNotEmpty) {
      final q = _locationQuery.trim().toLowerCase();
      list = list
          .where((p) => (p.creatorLocation ?? '').toLowerCase().contains(q))
          .toList();
    }

    if (_verifiedOnly) {
      list = list
          .where((p) => p.isVerifiedArtwork || p.artistIsVerified == true)
          .toList();
    }

    if (_nfcOnly) {
      list = list.where((p) => p.hasNfcAttached).toList();
    }

    if (_listingType != 'all') {
      list = list
          .where((p) => (p.listingType ?? 'fixed_price') == _listingType)
          .toList();
    }

    switch (_priceRange) {
      case '0-10000':
        list = list.where((p) => (p.price ?? 0) <= 10000).toList();
        break;
      case '10000-50000':
        list = list
            .where((p) => (p.price ?? 0) >= 10000 && (p.price ?? 0) <= 50000)
            .toList();
        break;
      case '50000-200000':
        list = list
            .where((p) => (p.price ?? 0) >= 50000 && (p.price ?? 0) <= 200000)
            .toList();
        break;
      case '200000+':
        list = list.where((p) => (p.price ?? 0) >= 200000).toList();
        break;
    }

    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
        break;
      case 'price_desc':
        list.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
        break;
      case 'most_viewed':
        list.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case 'most_liked':
        list.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case 'auction_ending':
        final ending = <String, DateTime>{
          for (final a in _endingSoonAuctions) a.paintingId: a.endTime,
        };
        list.sort((a, b) {
          final ea = ending[a.id];
          final eb = ending[b.id];
          if (ea == null && eb == null) return 0;
          if (ea == null) return 1;
          if (eb == null) return -1;
          return ea.compareTo(eb);
        });
        break;
      case 'newest':
        list.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        break;
      default:
        list = _sortByTrending(list);
        break;
    }

    final primaryRail = _sortBy == 'trending'
        ? _sortByTrending(list)
        : List<PaintingModel>.from(list);
    final recentRail = List<PaintingModel>.from(list)
      ..sort(
        (a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)),
      );

    setState(() {
      _filtered = list;
      _trending = primaryRail.take(10).toList();
      _recent = recentRail.take(12).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const PremiumBackdrop(
            glows: [
              PremiumGlowSpec(
                alignment: Alignment(-0.9, -0.8),
                size: 260,
                color: Color(0x33FF6A2B),
              ),
              PremiumGlowSpec(
                alignment: Alignment(0.9, -0.3),
                size: 300,
                color: Color(0x224F8BFF),
              ),
            ],
          ),
          SafeArea(
            top: !widget.embedInShell,
            child: CustomScrollView(
              slivers: [
                if (!widget.embedInShell)
                  SliverToBoxAdapter(child: _buildTopBar()),
                SliverToBoxAdapter(child: _buildFilterBar()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _buildSortAndCount(),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.textTertiary, size: 44),
                            const SizedBox(height: 10),
                            Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.textSecondary),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                                onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  _sectionHeader(
                      'Trending Artworks', 'High momentum right now'),
                  _artworkStrip(_trending),
                  _sectionHeader(
                      'Recently Listed', 'Fresh artworks in the marketplace'),
                  _artworkStrip(_recent.take(12).toList()),
                  _sectionHeader(
                      'Ending Soon Auctions', 'Bid windows closing soon'),
                  _auctionStrip(_endingSoonAuctions),
                  _sectionHeader(
                      'Featured Artists', 'Creators collectors are following'),
                  _artistsStrip(),
                  _sectionHeader(
                      'Popular Studios', 'Explore curated artist studios'),
                  _shopsStrip(),
                  _sectionHeader(
                      'Discover Artworks', 'Filtered and sorted results'),
                  _resultsGrid(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marketplace',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7),
                ),
                Text('Trending, auctions, studios, and verified artworks',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.push('/auctions'),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gavel_rounded, color: AppColors.error, size: 14),
                  SizedBox(width: 6),
                  Text('Auctions',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FilterChipButton(
            label: _medium,
            icon: Icons.brush_outlined,
            onTap: () async {
              final value = await _pickOne(context, 'Medium', _mediumOptions);
              if (value == null) return;
              setState(() => _medium = value);
              _applyFilters();
            },
          ),
          _FilterChipButton(
            label: _priceRanges[_priceRange] ?? 'Any price',
            icon: Icons.payments_outlined,
            onTap: () async {
              final values = _priceRanges.entries.map((e) => e.value).toList();
              final picked = await _pickOne(context, 'Price Range', values);
              if (picked == null) return;
              final key =
                  _priceRanges.entries.firstWhere((e) => e.value == picked).key;
              setState(() => _priceRange = key);
              _applyFilters();
            },
          ),
          _FilterChipButton(
            label: _listingType == 'all'
                ? 'All Listings'
                : _listingType.replaceAll('_', ' '),
            icon: Icons.sell_outlined,
            onTap: () async {
              const values = ['all', 'fixed_price', 'auction', 'open_offer'];
              final picked = await _pickOne(context, 'Listing Type',
                  values.map((e) => e.replaceAll('_', ' ')).toList());
              if (picked == null) return;
              setState(() => _listingType = picked.replaceAll(' ', '_'));
              _applyFilters();
            },
          ),
          _FilterChipButton(
            label: _verifiedOnly ? 'Verified only' : 'Verified',
            icon: Icons.verified_outlined,
            selected: _verifiedOnly,
            onTap: () {
              setState(() => _verifiedOnly = !_verifiedOnly);
              _applyFilters();
            },
          ),
          _FilterChipButton(
            label: _nfcOnly ? 'NFC only' : 'NFC',
            icon: Icons.nfc,
            selected: _nfcOnly,
            onTap: () {
              setState(() => _nfcOnly = !_nfcOnly);
              _applyFilters();
            },
          ),
          _FilterChipButton(
            label: _availabilityOnly ? 'Available' : 'All Status',
            icon: Icons.inventory_2_outlined,
            selected: _availabilityOnly,
            onTap: () {
              setState(() => _availabilityOnly = !_availabilityOnly);
              _applyFilters();
            },
          ),
          _FilterChipButton(
            label: _styleQuery.isEmpty ? 'Style' : 'Style: $_styleQuery',
            icon: Icons.auto_awesome_outlined,
            onTap: () => _askText('Style filter', _styleQuery, (v) {
              setState(() => _styleQuery = v);
              _applyFilters();
            }),
          ),
          _FilterChipButton(
            label: _locationQuery.isEmpty ? 'Location' : 'Loc: $_locationQuery',
            icon: Icons.location_on_outlined,
            onTap: () => _askText('Creator location', _locationQuery, (v) {
              setState(() => _locationQuery = v);
              _applyFilters();
            }),
          ),
          _FilterChipButton(
            label: 'Clear',
            icon: Icons.close_rounded,
            onTap: () {
              setState(() {
                _medium = 'All';
                _priceRange = 'all';
                _availabilityOnly = true;
                _verifiedOnly = false;
                _nfcOnly = false;
                _listingType = 'all';
                _styleQuery = '';
                _locationQuery = '';
              });
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSortAndCount() {
    return Row(
      children: [
        Text('${_filtered.length} artworks',
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButton<String>(
            value: _sortBy,
            underline: const SizedBox.shrink(),
            isDense: true,
            dropdownColor: AppColors.surfaceVariant,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            items: _sortOptions.entries
                .map((entry) => DropdownMenuItem(
                    value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _sortBy = value);
              _applyFilters();
            },
          ),
        ),
      ],
    );
  }

  SliverToBoxAdapter _sectionHeader(String title, String subtitle) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _artworkStrip(List<PaintingModel> artworks) {
    if (artworks.isEmpty) {
      return const SliverToBoxAdapter(
        child: _PremiumEmptyState(
          icon: Icons.image_outlined,
          title: 'No artworks available yet',
          subtitle: 'New listings will appear here as creators publish.',
          cta: 'Browse all marketplace',
        ),
      );
    }
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 270,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: artworks.length.clamp(0, 12),
          itemBuilder: (_, i) => SizedBox(
            width: 210,
            child: _ArtworkCard(
              artwork: artworks[i],
              currency: _currency,
              onTap: () => context.push('/artwork/${artworks[i].id}',
                  extra: artworks[i]),
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _auctionStrip(List<AuctionModel> auctions) {
    if (auctions.isEmpty) {
      return const SliverToBoxAdapter(
        child: _PremiumEmptyState(
          icon: Icons.gavel_rounded,
          title: 'No auctions live yet',
          subtitle: 'Artists have not started a live auction right now.',
          cta: 'Browse fixed-price artworks',
        ),
      );
    }
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: auctions.length,
          itemBuilder: (_, i) {
            final auction = auctions[i];
            final title = auction.painting?.title ?? 'Auction artwork';
            final image = auction.painting?.resolvedImageUrl ?? '';
            return GestureDetector(
              onTap: () =>
                  context.push('/auction/${auction.id}', extra: auction),
              child: Container(
                width: 290,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.hardEdge,
                child: Row(
                  children: [
                    SizedBox(
                      width: 116,
                      child: image.isEmpty
                          ? Container(color: AppColors.surfaceVariant)
                          : CachedNetworkImage(
                              imageUrl: image, fit: BoxFit.cover),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(
                                'Highest: ${auction.currentHighestBid == null ? "No bids yet" : _currency.format(auction.currentHighestBid)}',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(auction.relativeEndLabel,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _artistsStrip() {
    if (_featuredArtists.isEmpty) {
      return const SliverToBoxAdapter(
        child: _PremiumEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No featured artists yet',
          subtitle:
              'Artist highlights will appear when creator data is available.',
          cta: 'Explore artworks',
        ),
      );
    }
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 94,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: _featuredArtists.length,
          itemBuilder: (_, i) {
            final artist = _featuredArtists[i];
            final name = artist['display_name']?.toString() ??
                artist['username']?.toString() ??
                'Artist';
            final avatar = artist['profile_picture_url']?.toString();
            return GestureDetector(
              onTap: () => context.push('/public-profile/${artist['id']}'),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: avatar != null && avatar.isNotEmpty
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar == null || avatar.isEmpty
                          ? Text(name.substring(0, 1).toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _shopsStrip() {
    if (_popularShops.isEmpty) {
      return const SliverToBoxAdapter(
        child: _PremiumEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No popular studios yet',
          subtitle: 'Studios appear here when creators publish their space.',
          cta: 'Browse marketplace',
        ),
      );
    }
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: _popularShops.length,
          itemBuilder: (_, i) {
            final shop = _popularShops[i];
            final name = shop['name']?.toString() ?? 'Studio';
            final slug = shop['slug']?.toString();
            final cover = shop['cover_image_url']?.toString();
            return GestureDetector(
              onTap: () {
                if (slug != null && slug.isNotEmpty) {
                  context.push('/shop/$slug');
                }
              },
              child: Container(
                width: 260,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null && cover.isNotEmpty)
                      CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                    else
                      Container(color: AppColors.surfaceVariant),
                    const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppColors.cardOverlay)),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  SliverPadding _resultsGrid() {
    if (_filtered.isEmpty) {
      return const SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
        sliver: SliverToBoxAdapter(
          child: _PremiumEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'No artworks match your filters',
            subtitle: 'Try clearing filters or switching sorting options.',
            cta: 'Clear filters',
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _ArtworkCard(
            artwork: _filtered[i],
            currency: _currency,
            onTap: () => context.push('/artwork/${_filtered[i].id}',
                extra: _filtered[i]),
          ),
          childCount: _filtered.length,
        ),
      ),
    );
  }

  Future<String?> _pickOne(
      BuildContext context, String title, List<String> options) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: AppColors.border),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800)),
                  ),
                  ...options.map(
                    (opt) => ListTile(
                      title: Text(opt,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      onTap: () => Navigator.pop(context, opt),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _askText(
      String title, String current, ValueChanged<String> onSaved) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Type to filter'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Apply')),
        ],
      ),
    );
    if (result != null) {
      onSaved(result);
    }
  }
}

class _ArtworkCard extends StatelessWidget {
  final PaintingModel artwork;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _ArtworkCard({
    required this.artwork,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final listing = artwork.listingType ?? 'fixed_price';
    final badge = listing == 'auction'
        ? 'Auction'
        : (listing == 'open_offer' ? 'Open Offer' : 'Buy Now');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: premiumGlassDecoration(
          borderRadius: BorderRadius.circular(14),
          shadowAlpha: 0.2,
          shadowBlur: 18,
          shadowOffset: const Offset(0, 10),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (artwork.resolvedImageUrl.isNotEmpty)
                    CachedNetworkImage(
                        imageUrl: artwork.resolvedImageUrl, fit: BoxFit.cover)
                  else
                    Container(color: AppColors.surfaceVariant),
                  const DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: AppColors.cardOverlay)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(badge,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (artwork.isVerifiedArtwork)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.verified_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artwork.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.accentSoftOf(context),
                        foregroundImage:
                            artwork.resolvedArtistAvatarUrl != null &&
                                    artwork.resolvedArtistAvatarUrl!
                                        .trim()
                                        .isNotEmpty
                                ? CachedNetworkImageProvider(
                                    artwork.resolvedArtistAvatarUrl!,
                                  )
                                : null,
                        child: Text(
                          ((artwork.artistDisplayName ?? 'A').trim().isNotEmpty
                                  ? (artwork.artistDisplayName ?? 'A')
                                      .trim()
                                      .substring(0, 1)
                                  : 'A')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'by ${artwork.artistDisplayName ?? 'Artist'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        artwork.price != null
                            ? currency.format(artwork.price!)
                            : 'Price on request',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined,
                              size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text('${artwork.viewsCount}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textTertiary)),
                        ],
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

class _FilterChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: premiumGlassDecoration(
          borderRadius: BorderRadius.circular(999),
          borderColor: selected ? AppColors.primary : AppColors.border,
          shadowAlpha: 0,
          gradientColors: selected
              ? [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0.1),
                ]
              : [
                  AppColors.surface.withValues(alpha: 0.88),
                  AppColors.surfaceVariant.withValues(alpha: 0.7),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;

  const _PremiumEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: premiumGlassDecoration(
          borderRadius: BorderRadius.circular(14),
          shadowAlpha: 0.16,
          shadowBlur: 16,
          shadowOffset: const Offset(0, 8),
          gradientColors: [
            AppColors.surfaceVariant.withValues(alpha: 0.88),
            AppColors.surface.withValues(alpha: 0.72),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text(cta,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
