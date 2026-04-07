import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../models/certificate.dart';
import '../../repositories/certificate_repository.dart';


class AuthenticityCenter extends StatefulWidget {
  const AuthenticityCenter({super.key});

  @override
  State<AuthenticityCenter> createState() => _AuthenticityState();
}

class _AuthenticityState extends State<AuthenticityCenter>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chromeFg = AppColors.textPrimaryOf(context);
    final muted = AppColors.textSecondaryOf(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: chromeFg),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Authenticity Center',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: chromeFg,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Verify certificates & manage your vault',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: muted,
                height: 1.2,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(height: 1, thickness: 1, color: AppColors.borderOf(context)),
              TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: muted,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Verify'),
                  Tab(text: 'My vault'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_VerifyTab(), _VaultTab()],
      ),
    );
  }
}

// ─── Verify Tab (public-facing) ──────────────────────────────────────────────
class _VerifyTab extends StatefulWidget {
  const _VerifyTab();
  @override
  State<_VerifyTab> createState() => _VerifyTabState();
}

class _VerifyTabState extends State<_VerifyTab> {
  final _manualCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() { _manualCtrl.dispose(); super.dispose(); }

  Future<void> _verifyManual() async {
    String code = _manualCtrl.text.trim();
    if (code.isEmpty) return;

    // Strip artyug:// deep-link prefix so bare UUID also matches
    const scheme = 'artyug://certificate/';
    if (code.startsWith(scheme)) code = code.substring(scheme.length);

    setState(() => _searching = true);
    CertificateModel? cert;
    try {
      cert = await CertificateRepository.verifyByQrCode(code);
    } catch (_) {
      cert = null;
    }
    if (mounted) {
      setState(() => _searching = false);
      context.push('/qr-result', extra: <String, dynamic>{
        'qrCode': _manualCtrl.text.trim(),
        'certificate': cert,
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final sectionMuted = AppColors.textSecondaryOf(context);
    final border = AppColors.borderOf(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VerifyPageIntro(),
          const SizedBox(height: 20),
          _SolanaBanner(),
          const SizedBox(height: 24),

          _SectionHeader(
            title: 'Quick scan',
            subtitle: 'Fastest way to confirm a piece is registered on Artyug.',
            titleColor: sectionMuted,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScanOption(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scan QR code',
                  subtitle: 'Point your camera at the QR printed on the certificate or packaging.',
                  badge: 'Most common',
                  onTap: () => context.push('/verify'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScanOption(
                  icon: Icons.nfc_rounded,
                  title: 'Scan NFC tag',
                  subtitle: 'Hold your phone near the NFC chip embedded with the artwork.',
                  badge: 'Physical works',
                  onTap: _handleNfcTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          _SectionHeader(
            title: 'Manual verification',
            subtitle: 'Use this if you only have a certificate ID, URL, or pasted code.',
            titleColor: sectionMuted,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualCtrl,
            style: TextStyle(color: AppColors.textOnLight, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. certificate ID, verify link, or QR payload…',
              hintStyle: TextStyle(color: AppColors.textOnLightSecondary.withValues(alpha: 0.85)),
              prefixIcon: Icon(Icons.tag_rounded, size: 22, color: AppColors.textOnLightSecondary),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.surfaceMutedOf(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _verifyManual(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _searching ? null : _verifyManual,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _searching
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                    )
                  : const Text('Verify ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 28),

          const _HowItWorksCard(),
        ],
      ),
    );
  }

  void _handleNfcTap() {
    AppConfig.nfcEnabled
        ? context.push('/nfc-scan')
        : showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => const _NfcBlockedSheet(),
          );
  }
}

// ─── Vault Tab (user's certificates) ─────────────────────────────────────────
class _VaultTab extends StatelessWidget {
  const _VaultTab();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      Text(
        'Your vault',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimaryOf(context),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Certificates you own and on-chain status — same records others verify from the Verify tab.',
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.textSecondaryOf(context),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _StatCard('2', 'Certificates', Icons.verified_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard('1', 'On-chain', Icons.link_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard('0', 'Pending', Icons.pending_outlined)),
      ]),
      const SizedBox(height: 24),

      // CTA to certificates
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFFF6B35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('My Certificates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.onPrimary)),
              SizedBox(height: 4),
              Text('View and share your ownership proofs', style: TextStyle(fontSize: 13, color: AppColors.onPrimary)),
            ],
          )),
          ElevatedButton(
            onPressed: () => context.push('/certificates'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.onPrimary, foregroundColor: AppColors.primary),
            child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const SizedBox(height: 24),

      // Blockchain status
      _BlockchainStatusCard(),
      const SizedBox(height: 20),

      // Creator verification (if creator)
      _CreatorStatsCard(),
    ],
    ),
  );
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

/// Short intro so users know what this hub does (clear hierarchy, e‑commerce style).
class _VerifyPageIntro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fg = AppColors.textPrimaryOf(context);
    final sub = AppColors.textSecondaryOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadows(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Check that an artwork matches its Artyug certificate',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Each sale can include a digital certificate linked to the blockchain. '
            'Scanning or entering an ID shows whether that certificate is valid and what it proves.',
            style: TextStyle(fontSize: 13, color: sub, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color titleColor;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryOf(context),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SolanaBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final enabled = AppConfig.solanaEnabled;
    final isDemo = AppConfig.isDemoMode;
    final chain = isDemo ? 'Devnet (Demo)' : AppConfig.chainMode.name;
    final blockReason = AppConfig.solanaBlockReason;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.primaryLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(children: [
        Icon(
          enabled ? Icons.link : Icons.link_off,
          size: 18,
          color: enabled ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(child: enabled
            ? RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, height: 1.35),
                  children: [
                    TextSpan(
                      text: 'Blockchain: ',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textOnLight),
                    ),
                    TextSpan(
                      text: 'Solana $chain',
                      style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textOnLightSecondary),
                    ),
                  ],
                ),
              )
            : Text(
                blockReason ?? 'Blockchain disabled',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryOf(context)),
              )),
        if (enabled && isDemo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(100)),
            child: const Text(
              'DEMO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.onPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ]),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? Colors.white : AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: isDark ? AppColors.cardShadows(context) : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 24, color: AppColors.primary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnLightSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textOnLight,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textOnLightSecondary,
                    height: 1.4,
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

class _StatCard extends StatelessWidget {
  final String count;
  final String label;
  final IconData icon;
  const _StatCard(this.count, this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: isDark ? AppColors.cardShadows(context) : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            count,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textOnLight,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnLightSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockchainStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: isDark ? AppColors.cardShadows(context) : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text(
              'Blockchain status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textOnLight,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(100)),
              child: const Text(
                'DEVNET',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'What is enabled for certificates in this environment.',
            style: TextStyle(fontSize: 12, color: AppColors.textOnLightSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          _StatusRow(Icons.check_circle_outline, 'Certificate anchoring', AppConfig.solanaEnabled ? 'Active' : 'Disabled', AppConfig.solanaEnabled),
          const SizedBox(height: 10),
          _StatusRow(Icons.nfc, 'NFC writing', AppConfig.nfcEnabled ? 'Active' : 'Disabled', AppConfig.nfcEnabled),
          const SizedBox(height: 10),
          _StatusRow(Icons.qr_code_2, 'QR verification', 'Active', true),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool active;
  const _StatusRow(this.icon, this.label, this.status, this.active);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: active ? AppColors.primary : AppColors.textOnLightSecondary),
    const SizedBox(width: 10),
    Expanded(
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textOnLight),
      ),
    ),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF16A34A).withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? const Color(0xFF16A34A) : AppColors.textOnLightSecondary,
        ),
      ),
    ),
  ]);
}

