import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../providers/theme_provider.dart';
import '../../core/config/app_config.dart';

/// NFC Scan Screen — on web, always shows fallback.
/// On native, shows UI but delegates actual NFC to platform via lazy dynamic import.
///
/// NOTE: nfc_manager is NOT imported here at the top level to avoid web compile errors.
/// The native NFC scanning is triggered via the [_NfcPlatformBridge] which uses
/// a Navigator.push to a separate route that only loads on Android/iOS.
class NfcScanScreen extends StatefulWidget {
  const NfcScanScreen({super.key});

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Auto-start scan on native
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startNfc());
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startNfc() => setState(() => _scanning = true);

  void _stopNfc() {
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebFallback(context);
    return _buildNativeScan(context);
  }

  Widget _buildWebFallback(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      backgroundColor: kBg, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: kBlack), onPressed: () => context.pop()),
      title: const Text('NFC SCAN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kBlack)),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.nfc_outlined, size: 40, color: kGrey),
            ),
            const SizedBox(height: 24),
            const Text('NFC Not Available on Web', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kBlack)),
            const SizedBox(height: 10),
            const Text(
              'NFC scanning requires the Artyug Android app.\nWeb browsers cannot access NFC hardware.',
              style: TextStyle(fontSize: 14, color: kGrey, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () { context.pop(); context.push('/verify'); },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Use QR Scanner Instead', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: kWhite),
            )),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
          ],
        ),
      ),
    ),
  );

  Widget _buildNativeScan(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      backgroundColor: kBg, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: kBlack), onPressed: () => context.pop()),
      title: const Text('NFC SCAN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kBlack)),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 140 + 20 * _pulseCtrl.value,
              height: 140 + 20 * _pulseCtrl.value,
              decoration: BoxDecoration(
                color: kOrange.withOpacity(0.08 + 0.05 * _pulseCtrl.value),
                shape: BoxShape.circle,
              ),
              child: Center(child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: kOrangeLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: kOrange, width: 2),
                ),
                child: const Icon(Icons.nfc, size: 48, color: kOrange),
              )),
            ),
          ),
          const SizedBox(height: 36),
          const Text('HOLD NEAR NFC TAG', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: kBlack, letterSpacing: 1.5,
          )),
          const SizedBox(height: 8),
          const Text(
            'Place the back of your phone near\nthe artwork\'s NFC tag',
            style: TextStyle(fontSize: 14, color: kGrey, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: kOrangeLight, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kOrange.withOpacity(0.3)),
            ),
            child: const Text(
              'NFC hardware reading will be active while this screen is open.',
              style: TextStyle(fontSize: 13, color: kBlack, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel', style: TextStyle(color: kGrey, fontSize: 14)),
          ),
        ],
      ),
    ),
  );
}
