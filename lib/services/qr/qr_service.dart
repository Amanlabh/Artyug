library artyug.qr_service;

/// QR Service — generates and parses Artyug QR code payloads.
///
/// Format spec:
///   artyug://certificate/{certificateId}
///   artyug://artwork/{artworkId}
///   artyug://profile/{userId}
///
/// All QR data is kept human-readable so third-party scanners can still open
/// the deep link URL fallback: https://app.artyug.art/certificate/{id}

class QrService {
  static const _scheme = 'artyug://';
  static const _fallbackBase = 'https://app.artyug.art';

  // ─── Generate ─────────────────────────────────────────────────────────────

  /// Generate a QR payload for a certificate.
  static String forCertificate(String certificateId) =>
      '${_scheme}certificate/$certificateId';

  /// Generate a QR payload for an artwork.
  static String forArtwork(String artworkId) =>
      '${_scheme}artwork/$artworkId';

  /// Generate a QR payload for a user profile.
  static String forProfile(String userId) =>
      '${_scheme}profile/$userId';

  /// Web fallback URL that can be opened in any browser.
  static String fallbackUrl(String type, String id) =>
      '$_fallbackBase/$type/$id';

  // ─── Parse ────────────────────────────────────────────────────────────────

  /// Parse a scanned QR string → [QrPayload] or null if unrecognized.
  static QrPayload? parse(String raw) {
    final sanitized = raw.trim();

    // Native deep link
    if (sanitized.startsWith(_scheme)) {
      final path = sanitized.substring(_scheme.length);
      return _parsePath(path);
    }

    // Web fallback URL
    if (sanitized.startsWith(_fallbackBase)) {
      final uri = Uri.tryParse(sanitized);
      if (uri != null) {
        final path = uri.path.replaceFirst('/', '');
        return _parsePath(path);
      }
    }

    // Bare UUID — assume certificate
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    if (uuidRegex.hasMatch(sanitized)) {
      return QrPayload(type: QrType.certificate, id: sanitized);
    }

    return null;
  }

  static QrPayload? _parsePath(String path) {
    final parts = path.split('/');
    if (parts.length < 2) return null;
    final type = parts[0];
    final id = parts[1];
    if (id.isEmpty) return null;

    switch (type) {
      case 'certificate':
        return QrPayload(type: QrType.certificate, id: id);
      case 'artwork':
        return QrPayload(type: QrType.artwork, id: id);
      case 'profile':
        return QrPayload(type: QrType.profile, id: id);
      default:
        return null;
    }
  }
}

// ─── Value objects ────────────────────────────────────────────────────────────

enum QrType { certificate, artwork, profile, unknown }

class QrPayload {
  final QrType type;
  final String id;

  const QrPayload({required this.type, required this.id});

  String get routePath {
    switch (type) {
      case QrType.certificate:
        return '/certificate/$id';
      case QrType.artwork:
        return '/artwork/$id';
      case QrType.profile:
        return '/public-profile/$id';
      case QrType.unknown:
        return '/authenticate';
    }
  }

  @override
  String toString() => 'QrPayload(type: $type, id: $id)';
}
