import '../core/config/supabase_client.dart';
import '../models/certificate.dart';

class CertificateRepository {
  static final _client = SupabaseClientHelper.db;

  static const _scheme = 'artyug://certificate/';

  /// Lookup a certificate by QR code — used by the verify scanner.
  ///
  /// Accepts:
  ///   - Full deep-link: `artyug://certificate/{id}`
  ///   - Bare UUID/cert ID
  ///
  /// Strategy:
  ///   1. Try exact `qr_code` column match (handles full deep-link stored in DB)
  ///   2. Try matching as bare cert ID in `qr_code` column
  ///   3. Try direct `id` column match (cert ID entered manually)
  static Future<CertificateModel?> verifyByQrCode(String input) async {
    final code = input.trim();
    if (code.isEmpty) return null;

    // Strategy 1 — exact match on qr_code column
    var data = await _client
        .from('certificates')
        .select()
        .eq('qr_code', code)
        .maybeSingle();
    if (data != null) return CertificateModel.fromJson(data);

    // Strategy 2 — try with the deep-link prefix prepended
    final withPrefix = '$_scheme$code';
    data = await _client
        .from('certificates')
        .select()
        .eq('qr_code', withPrefix)
        .maybeSingle();
    if (data != null) return CertificateModel.fromJson(data);

    // Strategy 3 — treat as direct certificate ID
    data = await _client
        .from('certificates')
        .select()
        .eq('id', code)
        .maybeSingle();
    if (data != null) return CertificateModel.fromJson(data);

    return null;
  }

  /// Fetch all certificates owned by the current user
  static Future<List<CertificateModel>> getMyCollection() async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) return [];
    final data = await _client
        .from('certificates')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => CertificateModel.fromJson(e)).toList();
  }

  /// Fetch a single certificate by its ID
  static Future<CertificateModel?> getCertificateById(String certId) async {
    final data = await _client
        .from('certificates')
        .select()
        .eq('id', certId)
        .maybeSingle();
    if (data == null) return null;
    return CertificateModel.fromJson(data);
  }

  /// Fetch all certificates for artworks sold by this artist
  static Future<List<CertificateModel>> getCreatorIssuedCertificates(
      String artistId) async {
    final data = await _client
        .from('certificates')
        .select()
        .eq('artist_id', artistId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => CertificateModel.fromJson(e)).toList();
  }

  /// Update the NFC enabled status on a certificate
  static Future<void> setNfcEnabled(String certId, bool enabled) async {
    await _client
        .from('certificates')
        .update({'nfc_enabled': enabled}).eq('id', certId);
  }
}
