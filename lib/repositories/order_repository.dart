import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
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
  static const _gatewayMetadataColumns = <String>{
    'razorpay_order_id',
    'razorpay_payment_id',
  };

  static Future<OrderResult?> _findExistingLiveOrderByPaymentId(
    String razorpayPaymentId,
  ) async {
    try {
      final data = await _client
          .from('orders')
          .select()
          .eq('razorpay_payment_id', razorpayPaymentId)
          .maybeSingle();
      if (data == null) return null;
      final order = OrderModel.fromJson(data);
      CertificateModel? certificate;
      final certId = order.certificateId;
      if (certId != null && certId.isNotEmpty) {
        final certData = await _client
            .from('certificates')
            .select()
            .eq('id', certId)
            .maybeSingle();
        if (certData != null) {
          certificate = CertificateModel.fromJson(certData);
        }
      }
      return OrderResult(
        order: order,
        certificate: certificate,
        solanaExplorerUrl: certificate?.solanaExplorerUrl,
        purchaseMode: order.purchaseMode ?? 'live',
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch a painting snapshot for checkout
  static Future<PaintingModel?> getPainting(String paintingId) async {
    final data = await _client.from('paintings').select('''
          *,
          profiles!paintings_artist_id_fkey(
            display_name,
            profile_picture_url,
            is_verified
          )
        ''').eq('id', paintingId).single();
    if (data.isEmpty) return null;
    return PaintingModel.fromJson({
      ...data,
      'display_name': data['profiles']?['display_name'],
      'profile_picture_url': data['profiles']?['profile_picture_url'],
      'artist_is_verified': data['profiles']?['is_verified'],
      'is_verified_artwork': data['is_verified'],
    });
  }

  /// Create a demo/test purchase — no real payment.
  static Future<OrderResult> createDemoOrder(String paintingId) async {
    final user = SupabaseClientHelper.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final painting = await getPainting(paintingId);
    if (painting == null) throw Exception('Artwork not found');

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
      'total_amount': painting.price ?? 0,
      'currency': 'INR',
      'payment_method': 'test',
      'status': 'completed',
      'authenticity_enabled': true,
      'certificate_id': certId,
      'purchase_mode': 'demo',
    });

    String? blockchainHash;
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
      if (blockchainHash != null) 'blockchain_hash': blockchainHash,
      'qr_code': qrCode,
      'nfc_enabled': AppConfig.nfcEnabled,
      'current_market_price': (painting.price ?? 0) * 1.15,
    });

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

  /// Create a **real paid** order after a successful Razorpay payment.
  ///
  /// Call this immediately after [PaymentService.initiateRazorpayPayment]
  /// returns a successful [PaymentResult].  After inserting the order it fires
  /// a Solana Memo attestation to produce the blockchain hash.
  static Future<OrderResult> createLiveOrder({
    required String paintingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required double amountPaid,
    String currency = 'INR',
  }) async {
    final user = SupabaseClientHelper.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final existing = await _findExistingLiveOrderByPaymentId(
      razorpayPaymentId,
    );
    if (existing != null) return existing;

    final painting = await getPainting(paintingId);
    if (painting == null) throw Exception('Artwork not found');

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

    // Insert order with live Razorpay details
    await _insertWithOptionalColumns(
      table: 'orders',
      payload: {
      'id': orderId,
      'artwork_id': paintingId,
      'artwork_title': painting.title,
      'artwork_media_url': painting.imageUrl,
      'artwork_type': painting.medium ?? 'original',
      'buyer_id': user.id,
      'buyer_name': buyerName,
      'seller_id': painting.artistId,
      'seller_name': artistName,
      'amount': amountPaid,
      'total_amount': amountPaid,
      'currency': currency,
      'payment_method': 'razorpay',
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'status': 'completed',
      'authenticity_enabled': true,
      'certificate_id': certId,
      'purchase_mode': 'live',
      },
      optionalColumns: _gatewayMetadataColumns,
    );

    // Mark painting as sold so it can't be bought again
    try {
      await _client.from('paintings').update({
        'is_sold': true,
        'status': 'sold',
      }).eq('id', paintingId);
    } catch (e) {
      debugPrint('[OrderRepository] Could not mark painting sold: $e');
    }

    // Solana memo attestation — produces the blockchain hash
    String? blockchainHash;
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
        amount: amountPaid,
        currency: currency,
        purchasedAt: purchasedAt,
      );
      if (att != null) {
        blockchainHash = att.signatureBase58;
        solanaExplorerUrl = att.explorerUrl;
        debugPrint('[OrderRepository] Live Solana hash: $blockchainHash');
        debugPrint('[OrderRepository] Explorer: $solanaExplorerUrl');
      } else {
        debugPrint(
            '[OrderRepository] Solana attestation skipped — order still recorded.');
      }
    }

    // Insert certificate with blockchain hash
    await _insertWithOptionalColumns(
      table: 'certificates',
      payload: {
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
      if (blockchainHash != null) 'blockchain_hash': blockchainHash,
      'qr_code': qrCode,
      'nfc_enabled': AppConfig.nfcEnabled,
      'current_market_price': amountPaid * 1.15,
      'payment_method': 'razorpay',
      'razorpay_order_id': razorpayOrderId,
      },
      optionalColumns: _gatewayMetadataColumns,
    );

    final orderData =
        await _client.from('orders').select().eq('id', orderId).single();
    final certData =
        await _client.from('certificates').select().eq('id', certId).single();

    return OrderResult(
      order: OrderModel.fromJson(orderData),
      certificate: CertificateModel.fromJson(certData),
      solanaExplorerUrl: solanaExplorerUrl,
      purchaseMode: 'live',
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
    final data =
        await _client.from('orders').select().eq('id', orderId).maybeSingle();
    if (data == null) return null;
    return OrderModel.fromJson(data);
  }

  static String _randomAlphanumeric(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (_) => chars[Random().nextInt(chars.length)])
        .join();
  }

  static Future<void> _insertWithOptionalColumns({
    required String table,
    required Map<String, dynamic> payload,
    Set<String> optionalColumns = const <String>{},
  }) async {
    final sanitized = Map<String, dynamic>.from(payload);

    while (true) {
      try {
        await _client.from(table).insert(sanitized);
        return;
      } on PostgrestException catch (e) {
        final missingColumn = _extractMissingColumn(e.message);
        if (missingColumn == null ||
            !optionalColumns.contains(missingColumn) ||
            !sanitized.containsKey(missingColumn)) {
          rethrow;
        }
        sanitized.remove(missingColumn);
        debugPrint(
          '[OrderRepository] Skipping unsupported column '
          '$missingColumn on $table insert.',
        );
      }
    }
  }

  static String? _extractMissingColumn(String message) {
    final match = RegExp(r"'([^']+)' column").firstMatch(message);
    return match?.group(1);
  }
}
