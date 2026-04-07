// NFC stub for web — provides empty interface so nfc_scan_screen.dart compiles on web
// This file is selected by conditional import when running on web

class NfcManager {
  static final NfcManager instance = NfcManager._();
  NfcManager._();
  Future<bool> isAvailable() async => false;
  Future<void> stopSession({String? errorMessage}) async {}
  void startSession({
    required Future<void> Function(dynamic tag) onDiscovered,
    Future<void> Function(dynamic error)? onError,
  }) {}
}

class NfcTag {}
class Ndef {
  static Ndef? from(NfcTag tag) => null;
  dynamic get cachedMessage => null;
}
class NdefMessage {
  List<NdefRecord> get records => [];
}
class NdefRecord {
  dynamic get typeNameFormat => null;
  List<int> get payload => [];
}
class NdefTypeNameFormat {
  static const nfcWellknown = 'nfcWellknown';
}
