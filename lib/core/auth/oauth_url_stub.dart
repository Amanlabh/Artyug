import 'package:flutter/foundation.dart';

/// Non-web: [Uri.base] is sufficient.
Uri oauthBrowserUri() => Uri.base;

/// No-op outside web.
void oauthStripQueryParamsIfOAuthPresent() {}

void debugLogOAuthUri() {
  if (kDebugMode) {
    debugPrint('[Auth] OAuth URI (stub): ${oauthBrowserUri()}');
  }
}
