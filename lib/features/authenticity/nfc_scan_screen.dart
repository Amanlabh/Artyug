import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import '../../services/nfc_link_service.dart';

/// NFC Scan Screen — on web, always shows fallback.
/// On native, shows UI but delegates actual NFC to platform via lazy dynamic import.
///
/// NOTE: nfc_manager is NOT imported here at the top level to avoid web compile errors.
/// The native NFC scanning is triggered via the [_NfcPlatformBridge] which uses
/// a Navigator.push to a separate route that only loads on Android/iOS.
class NfcScanScreen extends StatefulWidget {
  final bool returnPayloadOnly;
  final String? preferredPayload;

  const NfcScanScreen({
    super.key,
    this.returnPayloadOnly = false,
    this.preferredPayload,
  });

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _scanning = false;
  bool _sessionActive = false;
  String _status = 'Ready to scan';

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
    _stopNfc();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startNfc() async {
    if (_scanning) return;
    if (mounted) {
      setState(() {
        _scanning = true;
        _status = 'Waiting for NFC tag...';
      });
    }

    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (availability != NfcAvailability.enabled) {
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _status = 'NFC is not available on this device.';
        });
        return;
      }

      _sessionActive = true;
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (tag) async {
          final payload = _extractPayload(tag);
          await _safeStopSession();
          if (!mounted) return;
          setState(() => _scanning = false);
          await _handleScannedPayload(payload);
        },
        onSessionErrorIos: (error) async {
          await _safeStopSession(errorMessageIos: error.message);
          if (!mounted) return;
          setState(() {
            _scanning = false;
            _status = 'NFC read failed. Try again.';
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _status = 'NFC scan could not start on this device.';
      });
    }
  }

  void _stopNfc() {
    if (mounted) setState(() => _scanning = false);
    unawaited(_safeStopSession());
  }

  Future<void> _safeStopSession({String? errorMessageIos}) async {
    if (!_sessionActive) return;
    _sessionActive = false;
    try {
      await NfcManager.instance.stopSession(errorMessageIos: errorMessageIos);
    } catch (_) {}
  }

  String? _extractPayload(NfcTag tag) {
    try {
      // Uses raw tag map for broad compatibility across nfc_manager versions.
      // ignore: invalid_use_of_protected_member
      final map = (tag.data as Map?)?.cast<Object?, Object?>();
      final ndef = map?['ndef'];
      final cached = (ndef as Map?)?['cachedMessage'] as Map?;
      final records = (cached?['records'] ?? cached?['record']) as List?;
      if (records == null || records.isEmpty) return null;
      for (final rec in records) {
        final payloadRaw = (rec as Map)['payload'] as List?;
        if (payloadRaw == null) continue;
        final payload = payloadRaw.map((e) => (e as num).toInt()).toList();
        if (payload.isEmpty) continue;
        final uri = _decodeUriPayload(payload);
        if (uri != null && uri.isNotEmpty) return uri;
        final raw = String.fromCharCodes(payload).trim();
        if (raw.isNotEmpty) return raw;
      }
    } catch (_) {}
    return null;
  }

  String? _decodeUriPayload(List<int> payload) {
    if (payload.isEmpty) return null;
    const prefixes = <String>[
      '',
      'http://www.',
      'https://www.',
      'http://',
      'https://',
      'tel:',
      'mailto:',
      'ftp://anonymous:anonymous@',
      'ftp://ftp.',
      'ftps://',
      'sftp://',
      'smb://',
      'nfs://',
      'ftp://',
      'dav://',
      'news:',
      'telnet://',
      'imap:',
      'rtsp://',
      'urn:',
      'pop:',
      'sip:',
      'sips:',
      'tftp:',
      'btspp://',
      'btl2cap://',
      'btgoep://',
      'tcpobex://',
      'irdaobex://',
      'file://',
      'urn:epc:id:',
      'urn:epc:tag:',
      'urn:epc:pat:',
      'urn:epc:raw:',
      'urn:epc:',
      'urn:nfc:',
    ];
    final prefixCode = payload.first;
    final suffix = String.fromCharCodes(payload.sublist(1));
    final prefix = prefixCode >= 0 && prefixCode < prefixes.length
        ? prefixes[prefixCode]
        : '';
    return ('$prefix$suffix').trim();
  }

  Future<void> _handleScannedPayload(String? raw) async {
    final payload = raw?.trim();
    if (payload == null || payload.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC tag was empty or unsupported.')),
      );
      return;
    }

    if (widget.returnPayloadOnly) {
      if (!mounted) return;
      Navigator.of(context).pop(payload);
      return;
    }

    if (payload.startsWith('artyug://certificate/')) {
      if (!mounted) return;
      context.push('/qr-result', extra: payload);
      return;
    }

    if (payload.startsWith('artyug://artwork/')) {
      final id = payload.replaceFirst('artyug://artwork/', '').trim();
      if (id.isNotEmpty) {
        final configured = await NfcLinkService.getArtworkNfcLink(id);
        if (configured != null && configured.isNotEmpty) {
          await _openInsideAndOfferExternal(configured);
          return;
        }
        if (!mounted) return;
        context.push('/artwork/$id');
        return;
      }
    }

    if (payload.startsWith('http://') || payload.startsWith('https://')) {
      await _openInsideAndOfferExternal(payload);
      return;
    }

    if (!mounted) return;
    context.push('/qr-result', extra: payload);
  }

  Future<void> _openInsideAndOfferExternal(String url) async {
    await _openLinkInApp(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Opened inside Artyug'),
        action: SnackBarAction(
          label: 'Open in browser',
          onPressed: () async {
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }

  Future<void> _openLinkInApp(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebFallback(context);
    return _buildNativeScan(context);
  }

  Widget _buildWebFallback(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kBlack),
              onPressed: () => context.pop()),
          title: const Text('NFC SCAN',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kBlack)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      color: kBg, borderRadius: BorderRadius.circular(24)),
                  child: const Icon(Icons.nfc_outlined, size: 40, color: kGrey),
                ),
                const SizedBox(height: 24),
                const Text('NFC Not Available on Web',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kBlack)),
                const SizedBox(height: 10),
                const Text(
                  'NFC scanning requires the Artyug Android app.\nWeb browsers cannot access NFC hardware.',
                  style: TextStyle(fontSize: 14, color: kGrey, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.pop();
                        context.push('/verify');
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Use QR Scanner Instead',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange, foregroundColor: kWhite),
                    )),
                const SizedBox(height: 12),
                if (widget.returnPayloadOnly &&
                    (widget.preferredPayload?.isNotEmpty == true))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(widget.preferredPayload),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Use default NFC destination'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange, foregroundColor: kWhite),
                    ),
                  ),
                if (widget.returnPayloadOnly &&
                    (widget.preferredPayload?.isNotEmpty == true))
                  const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back')),
              ],
            ),
          ),
        ),
      );

  Widget _buildNativeScan(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kBlack),
              onPressed: () => context.pop()),
          title: const Text('NFC SCAN',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kBlack)),
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
                  child: Center(
                      child: Container(
                    width: 100,
                    height: 100,
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
              const Text('HOLD NEAR NFC TAG',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kBlack,
                    letterSpacing: 1.5,
                  )),
              const SizedBox(height: 8),
              const Text(
                'Place the back of your phone near\nthe artwork\'s NFC tag',
                style: TextStyle(fontSize: 14, color: kGrey, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                _scanning ? 'Scanning in progress...' : _status,
                style: const TextStyle(fontSize: 13, color: kGrey),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: kOrangeLight,
                  borderRadius: BorderRadius.circular(12),
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
                onPressed: () {
                  _stopNfc();
                  context.pop();
                },
                child: const Text('Cancel',
                    style: TextStyle(color: kGrey, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
}