class _CreatorStatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: isDark ? AppColors.cardShadows(context) : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'For creators',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textOnLight,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Issue certificates for sold artworks so collectors can verify provenance and ownership.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textOnLightSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/creator-dashboard'),
              icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
              label: const Text('Open creator dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.textOnLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: isDark ? AppColors.cardShadows(context) : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How authentication works',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textOnLight,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'End-to-end flow from listing to verification.',
            style: TextStyle(fontSize: 12, color: AppColors.textOnLightSecondary, height: 1.35),
          ),
          const SizedBox(height: 18),
          _StepRow('1', 'Artist lists the work and uploads proof assets on Artyug.'),
          _StepRow('2', 'When a collector buys, a certificate record is created for that sale.'),
          _StepRow('3', 'The certificate can be anchored on Solana for a public audit trail.'),
          _StepRow('4', 'A QR code and/or NFC tag ties the physical piece to that certificate.'),
          _StepRow('5', 'Anyone scans or enters the ID to confirm the work matches the record.'),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String num;
  final String text;
  const _StepRow(this.num, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  num,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textOnLight,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _NfcBlockedSheet extends StatelessWidget {
  const _NfcBlockedSheet();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceMutedOf(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.nfc_outlined, size: 28, color: AppColors.textSecondaryOf(context)),
        ),
        const SizedBox(height: 20),
        const Text(
          'NFC not available',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textOnLight,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'NFC scanning needs the Artyug Android app with NFC hardware.\nMost web browsers cannot access NFC.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textOnLightSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () { Navigator.pop(context); context.push('/verify'); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
          child: const Text('Use QR Scanner Instead', style: TextStyle(fontWeight: FontWeight.w700)),
        )),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textOnLightSecondary)),
        ),
      ],
    ),
  );
}
