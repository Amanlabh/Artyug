import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';

/// Dark ink on white certificate cards (scaffold/chrome use [AppColors.textPrimary] on dark).
const Color _onLight = AppColors.textOnLight;
const Color _onLightMuted = AppColors.textOnLightSecondary;
const Color _onLightHint = Color(0xFF6B7280);

// ─── Model ────────────────────────────────────────────────────────────────
class CertificateModel {
  final String id;
  final String artworkId;
  final String artworkTitle;
  final String? artworkImageUrl;
  final String creatorName;
  final String ownerName;
  final String issuedAt;
  final String? txHash;
  final String? nfcTagId;
  final String? qrCode;
  final bool isVerified;

  const CertificateModel({
    required this.id,
    required this.artworkId,
    required this.artworkTitle,
    this.artworkImageUrl,
    required this.creatorName,
    required this.ownerName,
    required this.issuedAt,
    this.txHash,
    this.nfcTagId,
    this.qrCode,
    this.isVerified = false,
  });

  factory CertificateModel.fromMap(Map<String, dynamic> m) => CertificateModel(
    id: m['id'] ?? '',
    artworkId: m['artwork_id'] ?? m['painting_id'] ?? '',
    artworkTitle: m['artwork_title'] ?? m['title'] ?? 'Untitled',
    artworkImageUrl: m['artwork_media_url'],
    creatorName: m['artist_name'] ?? 'Unknown Artist',
    ownerName: m['owner_name'] ?? 'Unknown Collector',
    issuedAt: m['issued_at'] ?? m['purchase_date'] ?? m['created_at'] ?? '',
    txHash: (m['blockchain_hash'] ?? m['tx_hash']) as String?,
    nfcTagId: m['nfc_tag_id'],
    qrCode: m['qr_code'] ?? 'artyug://certificate/${m['id']}',
    isVerified: m['is_verified'] == true,
  );

  // Demo certificates
  static List<CertificateModel> get demoCerts => [
    const CertificateModel(
      id: 'cert-demo-001',
      artworkId: 'art-demo-001',
      artworkTitle: 'Monsoon Memories #1',
      creatorName: 'Aman Labh',
      ownerName: 'Collector A',
      issuedAt: '2025-03-12T10:00:00Z',
      txHash: '5FHneW46xGXgs5mKyvo1TS6GzMRAdEqy9BxkU3G8dJGP4jKM',
      qrCode: 'artyug://certificate/cert-demo-001',
      isVerified: true,
    ),
    const CertificateModel(
      id: 'cert-demo-002',
      artworkId: 'art-demo-002',
      artworkTitle: 'One Indian Girl',
      creatorName: 'Aman Labh',
      ownerName: 'Collector B',
      issuedAt: '2025-02-20T14:30:00Z',
      txHash: '3qBKGNnZ9j4Xz5VrFrfMF3ij5v4j1TXMFJHopNmYBwK',
      qrCode: 'artyug://certificate/cert-demo-002',
      isVerified: false,
    ),
  ];
}

// ─── Certificate List Screen ────────────────────────────────────────────────
class CertificateListScreen extends StatefulWidget {
  const CertificateListScreen({super.key});

  @override
  State<CertificateListScreen> createState() => _CertificateListScreenState();
}

