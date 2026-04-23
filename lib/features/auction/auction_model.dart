/// ArtYug Auction Model
/// Represents an auction for an artwork with live bidding.
library;

import '../../../models/painting.dart';

class AuctionModel {
  final String id;
  final String paintingId;
  final String sellerId;
  final double startingPrice;
  final double? reservePrice;
  final double? currentHighestBid;
  final String? currentHighestBidderId;
  final String? currentHighestBidderName;
  final String? currentHighestBidderAvatarUrl;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // 'pending' | 'active' | 'ended' | 'cancelled'
  final int totalBids;
  final List<BidModel> recentBids;
  final PaintingModel? painting;
  final DateTime? createdAt;

  const AuctionModel({
    required this.id,
    required this.paintingId,
    required this.sellerId,
    required this.startingPrice,
    this.reservePrice,
    this.currentHighestBid,
    this.currentHighestBidderId,
    this.currentHighestBidderName,
    this.currentHighestBidderAvatarUrl,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.totalBids = 0,
    this.recentBids = const [],
    this.painting,
    this.createdAt,
  });

  bool get isActive => status == 'active' && endTime.isAfter(DateTime.now());
  bool get isEnded => status == 'ended' || endTime.isBefore(DateTime.now());
  bool get isPending => status == 'pending';

  Duration get timeRemaining {
    final remaining = endTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get formattedTimeRemaining {
    final r = timeRemaining;
    if (r == Duration.zero) return 'Ended';
    final h = r.inHours;
    final m = r.inMinutes % 60;
    final s = r.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  double get minimumNextBid {
    final current = currentHighestBid ?? startingPrice;
    // Minimum increment: 5% or ₹500, whichever is higher
    final pct = current * 0.05;
    return current + (pct > 500 ? pct : 500);
  }

  factory AuctionModel.fromJson(Map<String, dynamic> json,
      {List<BidModel>? bids, PaintingModel? painting}) {
    return AuctionModel(
      id: json['id'] as String,
      paintingId: json['painting_id'] as String,
      sellerId: json['seller_id'] as String,
      startingPrice: (json['starting_price'] as num).toDouble(),
      reservePrice: json['reserve_price'] != null
          ? (json['reserve_price'] as num).toDouble()
          : null,
      currentHighestBid: json['current_highest_bid'] != null
          ? (json['current_highest_bid'] as num).toDouble()
          : null,
      currentHighestBidderId:
          json['current_highest_bidder_id'] as String?,
      currentHighestBidderName:
          json['current_highest_bidder_name'] as String?,
      currentHighestBidderAvatarUrl:
          json['current_highest_bidder_avatar_url'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      status: json['status'] as String? ?? 'pending',
      totalBids: (json['total_bids'] as num?)?.toInt() ?? 0,
      recentBids: bids ?? [],
      painting: painting,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class BidModel {
  final String id;
  final String auctionId;
  final String bidderId;
  final String? bidderName;
  final String? bidderAvatarUrl;
  final double amount;
  final DateTime createdAt;
  final String status; // 'active' | 'outbid' | 'won'

  const BidModel({
    required this.id,
    required this.auctionId,
    required this.bidderId,
    this.bidderName,
    this.bidderAvatarUrl,
    required this.amount,
    required this.createdAt,
    required this.status,
  });

  factory BidModel.fromJson(Map<String, dynamic> json) {
    return BidModel(
      id: json['id'] as String,
      auctionId: json['auction_id'] as String,
      bidderId: json['bidder_id'] as String,
      bidderName: json['bidder_name'] as String? ??
          json['display_name'] as String?,
      bidderAvatarUrl: json['bidder_avatar_url'] as String? ??
          json['profile_picture_url'] as String?,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String? ?? 'active',
    );
  }
}
