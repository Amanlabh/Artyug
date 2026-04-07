import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../feed/marketplace_media.dart';

/// Premium marketplace painting card used across feed/discovery surfaces.
class PaintingCard extends StatefulWidget {
  final PaintingModel painting;
  final VoidCallback? onLike;
  final bool isLiked;
  final bool showBuyButton;

  const PaintingCard({
    super.key,
    required this.painting,
    this.onLike,
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
          onTap: () => context.push('/artwork/${painting.id}', extra: painting),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  MarketplaceMediaFrame(
                    imageUrl: painting.resolvedImageUrl,
                    aspectRatio: 4 / 3,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _CreatorPill(
                      name: painting.artistDisplayName ?? 'Artyug Artist',
                      verified: painting.artistIsVerified ?? false,
                      avatarUrl: painting.resolvedArtistAvatarUrl,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _StatusPill(
                      label: painting.isBoosted
                          ? 'FEATURED'
                          : (painting.category ?? 'COLLECTIBLE').toUpperCase(),
                      color: painting.isBoosted
                          ? AppColors.primary
                          : AppColors.info,
                    ),
                  ),
                  if (painting.price != null)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.66),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          painting.displayPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Text(
                  painting.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    _ActionIcon(
                      menuContext: context,
                      icon: widget.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${painting.likesCount}',
                      active: widget.isLiked,
                      onTap: widget.onLike,
                    ),
                    const SizedBox(width: 10),
                    _ActionIcon(
                      menuContext: context,
                      icon: Icons.verified_user_outlined,
                      label: 'Auth',
                      onTap: () => context.push('/authenticity-center'),
                    ),
                    const Spacer(),
                    if (widget.showBuyButton)
                      painting.isAvailable
                          ? _PrimaryPillButton(
                              label: 'Buy',
                              onTap: () => context.push(
                                  '/checkout/${painting.id}',
                                  extra: painting),
                            )
                          : _MutedPill(
                              menuContext: context,
                              label:
                                  painting.isSold ? 'Sold' : 'Not listed',
                            ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorPill extends StatelessWidget {
  final String name;
  final bool verified;
  final String? avatarUrl;

  const _CreatorPill({
    required this.name,
    required this.verified,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: AppColors.surfaceHigh,
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl!)
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? const Icon(Icons.person, size: 11, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (verified) ...[
            const SizedBox(width: 5),
            const Icon(Icons.verified_rounded, size: 12, color: AppColors.info),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final BuildContext menuContext;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ActionIcon({
    required this.menuContext,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(menuContext);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? const Color(0xFFFF5D7A) : muted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFFFF5D7A) : muted,
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

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryPillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MutedPill extends StatelessWidget {
  final BuildContext menuContext;
  final String label;

  const _MutedPill({required this.menuContext, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMutedOf(menuContext),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderOf(menuContext)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondaryOf(menuContext),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
