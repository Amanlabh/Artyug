import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../repositories/painting_repository.dart';
import '../../widgets/feed/marketplace_media.dart';

class ArtworkDetailScreen extends StatefulWidget {
  final String paintingId;
  final PaintingModel? initialPainting;

  const ArtworkDetailScreen({
    super.key,
    required this.paintingId,
    this.initialPainting,
  });

  @override
  State<ArtworkDetailScreen> createState() => _ArtworkDetailScreenState();
}

enum _ArtworkInfoTab { about, provenance }

class _ArtworkDetailScreenState extends State<ArtworkDetailScreen> {
  PaintingModel? _painting;
  bool _loading = true;
  String? _error;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _likeBusy = false;
  bool _descExpanded = false;
  int _selectedMediaIndex = 0;
  _ArtworkInfoTab _infoTab = _ArtworkInfoTab.about;

  @override
  void initState() {
    super.initState();
    if (widget.initialPainting != null) {
      _painting = widget.initialPainting;
      _isLiked = widget.initialPainting!.isLikedByMe;
      _likesCount = widget.initialPainting!.likesCount;
      _loading = false;
    }
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final painting =
          await PaintingRepository.getPaintingDetail(widget.paintingId);
      if (!mounted) return;

      setState(() {
        _painting = painting ?? _painting;
        _isLiked = painting?.isLikedByMe ?? _isLiked;
        _likesCount = painting?.likesCount ?? _likesCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = _painting == null;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/sign-in');
      return;
    }

    setState(() {
      _likeBusy = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      await PaintingRepository.toggleLike(widget.paintingId);
      if (mounted) {
        context
            .read<FeedProvider>()
            .updateLikeLocally(widget.paintingId, _isLiked);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  List<String> _galleryImages(PaintingModel painting) {
    final urls = <String>[];
    final primary = painting.resolvedImageUrl.trim();
    if (primary.isNotEmpty) urls.add(primary);
    for (final raw in painting.additionalImages ?? const <String>[]) {
      final cleaned = raw.trim();
      if (cleaned.isNotEmpty && !urls.contains(cleaned)) {
        urls.add(cleaned);
      }
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final painting = _painting;
    if (_loading && painting == null) {
      return _buildLoading();
    }
    if (painting == null) {
      return _buildError();
    }
    final galleryImages = _galleryImages(painting);
    final selectedIndex = _selectedMediaIndex.clamp(
      0,
      galleryImages.isEmpty ? 0 : galleryImages.length - 1,
    );

    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            return SingleChildScrollView(
              padding:
                  EdgeInsets.fromLTRB(wide ? 30 : 18, 20, wide ? 30 : 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailTopBar(
                    isLiked: _isLiked,
                    likesCount: _likesCount,
                    likeBusy: _likeBusy,
                    onLikeTap: _toggleLike,
                  ),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _MediaColumn(
                            painting: painting,
                            galleryImages: galleryImages,
                            selectedIndex: selectedIndex,
                            onSelectImage: (index) =>
                                setState(() => _selectedMediaIndex = index),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: _DetailColumn(
                            painting: painting,
                            likesCount: _likesCount,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _MediaColumn(
                      painting: painting,
                      galleryImages: galleryImages,
                      selectedIndex: selectedIndex,
                      onSelectImage: (index) =>
                          setState(() => _selectedMediaIndex = index),
                    ),
                    const SizedBox(height: 18),
                    _DetailColumn(
                      painting: painting,
                      likesCount: _likesCount,
                    ),
                  ],
                  const SizedBox(height: 18),
                  _DescriptionPanel(
                    painting: painting,
                    expanded: _descExpanded,
                    activeTab: _infoTab,
                    onTabChanged: (tab) => setState(() => _infoTab = tab),
                    onToggle: () =>
                        setState(() => _descExpanded = !_descExpanded),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(child: MarketplaceShimmer()),
              SizedBox(height: 18),
              SizedBox(height: 120, child: MarketplaceShimmer()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.textTertiaryOf(context), size: 54),
              const SizedBox(height: 12),
              Text('Unable to open artwork',
                  style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_error ?? 'Unknown error',
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _loadDetail, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  final bool isLiked;
  final int likesCount;
  final bool likeBusy;
  final VoidCallback onLikeTap;

  const _DetailTopBar({
    required this.isLiked,
    required this.likesCount,
    required this.likeBusy,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimaryOf(context)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Artwork Detail',
            style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
        ),
        InkWell(
          onTap: likeBusy ? null : onLikeTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: isLiked
                      ? const Color(0xFFFF5D7A)
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 6),
                Text('$likesCount',
                    style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaColumn extends StatelessWidget {
  final PaintingModel painting;
  final List<String> galleryImages;
  final int selectedIndex;
  final ValueChanged<int> onSelectImage;

  const _MediaColumn({
    required this.painting,
    required this.galleryImages,
    required this.selectedIndex,
    required this.onSelectImage,
  });

  @override
  Widget build(BuildContext context) {
    final currentImage = galleryImages.isEmpty
        ? painting.resolvedImageUrl
        : galleryImages[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderStrongOf(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowOf(context, alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              MarketplaceMediaFrame(
                imageUrl: currentImage,
                aspectRatio: 1.04,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMutedOf(context),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                ),
                child: Text(
                  'Preview your collectible with certificate-ready media and gallery framing.',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (galleryImages.length > 1) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: galleryImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final active = index == selectedIndex;
                Widget thumb = InkWell(
                  onTap: () => onSelectImage(index),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 92,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary.withValues(alpha: 0.14)
                          : AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : AppColors.borderOf(context),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: MarketplaceMediaFrame(
                        imageUrl: galleryImages[index],
                        aspectRatio: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                );
                if (kIsWeb) {
                  thumb = MouseRegion(
                    onEnter: (_) => onSelectImage(index),
                    cursor: SystemMouseCursors.click,
                    child: thumb,
                  );
                }
                return thumb;
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailColumn extends StatelessWidget {
  final PaintingModel painting;
  final int likesCount;

  const _DetailColumn({
    required this.painting,
    required this.likesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          painting.title,
          style: TextStyle(
            color: AppColors.textPrimaryOf(context),
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.06,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        _ArtistIdentityCard(painting: painting),
        const SizedBox(height: 14),
        _PriceHero(painting: painting),
        const SizedBox(height: 16),
        _VariantSection(painting: painting),
        const SizedBox(height: 16),
        _ActionZone(painting: painting),
        const SizedBox(height: 18),
        _TrustRow(painting: painting),
        if (painting.styleTags != null && painting.styleTags!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: painting.styleTags!
                .take(10)
                .map(
                  (tag) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        _InfoChips(painting: painting, likesCount: likesCount),
      ],
    );
  }
}

class _ArtistIdentityCard extends StatelessWidget {
  final PaintingModel painting;

  const _ArtistIdentityCard({required this.painting});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/public-profile/${painting.artistId}'),
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.surfaceMutedOf(context),
              backgroundImage: painting.resolvedArtistAvatarUrl != null
                  ? CachedNetworkImageProvider(
                      painting.resolvedArtistAvatarUrl!,
                    )
                  : null,
              child: painting.resolvedArtistAvatarUrl == null
                  ? Icon(Icons.person_rounded,
                      color: AppColors.textSecondaryOf(context))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          painting.artistDisplayName ?? 'Artyug Artist',
                          style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (painting.artistIsVerified ?? false)
                        Icon(Icons.verified_rounded,
                            color: AppColors.info, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    painting.artistType ?? 'Creator',
                    style: TextStyle(
                        color: AppColors.textSecondaryOf(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiaryOf(context)),
          ],
        ),
      ),
    );
  }
}

class _PriceHero extends StatelessWidget {
  final PaintingModel painting;

  const _PriceHero({required this.painting});

  @override
  Widget build(BuildContext context) {
    final price = painting.price;
    final compareAt = price != null ? price * 1.3 : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sold by ${painting.artistDisplayName ?? 'Artyug creator'}',
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (compareAt != null)
              Text(
                'Rs. ${compareAt.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppColors.textTertiaryOf(context),
                  fontSize: 18,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            if (compareAt != null) const SizedBox(width: 10),
            Text(
              painting.displayPrice.replaceAll('â‚¹', 'Rs. '),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VariantSection extends StatelessWidget {
  final PaintingModel painting;

  const _VariantSection({required this.painting});

  @override
  Widget build(BuildContext context) {
    final sizeOptions = <String>[
      if (painting.sizeText != null && painting.sizeText!.trim().isNotEmpty)
        painting.sizeText!.trim(),
      if (painting.dimensions != null && painting.dimensions!.trim().isNotEmpty)
        painting.dimensions!.trim(),
      'Ready to hang',
    ].toSet().toList();

    const frameOptions = <String>[
      'Wrapped Canvas',
      'Golden Frame',
      'Black Frame',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VariantLabel('Size'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < sizeOptions.length; i++)
                _OptionChip(
                  label: sizeOptions[i],
                  active: i == 0,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _VariantLabel('Frame'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < frameOptions.length; i++)
                _OptionChip(
                  label: frameOptions[i],
                  active: i == 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VariantLabel extends StatelessWidget {
  final String label;

  const _VariantLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: AppColors.textTertiaryOf(context),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool active;

  const _OptionChip({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.textPrimaryOf(context) : AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? AppColors.textPrimaryOf(context) : AppColors.borderOf(context),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppColors.surfaceOf(context) : AppColors.textSecondaryOf(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  final PaintingModel painting;
  final int likesCount;

  const _InfoChips({required this.painting, required this.likesCount});

  @override
  Widget build(BuildContext context) {
    final chips = <(IconData, String)>[
      (Icons.favorite_rounded, '$likesCount likes'),
      (
        Icons.local_offer_rounded,
        painting.price != null ? painting.displayPrice : 'Not listed'
      ),
      if (painting.medium != null) (Icons.brush_rounded, painting.medium!),
      if (painting.dimensions != null)
        (Icons.straighten_rounded, painting.dimensions!),
      if (painting.category != null)
        (Icons.category_rounded, painting.category!),
      if (painting.listingType != null)
        (Icons.sell_outlined, painting.listingType!.replaceAll('_', ' ')),
      if (painting.yearCreated != null)
        (Icons.calendar_month_outlined, '${painting.yearCreated}'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (chip) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip.$1, size: 14, color: AppColors.textSecondaryOf(context)),
                  const SizedBox(width: 6),
                  Text(chip.$2,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActionZone extends StatelessWidget {
  final PaintingModel painting;

  const _ActionZone({required this.painting});

  @override
  Widget build(BuildContext context) {
    final listingType = painting.listingType ?? 'fixed_price';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderStrongOf(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderStrongOf(context)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.remove, size: 16),
                    SizedBox(width: 18),
                    Text('1', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(width: 18),
                    Icon(Icons.add, size: 16),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: painting.isAvailable ? () => _openBuyIntent(context) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB99874),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    listingType == 'auction' ? 'ADD BID' : 'ADD TO CART',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: listingType == 'auction'
                  ? () => _openAuction(context)
                  : painting.isAvailable
                      ? () => _openBuyIntent(context)
                      : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                listingType == 'auction'
                    ? 'PLACE BID'
                    : painting.isAvailable
                        ? 'BUY IT NOW'
                        : (painting.isSold ? 'SOLD' : 'NOT LISTED'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/authenticity-center'),
                  icon: const Icon(Icons.verified_user_rounded, size: 18),
                  label: const Text('Verify'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: 'artyug://artwork/${painting.id}'),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Artwork link copied')),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openAuction(BuildContext context) async {
    try {
      final row = await Supabase.instance.client
          .from('auctions')
          .select('id, status, end_time')
          .eq('painting_id', painting.id)
          .inFilter('status', ['active', 'live', 'upcoming', 'pending'])
          .order('end_time', ascending: true)
          .limit(1)
          .maybeSingle();
      final auctionId = row?['id']?.toString();
      if (auctionId == null || auctionId.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No live auction found for this artwork.')),
        );
        return;
      }
      if (!context.mounted) return;
      context.push('/auction/$auctionId');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open auction right now.')),
      );
    }
  }

  /// Smart buy intent:
  /// - Demo mode → routes to /checkout/{id} (CheckoutScreen handles demo wallet)
  /// - Live mode → direct Razorpay → Solana mainnet memo attestation
  Future<void> _openBuyIntent(BuildContext ctx) async {
    final auth = ctx.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ctx.push('/sign-in');
      return;
    }

    final amountInr = (painting.price ?? 0).toDouble();
    if (amountInr <= 0) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('This artwork has no price set.')),
      );
      return;
    }

    ctx.push('/checkout/${painting.id}', extra: painting);
  }
}

class _TrustRow extends StatelessWidget {
  final PaintingModel painting;

  const _TrustRow({required this.painting});

  @override
  Widget build(BuildContext context) {
    final items = [
      const _TrustTile(
        icon: Icons.local_shipping_outlined,
        title: 'Free Delivery',
        subtitle: 'Pan-India dispatch',
      ),
      const _TrustTile(
        icon: Icons.lock_outline_rounded,
        title: 'Secure Payments',
        subtitle: 'Protected checkout',
      ),
      const _TrustTile(
        icon: Icons.token_rounded,
        title: 'Solana-backed',
        subtitle: 'Certificate ready',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  SizedBox(
                    width: 190,
                    child: items[i],
                  ),
                ],
              ],
            ),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: items[i]),
            ],
          ],
        );
      },
    );
  }
}

class _TrustTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrustTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textPrimaryOf(context), size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionPanel extends StatelessWidget {
  final PaintingModel painting;
  final bool expanded;
  final _ArtworkInfoTab activeTab;
  final ValueChanged<_ArtworkInfoTab> onTabChanged;
  final VoidCallback onToggle;

  const _DescriptionPanel({
    required this.painting,
    required this.expanded,
    required this.activeTab,
    required this.onTabChanged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final description = painting.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _InfoTabButton(
              label: 'About the work',
              active: activeTab == _ArtworkInfoTab.about,
              onTap: () => onTabChanged(_ArtworkInfoTab.about),
            ),
            const SizedBox(width: 10),
            _InfoTabButton(
              label: 'Provenance',
              active: activeTab == _ArtworkInfoTab.provenance,
              onTap: () => onTabChanged(_ArtworkInfoTab.provenance),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: activeTab == _ArtworkInfoTab.about
              ? _AboutWorkPanel(
                  painting: painting,
                  description: description,
                  hasDescription: hasDescription,
                  expanded: expanded,
                  onToggle: onToggle,
                )
              : _ProvenanceCard(painting: painting),
        ),
      ],
    );
  }
}

class _InfoTabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _InfoTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.textPrimaryOf(context) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? AppColors.textPrimaryOf(context)
                : AppColors.textSecondaryOf(context),
            fontSize: 15,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AboutWorkPanel extends StatelessWidget {
  final PaintingModel painting;
  final String? description;
  final bool hasDescription;
  final bool expanded;
  final VoidCallback onToggle;

  const _AboutWorkPanel({
    required this.painting,
    required this.description,
    required this.hasDescription,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final framedSize = painting.sizeText?.trim();
    final medium = painting.medium?.trim();
    final dimensions = painting.dimensions?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasDescription
                    ? description!
                    : 'This artwork is presented as a collectible work ready for display, ownership transfer, and certificate-backed verification.',
                maxLines: expanded ? null : 5,
                overflow:
                    expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 15,
                  height: 1.75,
                  fontStyle: hasDescription ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              if (hasDescription) ...[
                const SizedBox(height: 14),
                Text(
                  painting.isVerifiedArtwork
                      ? 'This work is supported by Artyug authenticity tracking and can be referenced through its verification record.'
                      : 'The work includes marketplace-ready details so collectors can review medium, size, and condition before purchase.',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(expanded ? 'Show less' : 'Read more'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.borderOf(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            children: [
              _LineRow(label: 'Materials', value: medium ?? 'Canvas-ready artwork'),
              _LineRow(
                label: 'Size',
                value: dimensions ?? painting.sizeText ?? 'Open edition sizing',
              ),
              if (framedSize != null && framedSize.isNotEmpty)
                _LineRow(label: 'Framed size', value: framedSize),
              _LineRow(
                label: 'Rarity',
                value: painting.listingType?.trim().isNotEmpty == true
                    ? painting.listingType!
                    : 'Unique',
              ),
              _LineRow(
                label: 'Medium',
                value: medium ?? painting.category ?? 'Collectible artwork',
              ),
              _LineRow(
                label: 'Condition',
                value: painting.isSold
                    ? 'Previously collected work in archived sale condition.'
                    : 'Ready to hang and prepared for collector delivery.',
              ),
              _LineRow(
                label: 'Signature',
                value: painting.isVerifiedArtwork
                    ? 'Backed by Artyug verification and artist record.'
                    : 'Artist signature details available on request.',
              ),
              _LineRow(
                label: 'Certificate of authenticity',
                value: painting.solanaTxId?.isNotEmpty == true
                    ? 'Included with Solana-backed certificate support.'
                    : 'Included through Artyug authenticity center.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProvenanceCard extends StatelessWidget {
  final PaintingModel painting;

  const _ProvenanceCard({required this.painting});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Provenance & Authenticity',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _LineRow(
              label: 'Artwork ID',
              value: painting.id.substring(0, 8).toUpperCase()),
          _LineRow(
              label: 'Creator',
              value: painting.artistDisplayName ?? 'Artyug Artist'),
          _LineRow(
              label: 'Status',
              value: painting.isAvailable
                  ? 'Available'
                  : (painting.isSold ? 'Sold' : 'Not listed')),
          _LineRow(
              label: 'Verification',
              value: painting.isVerifiedArtwork ? 'Verified artwork' : 'Verification pending'),
          _LineRow(
              label: 'NFC',
              value: painting.nfcStatus ?? (painting.hasNfcAttached ? 'attached' : 'not_attached')),
          if (painting.solanaTxId != null && painting.solanaTxId!.isNotEmpty)
            _LineRow(label: 'Solana Tx', value: painting.solanaTxId!),
          _LineRow(
              label: 'Certificate',
              value: 'Available via Artyug authenticity center'),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final String label;
  final String value;

  const _LineRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderOf(context)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

