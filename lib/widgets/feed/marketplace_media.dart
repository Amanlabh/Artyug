import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class MarketplaceMediaFrame extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;
  final BorderRadius borderRadius;
  final bool showGradientOverlay;
  final String? heroTag;

  const MarketplaceMediaFrame({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 4 / 3,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.showGradientOverlay = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      Widget empty = ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: const _MediaFallback(),
        ),
      );
      if (heroTag != null) {
        empty = Hero(tag: heroTag!, child: empty);
      }
      return empty;
    }

    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const MarketplaceShimmer(),
              errorWidget: (_, __, ___) => const _MediaFallback(),
            ),
            if (showGradientOverlay)
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.cardOverlay),
              ),
          ],
        ),
      ),
    );

    if (heroTag != null) {
      content = Hero(tag: heroTag!, child: content);
    }
    return content;
  }
}

class MarketplaceShimmer extends StatefulWidget {
  const MarketplaceShimmer({super.key});

  @override
  State<MarketplaceShimmer> createState() => _MarketplaceShimmerState();
}

class _MarketplaceShimmerState extends State<MarketplaceShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _position = Tween<double>(begin: -1.2, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _position,
      builder: (_, __) {
        final muted = AppColors.surfaceMutedOf(context);
        final hi = AppColors.surfaceHighOf(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_position.value, -0.1),
              end: Alignment(_position.value + 1.1, 0.1),
              colors: [muted, hi, muted],
            ),
          ),
        );
      },
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMutedOf(context),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textTertiaryOf(context),
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            'Artwork unavailable',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
