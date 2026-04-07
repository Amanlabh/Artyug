import 'dart:convert';
import 'dart:typed_data';

import 'package:bs58/bs58.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

/// Successful memo attestation: store [signatureBase58] on the certificate; open [explorerUrl] in a browser.
class SolanaAttestationResult {
  final String signatureBase58;
  final String explorerUrl;

  const SolanaAttestationResult({
    required this.signatureBase58,
    required this.explorerUrl,
  });
}

/// Solana attestation service — writes a Memo program transaction to Solana
/// as proof of purchase. Works on devnet and mainnet.
///
/// **Custodial:** your `SOLANA_PRIVATE_KEY` (fee payer) signs; buyers do **not**
/// need Phantom / WalletConnect. Memo text is **public** on-chain — do not put
/// secrets there. For production, prefer signing on a server or Edge Function
/// instead of shipping a private key in a web/mobile client bundle.
///
/// Requires in .env:
///   SOLANA_PRIVATE_KEY=<base58-encoded 64-byte keypair or 32-byte seed>
///   SOLANA_RPC_URL=… (Flutter **web** needs CORS-friendly RPC, e.g. Helius devnet URL)
///
/// If keys are absent the method returns null and the caller stores a
/// synthetic hash — the platform continues to work without blockchain.
class SolanaService {
  SolanaService._();

  static const String _memoProgram =
      'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr';

  /// SPL Memo instruction data max length (bytes).
  static const int _memoMaxBytes = 566;

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Builds, signs, and sends a Memo transaction to Solana.
  /// Returns signature + Solscan URL, or null on failure.
  ///
  /// **Flutter web:** use a CORS-enabled RPC (e.g. Helius) in `SOLANA_RPC_URL`.
  static Future<SolanaAttestationResult?> sendMemoAttestation({
    required String orderId,
    required String certId,
    required String artworkId,
    required String buyerId,
    required String buyerDisplayName,
    required String artworkTitle,
    required double amount,
    required String currency,
    required DateTime purchasedAt,
  }) async {
    if (!AppConfig.isSolanaReady) {
      debugPrint(
          '[Solana] Not ready: ${AppConfig.solanaBlockReason ?? "unknown"}');
      return null;
    }
    if (kIsWeb) {
      debugPrint(
        '[Solana] Running on web — if RPC fails, try SOLANA_RPC_URL from a '
        'provider that allows browser CORS, or use mobile/desktop.',
      );
    }

    try {
      final rpcUrl = AppConfig.solanaRpcUrl;
      final privateKeyB58 = AppConfig.solanaPrivateKey!;

      // ── 1. Decode keypair ─────────────────────────────────────────────────
      final keypairBytes = base58.decode(privateKeyB58);
      late final Uint8List seedBytes;
      late final Uint8List pubKeyBytes;

      if (keypairBytes.length == 64) {
        // [32-byte seed | 32-byte public key] (Solana CLI / Phantom export)
        seedBytes = keypairBytes.sublist(0, 32);
        pubKeyBytes = keypairBytes.sublist(32, 64);
      } else if (keypairBytes.length == 32) {
        // 32-byte secret seed only
        seedBytes = keypairBytes;
        final algorithm = Ed25519();
        final kp = await algorithm.newKeyPairFromSeed(seedBytes);
        final pub = await kp.extractPublicKey();
        pubKeyBytes = Uint8List.fromList(pub.bytes);
      } else {
        debugPrint(
            '[Solana] Invalid key length ${keypairBytes.length} (need 32 or 64 bytes base58-decoded)');
        return null;
      }

      // ── 2. Get latest blockhash ───────────────────────────────────────────
      final blockhash = await _getLatestBlockhash(rpcUrl);
      if (blockhash == null) return null;

      // ── 3. Build Memo payload (UTF-8, max [_memoMaxBytes] — on-chain public)
      final purchaseIso = purchasedAt.toUtc().toIso8601String();
      final memoBytes = _buildMemoPayloadUtf8(
        orderId: orderId,
        certId: certId,
        artworkId: artworkId,
        buyerId: buyerId,
        buyerDisplayName: buyerDisplayName,
        artworkTitle: artworkTitle,
        amount: amount,
        currency: currency,
        purchaseIso: purchaseIso,
      );

      // ── 4. Build transaction message bytes ────────────────────────────────
      final messageBytes = _buildMemoMessage(
        senderPubKey: pubKeyBytes,
        memoProgramId: base58.decode(_memoProgram),
        memoData: memoBytes,
        recentBlockhash: base58.decode(blockhash),
      );

      // ── 5. Sign with Ed25519 ──────────────────────────────────────────────
      final signature = await _signEd25519(
        messageBytes: messageBytes,
        seed: seedBytes,
      );
      if (signature == null) return null;

      // ── 6. Build and send signed transaction ──────────────────────────────
      final signedTx = _buildSignedTransaction(
        messageBytes: messageBytes,
        signature: signature,
      );
      var txSig = await _sendTransaction(rpcUrl, signedTx, skipPreflight: false);
      txSig ??= await _sendTransaction(rpcUrl, signedTx, skipPreflight: true);
      if (txSig == null) return null;

      final clusterParam =
          AppConfig.chainMode == ChainMode.devnet ? '?cluster=devnet' : '';
      final explorerUrl = 'https://solscan.io/tx/$txSig$clusterParam';
      debugPrint('[Solana] Attested tx=$txSig solscan=$explorerUrl');
      return SolanaAttestationResult(
        signatureBase58: txSig,
        explorerUrl: explorerUrl,
      );
    } catch (e, st) {
      debugPrint('[Solana] Attestation failed: $e\n$st');
      return null;
    }
  }

