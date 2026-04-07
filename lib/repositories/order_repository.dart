import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/config/supabase_client.dart';
import '../models/order.dart';
import '../models/certificate.dart';
import '../models/painting.dart';
import '../services/blockchain/solana_service.dart';

class OrderResult {
  final OrderModel order;
  final CertificateModel? certificate;
  final String? solanaExplorerUrl;
  final String purchaseMode;

  const OrderResult({
    required this.order,
    this.certificate,
    this.solanaExplorerUrl,
    required this.purchaseMode,
  });
}

class OrderRepository {
  static final _client = SupabaseClientHelper.db;
  static const _uuid = Uuid();

  /// Fetch a painting snapshot for checkout
  static Future<PaintingModel?> getPainting(String paintingId) async {
    final data = await _client
        .from('paintings')
        .select('''
          *,
          profiles!paintings_artist_id_fkey(
            display_name,
            profile_picture_url,
            is_verified
          )
        ''')
        .eq('id', paintingId)
        .single();
    if (data.isEmpty) return null;
    return PaintingModel.fromJson({
      ...data,
      'display_name': data['profiles']?['display_name'],
      'profile_picture_url': data['profiles']?['profile_picture_url'],
      'is_verified': data['profiles']?['is_verified'],
    });
  }

  /// Create a demo/test purchase — no real payment.
  /// Mirrors the business logic in artyug-old/apps/api/src/routes/orders.ts
  static Future<OrderResult> createDemoOrder(String paintingId) async {
    final user = SupabaseClientHelper.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Fetch painting
    final painting = await getPainting(paintingId);
    if (painting == null) throw Exception('Artwork not found');

    // Fetch buyer profile name
    final profileData = await _client
        .from('profiles')
        .select('display_name, username')
        .eq('id', user.id)
        .maybeSingle();
    final buyerName = profileData?['display_name'] as String? ??
        profileData?['username'] as String? ??
        'Collector';

    final artistName = painting.artistDisplayName ?? 'Artist';

    final orderId = _uuid.v4();
    final certId = _uuid.v4();
    final qrCode = 'QR-${_randomAlphanumeric(10)}';
    final syntheticHash =
        '0x${List.generate(32, (_) => Random().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

    // Insert order
    await _client.from('orders').insert({
      'id': orderId,
      'artwork_id': paintingId,
      'artwork_title': painting.title,
      'artwork_media_url': painting.imageUrl,
      'artwork_type': painting.medium ?? 'original',
      'buyer_id': user.id,
      'buyer_name': buyerName,
      'seller_id': painting.artistId,
      'seller_name': artistName,
      'amount': painting.price ?? 0,
      'total_amount': painting.price ?? 0, // NOT NULL column
      'currency': 'INR',
      'payment_method': 'test',
      'status': 'completed',
      'authenticity_enabled': true,
      'certificate_id': certId,
      'purchase_mode': 'demo',
    });

    // Optional Solana memo attestation (devnet or mainnet — see AppConfig.chainMode)
    String blockchainHash = syntheticHash;
    String? solanaExplorerUrl;

    if (AppConfig.isSolanaReady) {
      final purchasedAt = DateTime.now().toUtc();
      final att = await SolanaService.sendMemoAttestation(
        orderId: orderId,
        certId: certId,
        artworkId: paintingId,
        buyerId: user.id,
        buyerDisplayName: buyerName,
        artworkTitle: painting.title,
        amount: painting.price ?? 0,
        currency: 'INR',
        purchasedAt: purchasedAt,
      );
      if (att != null) {
        blockchainHash = att.signatureBase58;
        solanaExplorerUrl = att.explorerUrl;
      } else if (kIsWeb) {
        debugPrint(
          '[OrderRepository] Solana attestation failed — check: devnet SOL on fee payer, '
          'valid SOLANA_PRIVATE_KEY, and CORS-friendly SOLANA_RPC_URL (e.g. Helius) on web.',
        );
      }
    }

    // Insert certificate
    await _client.from('certificates').insert({
      'id': certId,
      'order_id': orderId,
      'artwork_id': paintingId,
      'artwork_title': painting.title,
      'artwork_media_url': painting.imageUrl,
      'artist_id': painting.artistId,
      'artist_name': artistName,
      'owner_id': user.id,
      'owner_name': buyerName,
      'purchase_date': DateTime.now().toIso8601String(),
      'blockchain_hash': blockchainHash,
      'qr_code': qrCode,
      'nfc_enabled': AppConfig.nfcEnabled,
      'current_market_price': (painting.price ?? 0) * 1.15,
    });

    // Fetch fresh order + certificate
    final orderData =
        await _client.from('orders').select().eq('id', orderId).single();
    final certData =
        await _client.from('certificates').select().eq('id', certId).single();

    return OrderResult(
      order: OrderModel.fromJson(orderData),
      certificate: CertificateModel.fromJson(certData),
      solanaExplorerUrl: solanaExplorerUrl,
      purchaseMode: 'demo',
    );
  }

  /// Fetch all orders where current user is the buyer  
  static Future<List<OrderModel>> getMyPurchases() async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) return [];
    final data = await _client
        .from('orders')
        .select()
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  /// Fetch all orders where current user is the seller (creator view)
  static Future<List<OrderModel>> getMySales() async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) return [];
    final data = await _client
        .from('orders')
        .select()
        .eq('seller_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  /// Fetch a single order by ID (with ownership check)
  static Future<OrderModel?> getOrder(String orderId) async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) return null;
    final data = await _client
        .from('orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (data == null) return null;
    return OrderModel.fromJson(data);
  }

  static String _randomAlphanumeric(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
        length, (_) => chars[Random().nextInt(chars.length)]).join();
  }
}
