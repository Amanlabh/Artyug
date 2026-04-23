/// ArtYug Auction List / Browse Screen
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import 'auction_model.dart';
import 'auction_service.dart';

class AuctionListScreen extends StatefulWidget {
  const AuctionListScreen({super.key});

  @override
  State<AuctionListScreen> createState() => _AuctionListScreenState();
}

class _AuctionListScreenState extends State<AuctionListScreen> {
  List<AuctionModel> _auctions = [];
  bool _loading = true;
  String? _error;

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
      final data = await AuctionService.getActiveAuctions();
      if (!mounted) return;
      setState(() { _auctions = data; _loading = false; });
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.textTertiary, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                )),
              )
            else if (_auctions.isEmpty)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gavel_rounded,
                        color: AppColors.textTertiary, size: 48),
                    const SizedBox(height: 12),
                    const Text('No active auctions',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Check back soon for live auctions',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                  ],
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _AuctionCard(
                      auction: _auctions[i],
                      currency: _currency,
                      onTap: () => context.push(
                        '/auction/${_auctions[i].id}',
                        extra: _auctions[i],
                      ),
                    ),
                    childCount: _auctions.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text('Live Auctions',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5)),
                    Text('Bid on exclusive artworks',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Live badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: AppColors.error, size: 6),
                    SizedBox(width: 5),
                    Text('LIVE',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuctionCard extends StatelessWidget {
  final AuctionModel auction;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _AuctionCard({
    required this.auction,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final painting = auction.painting;
    final highBid = auction.currentHighestBid;
    final r = auction.timeRemaining;

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
            // Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (painting?.resolvedImageUrl.isNotEmpty == true)
                    CachedNetworkImage(
                      imageUrl: painting!.resolvedImageUrl,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.palette_rounded,
                          color: AppColors.textTertiary, size: 40),
                    ),
                  // Gradient overlay
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: AppColors.cardOverlay),
                    ),
                  ),
                  // Timer badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: 10,
                            color: r.inHours < 1
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            auction.formattedTimeRemaining,
                            style: TextStyle(
                              color: r.inHours < 1
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bids badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${auction.totalBids} bids',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    painting?.title ?? 'Untitled Artwork',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    painting?.artistDisplayName ?? 'Artist',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Highest Bid',
                                style: TextStyle(
                                    color: AppColors.textTertiary, fontSize: 10)),
                            Text(
                              highBid != null
                                  ? currency.format(highBid)
                                  : 'No bids',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Bid',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
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
