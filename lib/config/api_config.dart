import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Gemini (Google AI) — keys and model id from `.env`.
/// Docs: https://ai.google.dev/gemini-api/docs/models/gemini
class ApiConfig {
  static String get geminiApiKey {
    final a = dotenv.env['GEMINI_API_KEY']?.trim();
    if (a != null && a.isNotEmpty) return a;
    final b = dotenv.env['GOOGLE_AI_API_KEY']?.trim();
    return b ?? '';
  }

  /// Stable default; override with `GEMINI_MODEL` in `.env` if needed.
  static String get geminiModel {
    final m = dotenv.env['GEMINI_MODEL']?.trim();
    if (m != null && m.isNotEmpty) return m;
    return 'gemini-2.5-flash';
  }

  static bool validateApiKeys() {
    final k = geminiApiKey;
    if (k.isEmpty || k == 'YOUR_GEMINI_API_KEY_HERE') return false;
    return true;
  }
}
