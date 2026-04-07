import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/certificate.dart';

class QrResultScreen extends StatelessWidget {
  final String qrCode;
  final CertificateModel? certificate;

  const QrResultScreen({
    super.key,
    required this.qrCode,
    this.certificate,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = certificate != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Verification Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Result icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: isVerified
                    ? AppColors.success.withOpacity(0.12)
                    : AppColors.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVerified
                    ? Icons.verified_outlined
                    : Icons.gpp_bad_outlined,
                color: isVerified ? AppColors.success : AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              isVerified ? 'Artwork Authenticated' : 'Certificate Not Recognised',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isVerified ? AppColors.success : AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isVerified
                  ? 'This artwork has a valid Artyug certificate.'
                  : 'No certificate found for QR code: $qrCode',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            if (isVerified && certificate != null) ...[
              // Certificate card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (certificate!.artworkMediaUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          certificate!.artworkMediaUrl!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      certificate!.artworkTitle,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    _Row('Artist', certificate!.artistName),
                    _Row('Owner', certificate!.ownerName),
                    _Row('Purchase Date', certificate!.purchaseDate.substring(0, 10)),
                    _Row('Certificate Type', certificate!.blockchainLabel),
                    if (certificate!.blockchainHash != null) ...[
                      const SizedBox(height: 8),
                      const Text('Blockchain Hash',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: certificate!.blockchainHash!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hash copied')),
                          );
                        },
                        child: Text(
                          certificate!.displayTruncatedHash,
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Another'),
                onPressed: () => context.pushReplacement('/verify'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/main'),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
