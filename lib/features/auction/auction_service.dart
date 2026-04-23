/// ArtYug Auction Service
/// Handles CRUD + real-time subscription for auctions and bids.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auction_model.dart';
import '../../models/painting.dart';

class AuctionService {
  static final _client = Supabase.instance.client;

  /// Fetch active auctions (paginated) with joined painting info.
  static Future<List<AuctionModel>> getActiveAuctions({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _client
        .from('auctions')
        .select('''
          *,
          paintings (
            id, title, image_url, price, artist_id,
            profiles:artist_id ( display_name, profile_picture_url, is_verified )
          ),
          bids (
            id, auction_id, bidder_id, amount, status, created_at,
            profiles:bidder_id ( display_name, profile_picture_url )
          )
        ''')
        .eq('status', 'active')
        .order('end_time', ascending: true)
        .range(offset, offset + limit - 1);

    return _parseAuctions(data as List<dynamic>);
  }

  /// Fetch a single auction by ID.
  static Future<AuctionModel?> getAuctionById(String auctionId) async {
    final data = await _client
        .from('auctions')
        .select('''
          *,
          paintings (
            id, title, image_url, price, artist_id, description, medium,
            dimensions, style_tags, category, is_for_sale, is_sold,
            profiles:artist_id ( display_name, profile_picture_url, is_verified, artist_type )
          ),
          bids (
            id, auction_id, bidder_id, amount, status, created_at,
            profiles:bidder_id ( display_name, profile_picture_url )
          )
        ''')
        .eq('id', auctionId)
        .single();

    return _parseAuction(data as Map<String, dynamic>);
  }

  /// Fetch auctions for an artist.
  static Future<List<AuctionModel>> getArtistAuctions(String artistId) async {
    final data = await _client
        .from('auctions')
        .select('''
          *,
          paintings!inner (
            id, title, image_url, price, artist_id,
            profiles:artist_id ( display_name, profile_picture_url, is_verified )
          )
        ''')
        .eq('paintings.artist_id', artistId)
        .order('created_at', ascending: false);

    return _parseAuctions(data as List<dynamic>);
  }

  /// Place a bid on an auction.
  static Future<BidModel> placeBid({
    required String auctionId,
    required double amount,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Call DB function for atomic bid placement
    final result = await _client.rpc('place_bid', params: {
      'p_auction_id': auctionId,
      'p_bidder_id': user.id,
      'p_amount': amount,
    });

    if (result == null) throw Exception('Bid placement failed');
    return BidModel.fromJson(result as Map<String, dynamic>);
  }

  /// Subscribe to real-time bid updates for an auction.
  static RealtimeChannel subscribeToBids({
    required String auctionId,
    required void Function(BidModel bid) onBid,
    required void Function(AuctionModel auction) onAuctionUpdate,
  }) {
    final channel = _client.channel('auction:$auctionId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'bids',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'auction_id',
        value: auctionId,
      ),
      callback: (payload) {
        try {
          final bid = BidModel.fromJson(payload.newRecord);
          onBid(bid);
        } catch (_) {}
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'auctions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: auctionId,
      ),
      callback: (payload) {
        try {
          final auction = AuctionModel.fromJson(payload.newRecord);
          onAuctionUpdate(auction);
        } catch (_) {}
      },
    );

    channel.subscribe();
    return channel;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static List<AuctionModel> _parseAuctions(List<dynamic> data) {
    return data
        .map((e) => _parseAuction(e as Map<String, dynamic>))
        .whereType<AuctionModel>()
        .toList();
  }

  static AuctionModel? _parseAuction(Map<String, dynamic> json) {
    try {
      final paintingJson = json['paintings'] as Map<String, dynamic>?;
      PaintingModel? painting;
      if (paintingJson != null) {
        final profileJson =
            paintingJson['profiles'] as Map<String, dynamic>?;
        painting = PaintingModel(
          id: paintingJson['id'] as String,
          artistId: paintingJson['artist_id'] as String,
          title: paintingJson['title'] as String,
          description: paintingJson['description'] as String?,
          medium: paintingJson['medium'] as String?,
          dimensions: paintingJson['dimensions'] as String?,
          imageUrl: paintingJson['image_url'] as String? ?? '',
          price: paintingJson['price'] != null
              ? (paintingJson['price'] as num).toDouble()
              : null,
          isForSale: paintingJson['is_for_sale'] as bool? ?? false,
          isSold: paintingJson['is_sold'] as bool? ?? false,
          styleTags: (paintingJson['style_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          category: paintingJson['category'] as String?,
          artistDisplayName: profileJson?['display_name'] as String?,
          artistProfilePictureUrl:
              profileJson?['profile_picture_url'] as String?,
          artistIsVerified: profileJson?['is_verified'] as bool?,
          artistType: profileJson?['artist_type'] as String?,
        );
      }

      final bidsRaw = json['bids'] as List<dynamic>? ?? [];
      final bids = bidsRaw
          .map((b) {
            try {
              final bJson = b as Map<String, dynamic>;
              final profJson = bJson['profiles'] as Map<String, dynamic>?;
              return BidModel(
                id: bJson['id'] as String,
                auctionId: bJson['auction_id'] as String,
                bidderId: bJson['bidder_id'] as String,
                bidderName: profJson?['display_name'] as String?,
                bidderAvatarUrl:
                    profJson?['profile_picture_url'] as String?,
                amount: (bJson['amount'] as num).toDouble(),
                createdAt: DateTime.parse(bJson['created_at'] as String),
                status: bJson['status'] as String? ?? 'active',
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<BidModel>()
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

      return AuctionModel.fromJson(json, bids: bids, painting: painting);
    } catch (e) {
      return null;
    }
  }
}
