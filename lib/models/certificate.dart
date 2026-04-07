import '../core/config/app_config.dart';

// Model for certificates table
class CertificateModel {
  final String id;
  final String orderId;
  final String artworkId;
  final String artworkTitle;
  final String? artworkMediaUrl;
  final String artistId;
  final String artistName;
  final String ownerId;
  final String ownerName;
  final String purchaseDate;
  final String? blockchainHash;
  final String qrCode;
  final bool nfcEnabled;
  final double? currentMarketPrice;
  final DateTime? createdAt;

  const CertificateModel({
    required this.id,
    required this.orderId,
    required this.artworkId,
    required this.artworkTitle,
    this.artworkMediaUrl,
    required this.artistId,
    required this.artistName,
    required this.ownerId,
    required this.ownerName,
    required this.purchaseDate,
    this.blockchainHash,
    required this.qrCode,
    this.nfcEnabled = false,
    this.currentMarketPrice,
    this.createdAt,
  });

  factory CertificateModel.fromJson(Map<String, dynamic> json) {
    return CertificateModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      artworkId: json['artwork_id'] as String,
      artworkTitle: json['artwork_title'] as String,
      artworkMediaUrl: json['artwork_media_url'] as String?,
      artistId: json['artist_id'] as String,
      artistName: json['artist_name'] as String,
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String,
      purchaseDate: json['purchase_date'] as String,
      blockchainHash: json['blockchain_hash'] as String?,
      qrCode: json['qr_code'] as String,
      nfcEnabled: json['nfc_enabled'] as bool? ?? false,
      currentMarketPrice: json['current_market_price'] != null
          ? (json['current_market_price'] as num).toDouble()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// True when [blockchainHash] is a Solana tx signature or known explorer URL (not a demo `0x…` placeholder).
  bool get isBlockchainAnchored {
    final h = blockchainHash;
    if (h == null || h.isEmpty) return false;
    if (h.startsWith('https://explorer.solana.com')) return true;
    if (h.startsWith('https://solscan.io/')) return true;
    if (h.startsWith('0x')) return false;
    // Base58-encoded Solana signatures are typically 87–88 chars (64 bytes).
    return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{43,128}$').hasMatch(h);
  }

  String get blockchainLabel =>
      isBlockchainAnchored ? 'Solana Anchored' : 'Synthetic Certificate';

  /// Public URL to view the on-chain attestation (Explorer or Solscan).
  /// Null when the certificate is not blockchain-anchored.
  String? get solanaExplorerUrl {
    if (!isBlockchainAnchored) return null;
    final h = blockchainHash!.trim();
    if (h.startsWith('http://') || h.startsWith('https://')) return h;
    final cluster = AppConfig.chainMode.name;
    return 'https://explorer.solana.com/tx/$h?cluster=$cluster';
  }

  /// Raw Solana transaction signature (base58) when the record is on-chain.
  /// Parsed from a bare signature or from explorer / Solscan URLs in [blockchainHash].
  String? get transactionSignature {
    if (blockchainHash == null || blockchainHash!.isEmpty) return null;
    final h = blockchainHash!.trim();
    if (h.startsWith('0x')) return null;
    if (h.startsWith('https://explorer.solana.com/tx/') ||
        h.startsWith('https://solscan.io/tx/')) {
      final part = h.split('/tx/').last;
      final sig = part.split('?').first.split('#').first;
      return sig.isEmpty ? null : sig;
    }
    if (h.startsWith('http://') || h.startsWith('https://')) {
      final m = RegExp(r'/tx/([^/?#]+)').firstMatch(h);
      return m?.group(1);
    }
    if (RegExp(r'^[1-9A-HJ-NP-Za-km-z]{43,128}$').hasMatch(h)) return h;
    return null;
  }

  String get displayTruncatedHash {
    if (blockchainHash == null) return 'N/A';
    final h = blockchainHash!;
    if (h.startsWith('https://explorer.solana.com/tx/') ||
        h.startsWith('https://solscan.io/tx/')) {
      final part = h.split('/tx/').last.split('?').first;
      if (part.length > 20) {
        return '${part.substring(0, 8)}...${part.substring(part.length - 8)}';
      }
      return part;
    }
    if (h.length <= 20) return h;
    return '${h.substring(0, 8)}...${h.substring(h.length - 8)}';
  }
}