  // ─── RPC helpers ────────────────────────────────────────────────────────────

  static Future<String?> _getLatestBlockhash(String rpcUrl) async {
    final resp = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getLatestBlockhash',
        'params': [
          {'commitment': 'finalized'}
        ],
      }),
    );
    if (resp.statusCode != 200) {
      debugPrint('[Solana] getLatestBlockhash HTTP ${resp.statusCode}');
      return null;
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      debugPrint('[Solana] getLatestBlockhash error: ${body['error']}');
      return null;
    }
    return body['result']?['value']?['blockhash'] as String?;
  }

  /// Compact JSON for memo; shrinks until it fits Solana memo size limit.
  static Uint8List _buildMemoPayloadUtf8({
    required String orderId,
    required String certId,
    required String artworkId,
    required String buyerId,
    required String buyerDisplayName,
    required String artworkTitle,
    required double amount,
    required String currency,
    required String purchaseIso,
  }) {
    String clip(String s, int maxChars) {
      if (s.length <= maxChars) return s;
      return s.substring(0, maxChars);
    }

    final ts = DateTime.now().millisecondsSinceEpoch;

    Map<String, Object?> full() => {
          'type': 'artyug_purchase',
          'order_id': orderId,
          'cert_id': certId,
          'artwork_id': artworkId,
          'buyer_id': buyerId,
          'buyer_name': buyerDisplayName,
          'artwork_title': artworkTitle,
          'amount': amount,
          'currency': currency,
          'purchased_at': purchaseIso,
          'ts': ts,
        };

    Map<String, Object?> medium() => {
          'type': 'artyug_purchase',
          'order_id': orderId,
          'cert_id': certId,
          'artwork_id': artworkId,
          'buyer_id': buyerId,
          'buyer_name': clip(buyerDisplayName, 48),
          'artwork_title': clip(artworkTitle, 72),
          'amount': amount,
          'currency': clip(currency, 8),
          'purchased_at': purchaseIso,
          'ts': ts,
        };

    Map<String, Object?> minimal() => {
          't': 'artyug',
          'oid': orderId,
          'cid': certId,
          'aid': artworkId,
          'bid': buyerId,
          'bn': clip(buyerDisplayName, 24),
          'ts': ts,
        };

    for (final builder in <Map<String, Object?> Function()>[
      full,
      medium,
      minimal,
    ]) {
      final raw = utf8.encode(jsonEncode(builder()));
      if (raw.length <= _memoMaxBytes) return Uint8List.fromList(raw);
    }

    final fallback =
        utf8.encode(jsonEncode({'order_id': orderId, 'purchased_at': purchaseIso, 'ts': ts}));
    if (fallback.length <= _memoMaxBytes) return Uint8List.fromList(fallback);

    return Uint8List.fromList(
      utf8.encode(jsonEncode({'oid': orderId, 'ts': ts})),
    );
  }

  static Future<String?> _sendTransaction(
    String rpcUrl,
    Uint8List signedTx, {
    required bool skipPreflight,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'sendTransaction',
          'params': [
            base64Encode(signedTx),
            {
              'encoding': 'base64',
              'skipPreflight': skipPreflight,
              'maxRetries': 3,
            },
          ],
        }),
      );
      if (resp.statusCode != 200) {
        debugPrint('[Solana] HTTP ${resp.statusCode}: ${resp.body}');
        return null;
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        debugPrint(
            '[Solana] sendTransaction skipPreflight=$skipPreflight error: ${body['error']}');
        return null;
      }
      return body['result'] as String?;
    } catch (e, st) {
      debugPrint('[Solana] sendTransaction network error: $e\n$st');
      return null;
    }
  }

  // ─── Transaction builder ─────────────────────────────────────────────────────
  //
  // Solana legacy transaction wire format (compact-array encoding):
  //   [num_signatures (compact-u16)]
  //   [signature bytes * num_signatures]
  //   [message]
  //
  // Message format:
  //   [header: 3 bytes]
  //   [account_addresses (compact-u16 + 32 bytes each)]
  //   [recent_blockhash: 32 bytes]
  //   [instructions (compact-u16 count + each instruction)]
  //
  // Instruction format:
  //   [program_id_index: 1 byte]
  //   [accounts (compact-u16 + indices)]
  //   [data (compact-u16 + bytes)]

  static Uint8List _buildMemoMessage({
    required Uint8List senderPubKey,
    required Uint8List memoProgramId,
    required Uint8List memoData,
    required Uint8List recentBlockhash,
  }) {
    final buf = BytesBuilder();

    // Header: [num_required_signatures, num_readonly_signed, num_readonly_unsigned]
    buf.addByte(1); // signer count
    buf.addByte(0); // no read-only signers
    buf.addByte(1); // 1 read-only unsigned (memo program)

    // Account addresses
    buf.add(_compactU16(2));        // 2 accounts
    buf.add(senderPubKey);          // index 0 — fee payer + signer
    buf.add(memoProgramId);         // index 1 — Memo program (read-only unsigned)

    // Recent blockhash
    buf.add(recentBlockhash);

    // Instructions
    buf.add(_compactU16(1));        // 1 instruction
    buf.addByte(1);                 // program_id_index = 1 (Memo program)
    buf.add(_compactU16(0));        // 0 accounts referenced
    buf.add(_compactU16(memoData.length)); // data length
    buf.add(memoData);              // memo UTF-8 bytes

    return buf.toBytes();
  }

  static Uint8List _buildSignedTransaction({
    required Uint8List messageBytes,
    required Uint8List signature,
  }) {
    final buf = BytesBuilder();
    buf.add(_compactU16(1));   // 1 signature
    buf.add(signature);         // 64-byte Ed25519 signature
    buf.add(messageBytes);      // the message we signed
    return buf.toBytes();
  }

  /// Compact-u16 encoding as used by the Solana wire format.
  static Uint8List _compactU16(int value) {
    if (value < 0x80) return Uint8List.fromList([value]);
    if (value < 0x4000) {
      return Uint8List.fromList([
        (value & 0x7F) | 0x80,
        value >> 7,
      ]);
    }
    return Uint8List.fromList([
      (value & 0x7F) | 0x80,
      ((value >> 7) & 0x7F) | 0x80,
      value >> 14,
    ]);
  }

  // ─── Ed25519 signing ─────────────────────────────────────────────────────────

  static Future<Uint8List?> _signEd25519({
    required Uint8List messageBytes,
    required Uint8List seed,
  }) async {
    try {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPairFromSeed(seed);
      final sig = await algorithm.sign(messageBytes, keyPair: keyPair);
      return Uint8List.fromList(sig.bytes);
    } catch (e) {
      debugPrint('[Solana] Ed25519 sign failed: $e');
      return null;
    }
  }
}