class _CertificateListScreenState extends State<CertificateListScreen> {
  List<CertificateModel> _certs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCerts();
  }

  Future<void> _loadCerts() async {
    if (AppConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() { _certs = CertificateModel.demoCerts; _loading = false; });
      return;
    }
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      // Query using the denormalized columns (artwork_title, artwork_media_url)
      // that already exist in the certificates table — avoids FK join errors.
      final data = await Supabase.instance.client
          .from('certificates')
          .select('*')
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() {
        _certs = (data as List).map((m) => CertificateModel.fromMap(m)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: const Text('MY CERTIFICATES', style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 0.5,
      )),
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => context.pop()),
      actions: [
        TextButton.icon(
          onPressed: () => context.push('/verify'),
          icon: const Icon(Icons.qr_code_scanner, size: 18, color: AppColors.primary),
          label: const Text('Verify', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null
            ? _ErrorView(message: _error!, onRetry: _loadCerts)
            : _certs.isEmpty
                ? _EmptyView()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadCerts,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 600 ? 3 : 2;
                        return GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1,
                          ),
                          itemCount: _certs.length,
                          itemBuilder: (_, i) => _CertificateSquareTile(
                            cert: _certs[i],
                            onTap: () => context.push('/certificate/${_certs[i].id}', extra: _certs[i]),
                          ),
                        );
                      },
                    ),
                  ),
  );
}

String _shortTxPreview(String tx) {
  if (tx.length <= 12) return tx;
  return '${tx.substring(0, 12)}…';
}

class _CertificateSquareTile extends StatelessWidget {
  final CertificateModel cert;
  final VoidCallback onTap;
  const _CertificateSquareTile({required this.cert, required this.onTap});

  static const _qrEye = QrEyeStyle(color: _onLight, eyeShape: QrEyeShape.square);
  static const _qrData = QrDataModuleStyle(color: _onLight, dataModuleShape: QrDataModuleShape.square);

  @override
  Widget build(BuildContext context) {
    final qrData = cert.qrCode ?? 'artyug://certificate/${cert.id}';
    final imageUrl = cert.artworkImageUrl?.trim() ?? '';
    final hasArt = imageUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.primary.withOpacity(0.12),
        highlightColor: AppColors.primary.withOpacity(0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFF8F9FB),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.65), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 12,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasArt)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: const Color(0xFF1a1d24),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _CertificateSquareHeroQr(qrData: qrData),
                        )
                      else
                        _CertificateSquareHeroQr(qrData: qrData),
                      if (hasArt)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.05),
                                  Colors.black.withOpacity(0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (hasArt)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: qrData,
                                size: 48,
                                padding: EdgeInsets.zero,
                                eyeStyle: _qrEye,
                                dataModuleStyle: _qrData,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                cert.artworkTitle,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: _onLight,
                                  height: 1.2,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (cert.isVerified) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Text(
                                  '✓',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'by ${cert.creatorName}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _onLightMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        if (cert.txHash != null)
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary,
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'On-chain: ${_shortTxPreview(cert.txHash!)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: _onLightHint,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Tap for details',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary.withOpacity(0.85),
                              letterSpacing: 0.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Large QR when there is no artwork thumbnail.
class _CertificateSquareHeroQr extends StatelessWidget {
  final String qrData;
  const _CertificateSquareHeroQr({required this.qrData});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF2a2f3a),
          const Color(0xFF151820),
        ],
      ),
    ),
    child: Center(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: QrImageView(
          data: qrData,
          size: 92,
          padding: EdgeInsets.zero,
          eyeStyle: const QrEyeStyle(color: _onLight, eyeShape: QrEyeShape.square),
          dataModuleStyle: const QrDataModuleStyle(color: _onLight, dataModuleShape: QrDataModuleShape.square),
        ),
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.verified_outlined, size: 36, color: AppColors.primary),
      ),
      const SizedBox(height: 20),
      const Text('No Certificates Yet', style: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
      )),
      const SizedBox(height: 8),
      const Text('Purchase artwork to receive authenticity certificates.', style: TextStyle(
        fontSize: 14, color: AppColors.textSecondary, height: 1.5,
      ), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () => context.go('/main'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        child: const Text('Browse Artworks', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  ));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
      const SizedBox(height: 16),
      Text('Failed to load certificates', style: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      )),
      const SizedBox(height: 8),
      Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  ));
}

// ─── Certificate Loading Screen — used when navigation has no `extra` ──────────
class CertificateLoadingScreen extends StatefulWidget {
  final String certId;
  const CertificateLoadingScreen({super.key, required this.certId});
  @override
  State<CertificateLoadingScreen> createState() => _CertificateLoadingScreenState();
}

