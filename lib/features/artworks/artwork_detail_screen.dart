import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

class _ArtworkDetailScreenState extends State<ArtworkDetailScreen> {
  PaintingModel? _painting;
  bool _loading = true;
  String? _error;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _likeBusy = false;
  bool _descExpanded = false;

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

  @override
  Widget build(BuildContext context) {
    final painting = _painting;
    if (_loading && painting == null) {
      return _buildLoading();
    }
    if (painting == null) {
      return _buildError();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
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
                          child: _MediaColumn(painting: painting),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: _DetailColumn(
                            painting: painting,
                            isLiked: _isLiked,
                            likesCount: _likesCount,
                            descExpanded: _descExpanded,
                            onToggleDescription: () =>
                                setState(() => _descExpanded = !_descExpanded),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _MediaColumn(painting: painting),
                    const SizedBox(height: 18),
                    _DetailColumn(
                      painting: painting,
                      isLiked: _isLiked,
                      likesCount: _likesCount,
                      descExpanded: _descExpanded,
                      onToggleDescription: () =>
                          setState(() => _descExpanded = !_descExpanded),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: AppColors.background,
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
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.textTertiary, size: 54),
              const SizedBox(height: 12),
              const Text('Unable to open artwork',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_error ?? 'Unknown error',
                  style: const TextStyle(color: AppColors.textSecondary),
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Artwork Detail',
            style: TextStyle(
                color: AppColors.textPrimary,
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
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
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text('$likesCount',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
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

  const _MediaColumn({required this.painting});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderStrong),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: MarketplaceMediaFrame(
            imageUrl: painting.resolvedImageUrl,
            aspectRatio: 1,
            borderRadius: BorderRadius.circular(20),
          ),

        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.security_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Authenticity-ready media with QR and NFC certificate pathways.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailColumn extends StatelessWidget {
  final PaintingModel painting;
  final bool isLiked;
  final int likesCount;
  final bool descExpanded;
  final VoidCallback onToggleDescription;

  const _DetailColumn({
    required this.painting,
    required this.isLiked,
    required this.likesCount,
    required this.descExpanded,
    required this.onToggleDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          painting.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.06,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        _ArtistIdentityCard(painting: painting),
        const SizedBox(height: 14),
        _InfoChips(painting: painting, likesCount: likesCount),
        const SizedBox(height: 16),
        _ActionZone(painting: painting),
        const SizedBox(height: 18),
        _DescriptionPanel(
          description: painting.description,
          expanded: descExpanded,
          onToggle: onToggleDescription,
        ),
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
                      style: const TextStyle(
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
        _ProvenanceCard(painting: painting),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.surfaceVariant,
              backgroundImage: painting.resolvedArtistAvatarUrl != null
                  ? CachedNetworkImageProvider(
                      painting.resolvedArtistAvatarUrl!,
                    )
                  : null,
              child: painting.resolvedArtistAvatarUrl == null
                  ? const Icon(Icons.person_rounded,
                      color: AppColors.textSecondary)
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
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (painting.artistIsVerified ?? false)
                        const Icon(Icons.verified_rounded,
                            color: AppColors.info, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    painting.artistType ?? 'Creator',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
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
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (chip) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip.$1, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(chip.$2,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: painting.isAvailable
                    ? ElevatedButton.icon(
                        onPressed: () => context
                            .push('/checkout/${painting.id}', extra: painting),
                        icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                        label: Text('Buy for ${painting.displayPrice}'),
                      )
                    : OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.block_rounded, size: 18),
                        label: Text(painting.isSold ? 'Sold' : 'Not listed'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                        ClipboardData(text: 'artyug://artwork/${painting.id}'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Artwork link copied')));
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
}

class _DescriptionPanel extends StatelessWidget {
  final String? description;
  final bool expanded;
  final VoidCallback onToggle;

  const _DescriptionPanel(
      {required this.description,
      required this.expanded,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (description == null || description!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About this artwork',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            description!,
            maxLines: expanded ? null : 4,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.55),
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: onToggle,
              child: Text(expanded ? 'Show less' : 'Read more')),
        ],
      ),
    );
  }
}

class _ProvenanceCard extends StatelessWidget {
  final PaintingModel painting;

  const _ProvenanceCard({required this.painting});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Provenance & Authenticity',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
