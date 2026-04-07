import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/certificate.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/order_repository.dart';

/// Shown after a successful purchase.
/// Receives an OrderResult passed as route arguments.
class OrderConfirmScreen extends StatelessWidget {
  final OrderResult result;

  const OrderConfirmScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final cert = result.certificate;
    final isDemoPurchase = result.purchaseMode == 'demo';
    final order = result.order;
    final buyerEmail = context.watch<AuthProvider>().user?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _SuccessHeader(
                isDemo: isDemoPurchase,
                artworkTitle: order.artworkTitle ?? cert?.artworkTitle ?? 'Artwork',
              ),
              if (isDemoPurchase) ...[
                const SizedBox(height: 16),
                _DemoModeBanner(cert: cert),
              ],
              const SizedBox(height: 20),
              _OrderReceiptCard(
                order: order,
                cert: cert,
                buyerEmail: buyerEmail,
                isDemo: isDemoPurchase,
              ),
              if (cert != null) ...[
                const SizedBox(height: 28),
                _AuthenticityCertificate(
                  cert: cert,
                  solanaExplorerUrl: result.solanaExplorerUrl,
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/collector-dashboard'),
                  child: const Text('Go to My Collection'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/main'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Continue Browsing'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessHeader extends StatelessWidget {
  final bool isDemo;
  final String artworkTitle;

  const _SuccessHeader({required this.isDemo, required this.artworkTitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.success, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          isDemo ? 'Demo purchase complete' : 'Thank you for your order',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          artworkTitle,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DemoModeBanner extends StatelessWidget {
  final CertificateModel? cert;

  const _DemoModeBanner({this.cert});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Demo mode',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'No real payment was processed. This screen is a preview of what '
            'collectors see after checkout — certificate, QR, and receipt match production.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          ...() {
            final c = cert;
            if (c != null && !c.isBlockchainAnchored) {
              return [
            const SizedBox(height: 8),
            Text(
              'The on-chain hash below may be a placeholder until Solana is configured.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.textTertiary,
              ),
            ),
              ];
            }
            return <Widget>[];
          }(),
        ],
      ),
    );
  }
}

/// Amazon-style order summary: payment status, thumbnail, owner, totals.
class _OrderReceiptCard extends StatelessWidget {
  final OrderModel order;
  final CertificateModel? cert;
  final String? buyerEmail;
  final bool isDemo;

  const _OrderReceiptCard({
    required this.order,
    required this.cert,
    required this.buyerEmail,
    required this.isDemo,
  });

  String get _imageUrl => order.artworkMediaUrl ?? cert?.artworkMediaUrl ?? '';

  String get _shortOrderId {
    final id = order.id;
    if (id.length <= 10) return id.toUpperCase();
    return '${id.substring(0, 8)}…'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final amount = order.displayAmount;
    final ownerName = order.buyerName ?? cert?.ownerName ?? 'Owner';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F8EF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF067D3F),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment completed',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDemo
                            ? 'Demo transaction — no charge placed.'
                            : 'Your payment was successful. Your certificate is ready below.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (buyerEmail != null && buyerEmail!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Confirmation sent to $buyerEmail',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _imageUrl,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 88,
                            height: 88,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 88,
                            height: 88,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Container(
                          width: 88,
                          height: 88,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.palette_outlined, color: Color(0xFF94A3B8), size: 36),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.artworkTitle ?? cert?.artworkTitle ?? 'Artwork',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Qty: 1',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        amount,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OWNER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ownerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (buyerEmail != null && buyerEmail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    buyerEmail!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    Text(
                      _shortOrderId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Formal certificate frame with QR and Solana verification copy.
class _AuthenticityCertificate extends StatelessWidget {
  final CertificateModel cert;
  final String? solanaExplorerUrl;

  const _AuthenticityCertificate({
    required this.cert,
    required this.solanaExplorerUrl,
  });

  static const _gold = Color(0xFFD4A574);
  static const _goldDim = Color(0xFF8B7355);
  static const _innerBg = Color(0xFF0D1524);

  Future<void> _openExplorerInBrowser(BuildContext context, String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid explorer link')),
        );
      }
      return;
    }
    try {
      var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!context.mounted) return;
      if (!ok) {
        await Clipboard.setData(ClipboardData(text: urlString));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open browser — link copied to clipboard'),
          ),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: urlString));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open browser — link copied to clipboard'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final explorerUrl = solanaExplorerUrl ?? cert.solanaExplorerUrl;
    final txSig = cert.transactionSignature;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _gold,
            _goldDim,
            _gold.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.15),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: _innerBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _goldDim.withValues(alpha: 0.5), width: 1),
        ),
        child: Column(
          children: [
            Text(
              'ARTYUG',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: _gold.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Certificate of Authenticity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
                height: 1.2,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This document certifies the provenance of the listed artwork.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cert.isBlockchainAnchored ? Icons.link_rounded : Icons.shield_outlined,
                  size: 15,
                  color: cert.isBlockchainAnchored ? AppColors.primary : _goldDim,
                ),
                const SizedBox(width: 6),
                Text(
                  cert.blockchainLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cert.isBlockchainAnchored ? AppColors.primary : _gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: _gold.withValues(alpha: 0.35), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.diamond_outlined, size: 14, color: _gold.withValues(alpha: 0.6)),
                ),
                Expanded(child: Divider(color: _gold.withValues(alpha: 0.35), thickness: 1)),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: cert.qrCode,
                version: QrVersions.auto,
                size: 168,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Verify your artwork on the Solana blockchain',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scan the code above to open your certificate record.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                cert.qrCode,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _certDetailRow('Artist', cert.artistName),
            _certDetailRow('Owner', cert.ownerName),
            _certDetailRow('Purchase date', cert.purchaseDate.substring(0, 10)),
            if (cert.currentMarketPrice != null)
              _certDetailRow(
                'Est. market value',
                '₹${cert.currentMarketPrice!.toStringAsFixed(0)}',
              ),
            if (txSig != null) ...[
              const SizedBox(height: 4),
              _transactionIdRow(context, txSig),
            ] else if (cert.blockchainHash != null)
              _certDetailRow('Record', cert.displayTruncatedHash),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold, width: 2),
                    color: _innerBg,
                  ),
                  child: Icon(Icons.verified_rounded, color: _gold, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'This certificate is issued by Artyug and may be anchored to Solana for '
                      'independent verification.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (explorerUrl != null &&
                (explorerUrl.startsWith('https://') || explorerUrl.startsWith('http://'))) ...[
              const SizedBox(height: 16),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openExplorerInBrowser(context, explorerUrl),
                  icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                  label: const Text(
                    'View on Solscan',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _certDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Full Solana signature with copy (for pasting into Solscan manually).
  Widget _transactionIdRow(BuildContext context, String signature) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Transaction ID',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: signature));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction ID copied')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            signature,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