class _CertificateLoadingScreenState extends State<CertificateLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1. Try demo certs first
    final demo = CertificateModel.demoCerts
        .where((c) => c.id == widget.certId)
        .firstOrNull;
    if (demo != null) {
      if (!mounted) return;
      context.replace('/certificate/${widget.certId}', extra: demo);
      return;
    }
    // 2. Try Supabase
    try {
      final data = await Supabase.instance.client
          .from('certificates')
          .select('*')
          .eq('id', widget.certId)
          .single();
      final cert = CertificateModel.fromMap(data);
      if (!mounted) return;
      context.replace('/certificate/${widget.certId}', extra: cert);
    } catch (_) {
      // Fall back to list
      if (mounted) context.go('/certificates');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );
}

// ─── Certificate Detail Screen ───────────────────────────────────────────────
class CertificateDetailScreen extends StatelessWidget {
  final CertificateModel cert;
  const CertificateDetailScreen({super.key, required this.cert});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: const Text('CERTIFICATE', style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary,
      )),
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => context.pop()),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: AppColors.textPrimary),
          onPressed: () => _share(context),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // ── Certificate card ──────────────────────────────────────
        _CertificateCard2(cert: cert),
        const SizedBox(height: 20),
        // ── QR Section ───────────────────────────────────────────
        _QRSection(cert: cert),
        const SizedBox(height: 20),
        // ── Blockchain receipt ───────────────────────────────────
        _BlockchainSection(cert: cert),
        const SizedBox(height: 20),
        // ── Ownership history ────────────────────────────────────
        _OwnershipSection(cert: cert),
        const SizedBox(height: 32),
      ]),
    ),
  );

  void _share(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Share link copied to clipboard'),
      backgroundColor: AppColors.primary,
    ));
    Clipboard.setData(ClipboardData(
      text: 'Check out this authenticated artwork certificate: artyug.art/certificate/${cert.id}',
    ));
  }
}

class _CertificateCard2 extends StatelessWidget {
  final CertificateModel cert;
  const _CertificateCard2({required this.cert});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          RichText(text: const TextSpan(children: [
            TextSpan(text: 'ARTYUG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
            TextSpan(text: '.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cert.isVerified ? const Color(0xFF16A34A) : AppColors.textSecondary,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(cert.isVerified ? Icons.verified : Icons.pending, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(cert.isVerified ? 'VERIFIED' : 'PENDING',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        const Text('CERTIFICATE OF AUTHENTICITY', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5,
        )),
        const SizedBox(height: 6),
        Text(cert.artworkTitle, style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2,
        )),
        const SizedBox(height: 20),
        _CertRow('Created by', cert.creatorName),
        const SizedBox(height: 8),
        _CertRow('Owned by', cert.ownerName),
        const SizedBox(height: 8),
        _CertRow('Issued', cert.issuedAt.split('T').first),
        const SizedBox(height: 8),
        _CertRow('Certificate ID', '${cert.id.substring(0, 16)}...'),
      ],
    ),
  );
}

class _CertRow extends StatelessWidget {
  final String label;
  final String value;
  const _CertRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
    ],
  );
}

class _QRSection extends StatelessWidget {
  final CertificateModel cert;
  const _QRSection({required this.cert});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      const Text('SCAN TO VERIFY', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: _onLight, letterSpacing: 1,
      )),
      const SizedBox(height: 20),
      QrImageView(
        data: cert.qrCode ?? 'artyug://certificate/${cert.id}',
        size: 180,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(color: _onLight, eyeShape: QrEyeShape.square),
        dataModuleStyle: const QrDataModuleStyle(color: _onLight, dataModuleShape: QrDataModuleShape.square),
      ),
      const SizedBox(height: 16),
      Text(
        cert.qrCode ?? 'artyug://certificate/${cert.id}',
        style: const TextStyle(fontSize: 11, color: _onLightMuted, fontFamily: 'monospace'),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: cert.qrCode ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy Link'),
          style: OutlinedButton.styleFrom(foregroundColor: _onLight, side: BorderSide(color: AppColors.borderOf(context))),
        ),
      ]),
    ]),
  );
}

