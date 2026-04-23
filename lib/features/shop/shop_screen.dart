/// ArtYug Shop / Marketplace Browse Screen
/// Minimalist editorial layout — art first, commerce second.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';

class ShopScreen extends StatefulWidget {
  final bool embedInShell;
  const ShopScreen({super.key, this.embedInShell = false});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _client = Supabase.instance.client;
  List<PaintingModel> _artworks = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';
  String _sortBy = 'newest';

  final _categories = [
    'All', 'Painting', 'Sculpture', 'Digital', 'Photography',
    'Mixed Media', 'Prints', 'Drawing',
  ];
  final _sortOptions = {
    'newest': 'Newest',
    'price_asc': 'Price ↑',
    'price_desc': 'Price ↓',
    'popular': 'Popular',
  };

  final _currency = NumberFormat.currency(
    locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      dynamic query = _client
          .from('paintings')
          .select('''
            id, title, image_url, price, artist_id, is_for_sale,
            is_sold, medium, dimensions, category, style_tags, created_at,
            profiles:artist_id ( display_name, profile_picture_url, is_verified )
          ''')
          .eq('is_for_sale', true)
          .eq('is_sold', false);

      if (_selectedCategory != 'All') {
        query = query.ilike('category', '%$_selectedCategory%');
      }

      switch (_sortBy) {
        case 'price_asc':
          query = query.order('price', ascending: true);
          break;
        case 'price_desc':
          query = query.order('price', ascending: false);
          break;
        case 'popular':
          query = query.order('likes_count', ascending: false);
          break;
        default:
          query = query.order('created_at', ascending: false);
      }

      final data = await query.limit(60);
      if (!mounted) return;

      final artworks = (data as List<dynamic>).map((e) {
        final json = e as Map<String, dynamic>;
        final prof = json['profiles'] as Map<String, dynamic>?;
        return PaintingModel(
          id: json['id'] as String,
          artistId: json['artist_id'] as String,
          title: json['title'] as String? ?? 'Untitled',
          imageUrl: json['image_url'] as String? ?? '',
          price: json['price'] != null ? (json['price'] as num).toDouble() : null,
          isForSale: json['is_for_sale'] as bool? ?? false,
          isSold: json['is_sold'] as bool? ?? false,
          medium: json['medium'] as String?,
          dimensions: json['dimensions'] as String?,
          category: json['category'] as String?,
          styleTags: (json['style_tags'] as List<dynamic>?)
              ?.map((t) => t.toString()).toList(),
          artistDisplayName: prof?['display_name'] as String?,
          artistProfilePictureUrl: prof?['profile_picture_url'] as String?,
          artistIsVerified: prof?['is_verified'] as bool?,
        );
      }).toList();

      setState(() { _artworks = artworks; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: !widget.embedInShell,
        child: CustomScrollView(
          slivers: [
            if (!widget.embedInShell)
              SliverToBoxAdapter(child: _buildTopBar()),
            SliverToBoxAdapter(child: _buildFilters()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${_artworks.length} artworks',
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 12),
                    ),
                    const Spacer(),
                    _SortDropdown(
                      value: _sortBy,
                      options: _sortOptions,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _sortBy = v);
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.primary)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.textTertiary, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                )),
              )
            else if (_artworks.isEmpty)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.store_rounded,
                        color: AppColors.textTertiary, size: 48),
                    const SizedBox(height: 12),
                    const Text('No artworks found',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedCategory = 'All');
                        _load();
                      },
                      child: const Text('Clear filters'),
                    ),
                  ],
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ShopArtCard(
                      painting: _artworks[i],
                      currency: _currency,
                      onTap: () => context.push(
                        '/artwork/${_artworks[i].id}',
                        extra: _artworks[i],
                      ),
                    ),
                    childCount: _artworks.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                Text('Discover and collect original art',
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
                border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gavel_rounded, color: AppColors.error, size: 15),
                  SizedBox(width: 5),
                  Text('Auctions',
                      style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 4),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () {
                if (_selectedCategory == cat) return;
                setState(() => _selectedCategory = cat);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Sort Dropdown ──────────────────────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  const _SortDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        items: options.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ))
            .toList(),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        dropdownColor: AppColors.surfaceVariant,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.expand_more_rounded,
            color: AppColors.textTertiary, size: 16),
        isDense: true,
      ),
    );
  }
}

// ── Shop Art Card ──────────────────────────────────────────────────────────

class _ShopArtCard extends StatelessWidget {
  final PaintingModel painting;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _ShopArtCard({
    required this.painting,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (painting.resolvedImageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: painting.resolvedImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.surfaceVariant,
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.broken_image_rounded,
                            color: AppColors.textTertiary, size: 32),
                      ),
                    )
                  else
                    Container(color: AppColors.surfaceVariant,
                        child: const Icon(Icons.palette_rounded,
                            color: AppColors.textTertiary, size: 40)),
                  // Gradient bottom overlay
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: AppColors.cardOverlay),
                    ),
                  ),
                  // Category tag
                  if (painting.category != null)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          painting.category!,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Artist row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.surfaceVariant,
                        backgroundImage: painting.artistProfilePictureUrl != null
                            ? CachedNetworkImageProvider(
                                painting.artistProfilePictureUrl!)
                            : null,
                        child: painting.artistProfilePictureUrl == null
                            ? Text(
                                (painting.artistDisplayName ?? '?')[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800))
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          painting.artistDisplayName ?? 'Artist',
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (painting.artistIsVerified == true)
                        const Icon(Icons.verified_rounded,
                            color: AppColors.primary, size: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    painting.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        painting.price != null
                            ? currency.format(painting.price!)
                            : 'Price on request',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.shopping_bag_outlined,
                            color: AppColors.primary, size: 16),
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
