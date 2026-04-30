import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../feed/marketplace_media.dart';

/// Premium marketplace painting card used across feed/discovery surfaces.
class PaintingCard extends StatefulWidget {
  final PaintingModel painting;
  final VoidCallback? onLike;
  final VoidCallback? onTap;
  final bool isLiked;
  final bool showBuyButton;

  const PaintingCard({
    super.key,
    required this.painting,
    this.onLike,
    this.onTap,
    this.isLiked = false,
    this.showBuyButton = true,
  });

  @override
  State<PaintingCard> createState() => _PaintingCardState();
}

class _PaintingCardState extends State<PaintingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final painting = widget.painting;
    final specs = <String>[
      if (painting.medium != null && painting.medium!.trim().isNotEmpty)
        painting.medium!.trim(),
      if (painting.dimensions != null && painting.dimensions!.trim().isNotEmpty)
        painting.dimensions!.trim(),
      if (painting.category != null && painting.category!.trim().isNotEmpty)
        'on ${painting.category!.trim()}',
    ].join(', ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -4.0 : 0.0, 0),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.borderStrongOf(context),
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: AppColors.cardShadows(context, hovered: _hovered),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            widget.onTap?.call();
            context.push('/artwork/${painting.id}', extra: painting);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  MarketplaceMediaFrame(
                    imageUrl: painting.resolvedImageUrl,
                    aspectRatio: 1,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.58),
                          ],
                          stops: const [0.62, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.18),
                            foregroundImage:
                                painting.resolvedArtistAvatarUrl != null &&
                                        painting.resolvedArtistAvatarUrl!
                                            .trim()
                                            .isNotEmpty
                                    ? NetworkImage(
                                        painting.resolvedArtistAvatarUrl!,
                                      )
                                    : null,
                            child: Text(
                              ((painting.artistDisplayName ?? 'A')
                                              .trim()
                                              .isNotEmpty
                                          ? (painting.artistDisplayName ?? 'A')
                                              .trim()
                                              .substring(0, 1)
                                          : 'A')
                                      .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              painting.artistDisplayName ?? 'Artyug Artist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (painting.artistIsVerified ?? false) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: AppColors.info,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  painting.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ),
              if (specs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    specs,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              if (painting.price != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Text(
                    painting.displayPrice.replaceAll('₹', 'Rs. '),
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