class _BlockchainSection extends StatelessWidget {
  final CertificateModel cert;
  const _BlockchainSection({required this.cert});

  @override
  Widget build(BuildContext context) {
    final chainMode = AppConfig.isDemoMode ? 'DEVNET' : AppConfig.chainMode.name.toUpperCase();
    final solanaEnabled = AppConfig.solanaEnabled;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('BLOCKCHAIN RECEIPT', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: _onLight, letterSpacing: 1,
            )),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(chainMode, style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5,
              )),
            ),
          ]),
          const SizedBox(height: 16),
          if (!solanaEnabled) ...[
            _BlockedChip('Blockchain anchoring is disabled'),
          ] else if (cert.txHash != null) ...[
            _BlockchainRow('Network', 'Solana ${chainMode.toLowerCase()}'),
            const SizedBox(height: 10),
            _BlockchainRow('Status', 'Confirmed'),
            const SizedBox(height: 10),
            Row(children: [
              const Text('TX Hash', style: TextStyle(fontSize: 12, color: _onLightMuted)),
              const Spacer(),
              Flexible(child: Text(cert.txHash!, style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'monospace',
              ), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: cert.txHash!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TX hash copied')));
                },
                child: const Icon(Icons.copy, size: 14, color: _onLightHint),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () {
                final base = AppConfig.isDemoMode
                    ? 'https://explorer.solana.com/tx'
                    : 'https://explorer.solana.com/tx';
                final url = '$base/${cert.txHash}?cluster=${chainMode.toLowerCase()}';
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Explorer URL copied')));
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View on Solana Explorer'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
            )),
          ] else ...[
            _BlockedChip('Not yet anchored to blockchain (purchase in live mode to activate)'),
          ],
        ],
      ),
    );
  }
}

class _BlockchainRow extends StatelessWidget {
  final String label;
  final String value;
  const _BlockchainRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: _onLightMuted)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _onLight)),
    ],
  );
}

class _BlockedChip extends StatelessWidget {
  final String message;
  const _BlockedChip(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4))),
    ]),
  );
}

class _OwnershipSection extends StatelessWidget {
  final CertificateModel cert;
  const _OwnershipSection({required this.cert});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OWNERSHIP HISTORY', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800, color: _onLight, letterSpacing: 1,
        )),
        const SizedBox(height: 16),
        _OwnershipEvent(
          event: 'Certificate Issued',
          actor: cert.creatorName,
          date: cert.issuedAt.split('T').first,
          icon: Icons.verified_outlined,
          isFirst: true,
        ),
        _OwnershipEvent(
          event: 'Ownership Transferred',
          actor: cert.ownerName,
          date: cert.issuedAt.split('T').first,
          icon: Icons.person_outline,
          isFirst: false,
        ),
      ],
    ),
  );
}

class _OwnershipEvent extends StatelessWidget {
  final String event;
  final String actor;
  final String date;
  final IconData icon;
  final bool isFirst;
  const _OwnershipEvent({
    required this.event, required this.actor, required this.date,
    required this.icon, required this.isFirst,
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: isFirst ? AppColors.primaryLight : AppColors.background, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: isFirst ? AppColors.primary : AppColors.textSecondary),
        ),
        if (!isFirst) Container(width: 2, height: 0, color: AppColors.border),
      ]),
      const SizedBox(width: 14),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onLight)),
            Text(actor, style: const TextStyle(fontSize: 12, color: _onLightMuted)),
            Text(date, style: const TextStyle(fontSize: 11, color: _onLightHint)),
          ],
        ),
      )),
    ],
  );
}
