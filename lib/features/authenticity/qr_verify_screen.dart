import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/certificate.dart';
import '../../repositories/certificate_repository.dart';
import '../../providers/theme_provider.dart';


class QrVerifyScreen extends StatefulWidget {
  const QrVerifyScreen({super.key});

  @override
  State<QrVerifyScreen> createState() => _QrVerifyScreenState();
}

class _QrVerifyScreenState extends State<QrVerifyScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualCtrl = TextEditingController();
  bool _processing = false;
  bool _useManual = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    setState(() => _processing = true);
    await _controller.stop();
    if (mounted) {
      setState(() => _processing = false);
      context.pushReplacement('/qr-result', extra: raw);
    }
  }

  Future<void> _verifyManual() async {
    String code = _manualCtrl.text.trim();
    if (code.isEmpty) return;

    // Strip artyug:// deep-link prefix so bare UUID also matches
    const scheme = 'artyug://certificate/';
    if (code.startsWith(scheme)) code = code.substring(scheme.length);

    setState(() => _processing = true);
    CertificateModel? cert;
    try {
      cert = await CertificateRepository.verifyByQrCode(code);
    } catch (_) {
      cert = null;
    }
    if (mounted) {
      setState(() => _processing = false);
      context.pushReplacement('/qr-result', extra: <String, dynamic>{
        'qrCode': _manualCtrl.text.trim(),
        'certificate': cert,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useManual || kIsWeb) {
      return _buildManualEntry(context);
    }
    return _buildScanner(context);
  }

  Widget _buildScanner(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: const Text('SCAN QR CERTIFICATE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          icon: const Icon(Icons.flashlight_on_outlined),
          onPressed: () => _controller.toggleTorch(),
          tooltip: 'Toggle flash',
        ),
        IconButton(
          icon: const Icon(Icons.flip_camera_android_outlined),
          onPressed: () => _controller.switchCamera(),
          tooltip: 'Switch camera',
        ),
        TextButton(
          onPressed: () => setState(() => _useManual = true),
          child: const Text('Manual', style: TextStyle(color: Colors.white70)),
        ),
      ],
    ),
    body: Stack(children: [
      MobileScanner(controller: _controller, onDetect: _onDetect),
      // Scan frame overlay
      Center(child: Container(
        width: 240, height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: kOrange, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      )),
      // Bottom instruction
      Positioned(
        bottom: 60, left: 0, right: 0,
        child: Center(child: Column(children: [
          if (_processing) ...[
            const CircularProgressIndicator(color: kOrange),
            const SizedBox(height: 12),
            const Text('Verifying...', style: TextStyle(color: Colors.white)),
          ] else ...[
            const Icon(Icons.qr_code_scanner, color: Colors.white54, size: 28),
            const SizedBox(height: 8),
            const Text(
              'Point camera at an Artyug QR certificate',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ])),
      ),
    ]),
  );

  Widget _buildManualEntry(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      backgroundColor: kBg, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: kBlack), onPressed: () => context.pop()),
      title: const Text('VERIFY CERTIFICATE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kBlack)),
      actions: [
        if (!kIsWeb) TextButton(
          onPressed: () => setState(() => _useManual = false),
          child: const Text('Use Camera', style: TextStyle(color: kOrange, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (kIsWeb) Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: kOrangeLight, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kOrange.withOpacity(0.3)),
          ),
          child: Row(children: const [
            Icon(Icons.info_outline, size: 18, color: kOrange),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Camera QR scanning requires the Android app. Enter a certificate ID below.',
              style: TextStyle(fontSize: 13, color: kBlack, height: 1.4),
            )),
          ]),
        ),
        Center(child: Container(
          width: 90, height: 90,
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(22)),
          child: const Icon(Icons.qr_code_2, size: 50, color: kGrey),
        )),
        const SizedBox(height: 24),
        const Text('CERTIFICATE ID OR URL', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, color: kGrey, letterSpacing: 1.2,
        )),
        const SizedBox(height: 10),
        TextField(
          controller: _manualCtrl,
          style: const TextStyle(color: kBlack, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'artyug://certificate/xxxxx or cert ID',
            prefixIcon: Icon(Icons.link_outlined, size: 20),
          ),
          onSubmitted: (_) => _verifyManual(),
        ),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _processing ? null : _verifyManual,
          style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: kWhite),
          child: _processing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: kWhite))
              : const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        )),
      ]),
    ),
  );
}
