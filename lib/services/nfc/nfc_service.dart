library artyug.nfc_service;

import 'package:flutter/foundation.dart';

/// NFC Service — capability check and safe platform abstraction.
///
/// nfc_manager is intentionally NOT imported here (web compile incompatibility).
/// The actual NFC tag read/write is triggered via the NfcScanScreen which handles
/// it at the UI level with kIsWeb guards.
///
/// This service provides:
/// - Platform capability detection
/// - NFC payload format spec (artyug://certificate/{id})
/// - Utility to format tag data for storage

class NfcService {
  static const _scheme = 'artyug://certificate/';

  // ─── Capability ──────────────────────────────────────────────────────────

  /// Whether NFC is physically possible on this device.
  /// On web → always false (browsers have no NFC API).
  /// On mobile → true IF the device has NFC hardware (checked at runtime by nfc_manager).
  static bool get isPlatformSupported => !kIsWeb;

  // ─── Payload Format ──────────────────────────────────────────────────────

  /// Build the NFC NDEF URI payload for a certificate.
  static String buildPayload(String certificateId) =>
      '$_scheme$certificateId';

  /// Parse an NFC payload string → certificate ID or null.
  static String? parseCertificateId(String payload) {
    final trimmed = payload.trim();
    if (trimmed.startsWith(_scheme)) {
      final id = trimmed.substring(_scheme.length);
      return id.isNotEmpty ? id : null;
    }
    return null;
  }

  /// Whether the given scanned string looks like an Artyug NFC tag.
  static bool isArtyugTag(String payload) =>
      payload.trim().startsWith(_scheme);

  // ─── Tag Write Spec ──────────────────────────────────────────────────────
  // When writing to an NFC tag (Android only, nfc_manager), write one NDEF record:
  //   - Type: URI (0x01 identifier)
  //   - Payload: buildPayload(certificateId)
  //
  // The tag should be NTAG213 or compatible, minimum 144 bytes.
  // A typical certificate ID (UUID v4, 36 chars) + prefix = ~60 bytes — well within limits.
}
