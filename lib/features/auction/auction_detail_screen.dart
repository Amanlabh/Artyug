/// ArtYug Auction Detail Screen
/// Shows live auction with countdown, bid history, and bid placement.
/// Inspired by the auction UI mockup — offers panel, highest bid, countdown.
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../../providers/auth_provider.dart';
import 'auction_model.dart';
import 'auction_service.dart';

class AuctionDetailScreen extends StatefulWidget {
  final String auctionId;
  final AuctionModel? initial;

  const AuctionDetailScreen({
    super.key,
    required this.auctionId,
    this.initial,
  });

  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen>
    with TickerProviderStateMixin {
  AuctionModel? _auction;
  bool _loading = true;
  String? _error;

  // Real-time channel
  RealtimeChannel? _channel;

  // Countdown timer
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;

  // Bid input
  final _bidController = TextEditingController();
  bool _placingBid = false;

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _auction = widget.initial;
    if (_auction != null) {
      _timeRemaining = _auction!.timeRemaining;
      _loading = false;
    }

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _loadAuction();
    _startCountdown();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _countdownTimer?.cancel();
    _bidController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAuction() async {
    try {
      final auction = await AuctionService.getAuctionById(widget.auctionId);
      if (!mounted) return;
      setState(() {
        _auction = auction;
        _loading = false;
        if (auction != null) _timeRemaining = auction.timeRemaining;
      });
      _subscribeRealtime();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = _auction == null;
      });
    }
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = AuctionService.subscribeToBids(
      auctionId: widget.auctionId,
      onBid: (bid) {
        if (!mounted) return;
        setState(() {
          final existing = _auction;
          if (existing == null) return;
          final updatedBids = [bid, ...existing.recentBids].take(20).toList();
          _auction = AuctionModel(
            id: existing.id,
            paintingId: existing.paintingId,
            sellerId: existing.sellerId,
            startingPrice: existing.startingPrice,
            reservePrice: existing.reservePrice,
            currentHighestBid: bid.amount > (existing.currentHighestBid ?? 0)
                ? bid.amount
                : existing.currentHighestBid,
            currentHighestBidderId:
                bid.amount > (existing.currentHighestBid ?? 0)
                    ? bid.bidderId
                    : existing.currentHighestBidderId,
            currentHighestBidderName:
                bid.amount > (existing.currentHighestBid ?? 0)
                    ? bid.bidderName
                    : existing.currentHighestBidderName,
            currentHighestBidderAvatarUrl:
                bid.amount > (existing.currentHighestBid ?? 0)
                    ? bid.bidderAvatarUrl
                    : existing.currentHighestBidderAvatarUrl,
            startTime: existing.startTime,
            endTime: existing.endTime,
            status: existing.status,
            totalBids: existing.totalBids + 1,
            recentBids: updatedBids,
            painting: existing.painting,
            createdAt: existing.createdAt,
          );
        });
      },
      onAuctionUpdate: (auction) {
        if (!mounted) return;
        setState(() {
          _auction = AuctionModel.fromJson(
            {
              'id': auction.id,
              'painting_id': auction.paintingId,
              'seller_id': auction.sellerId,
              'starting_price': auction.startingPrice,
              'reserve_price': auction.reservePrice,
              'current_highest_bid': auction.currentHighestBid,
              'current_highest_bidder_id': auction.currentHighestBidderId,
              'current_highest_bidder_name': auction.currentHighestBidderName,
              'current_highest_bidder_avatar_url':
                  auction.currentHighestBidderAvatarUrl,
              'start_time': auction.startTime.toIso8601String(),
              'end_time': auction.endTime.toIso8601String(),
              'status': auction.status,
              'total_bids': auction.totalBids,
            },
            bids: _auction?.recentBids,
            painting: _auction?.painting,
          );
        });
      },
    );
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeRemaining = _auction?.timeRemaining ?? Duration.zero;
      });
    });
  }

  Future<void> _placeBid() async {
    final amtStr = _bidController.text.trim().replaceAll(',', '');
    final amt = double.tryParse(amtStr);
    if (amt == null) {
      _showSnack('Enter a valid bid amount');
      return;
    }
    final auction = _auction;
    if (auction == null) return;
    if (amt < auction.minimumNextBid) {
      _showSnack(
          'Minimum bid is ${_currency.format(auction.minimumNextBid)}');
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/sign-in');
      return;
    }

    setState(() => _placingBid = true);
    try {
      await AuctionService.placeBid(
        auctionId: widget.auctionId,
        amount: amt,
      );
      _bidController.clear();
      _showSnack('Bid placed successfully!', success: true);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showSnack('Bid failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _placingBid = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _auction == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_auction == null && _error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.error)),
        ),
      );
    }

    final auction = _auction!;
    final painting = auction.painting;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) return _buildWide(auction, painting, constraints);
            return _buildNarrow(auction, painting);
          },
        ),
      ),
    );
  }

  Widget _buildNarrow(AuctionModel auction, painting) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildTopBar(auction)),
        SliverToBoxAdapter(child: _buildArtworkImage(auction.painting)),
        SliverToBoxAdapter(child: const SizedBox(height: 16)),
        SliverToBoxAdapter(child: _buildCountdownHeader(auction)),
        SliverToBoxAdapter(child: const SizedBox(height: 12)),
        SliverToBoxAdapter(child: _buildBidsList(auction)),
        SliverToBoxAdapter(child: const SizedBox(height: 12)),
        SliverToBoxAdapter(child: _buildSpecifications(auction)),
        SliverToBoxAdapter(child: const SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildWide(AuctionModel auction, painting, BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTopBar(auction),
                const SizedBox(height: 16),
                _buildArtworkImage(auction.painting),
                const SizedBox(height: 16),
                _buildSpecifications(auction),
              ],
            ),
          ),
        ),
        Container(width: 1, color: AppColors.border),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildCountdownHeader(auction),
                const SizedBox(height: 16),
                _buildBidsList(auction),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(AuctionModel auction) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _squareBtn(
            Icons.arrow_back_rounded,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              auction.painting?.title ?? 'Live Auction',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _squareBtn(Icons.share_rounded, onTap: () {
            Clipboard.setData(ClipboardData(
                text: 'artyug://auction/${widget.auctionId}'));
            _showSnack('Auction link copied');
          }),
        ],
      ),
    );
  }

  Widget _squareBtn(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }

  Widget _buildArtworkImage(PaintingModel? painting) {
    if (painting == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: CachedNetworkImage(
            imageUrl: painting.resolvedImageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: AppColors.surfaceVariant,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.broken_image_rounded,
                  color: AppColors.textTertiary, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownHeader(AuctionModel auction) {
    final r = _timeRemaining;
    final ended = r == Duration.zero;
    final highBid = auction.currentHighestBid;
    final minNext = auction.minimumNextBid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Countdown row
          Row(
            children: [
              // Timer chip
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: ended ? 1.0 : _pulseAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ended
                          ? AppColors.surfaceVariant
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: ended
                              ? AppColors.border
                              : AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ended
                              ? Icons.check_circle_rounded
                              : Icons.timer_rounded,
                          size: 14,
                          color: ended
                              ? AppColors.textTertiary
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ended
                              ? 'Auction Ended'
                              : 'Ends in ${_formatDuration(r)}',
                          style: TextStyle(
                            color: ended
                                ? AppColors.textSecondary
                                : AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${auction.totalBids} bids',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Highest offer
          if (highBid != null) ...[
            const Text(
              'Offers',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Highest Offer',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Bids action area
          if (!ended) ...[
            const SizedBox(height: 12),
            _BidInputRow(
              controller: _bidController,
              minBid: minNext,
              currency: _currency,
              loading: _placingBid,
              onBid: _placeBid,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBidsList(AuctionModel auction) {
    final bids = auction.recentBids;
    if (bids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Column(
              children: [
                Icon(Icons.gavel_rounded,
                    color: AppColors.textTertiary, size: 32),
                SizedBox(height: 8),
                Text('No bids yet — be the first!',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Offers',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Separator: asking price
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                      width: 2,
                      height: 14,
                      color: AppColors.primary.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  const Text('Highest Offer',
                      style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    auction.currentHighestBid != null
                        ? 'Accepts in ${_formatDuration(_timeRemaining)}'
                        : 'No bids',
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),

            ...bids.take(8).toList().asMap().entries.map((e) {
              final idx = e.key;
              final bid = e.value;
              return _BidRow(
                bid: bid,
                isHighest: idx == 0,
                currency: _currency,
              );
            }),

            // Asking price separator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                      width: 2,
                      height: 14,
                      color: AppColors.border),
                  const SizedBox(width: 8),
                  const Text('Starting Price',
                      style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    _currency.format(auction.startingPrice),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecifications(AuctionModel auction) {
    final painting = auction.painting;
    if (painting == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Specifications',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context
                      .push('/artwork/${painting.id}', extra: painting),
                  child: const Text('Read More',
                      style: TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (painting.medium != null)
              _SpecRow(label: 'Medium', value: painting.medium!),
            if (painting.dimensions != null)
              _SpecRow(label: 'Size', value: painting.dimensions!),
            if (painting.category != null)
              _SpecRow(label: 'Category', value: painting.category!),
            _SpecRow(label: 'Artist', value: painting.artistDisplayName ?? '—'),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '—';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

// ── Bottom action bar ──────────────────────────────────────────────────────

class _BidInputRow extends StatelessWidget {
  final TextEditingController controller;
  final double minBid;
  final NumberFormat currency;
  final bool loading;
  final VoidCallback onBid;

  const _BidInputRow({
    required this.controller,
    required this.minBid,
    required this.currency,
    required this.loading,
    required this.onBid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Min next bid: ${currency.format(minBid)}',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : onBid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Offer',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bid row ────────────────────────────────────────────────────────────────

class _BidRow extends StatelessWidget {
  final BidModel bid;
  final bool isHighest;
  final NumberFormat currency;

  const _BidRow({
    required this.bid,
    required this.isHighest,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage: bid.bidderAvatarUrl != null
                ? CachedNetworkImageProvider(bid.bidderAvatarUrl!)
                : null,
            child: bid.bidderAvatarUrl == null
                ? Text(
                    (bid.bidderName ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bid.bidderName ?? 'Anonymous',
              style: TextStyle(
                color: isHighest
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight:
                    isHighest ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Text(
                currency.format(bid.amount),
                style: TextStyle(
                  color: isHighest
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isHighest
                      ? AppColors.success
                      : AppColors.border,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
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
