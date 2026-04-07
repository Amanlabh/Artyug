import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Full browser URL (query + fragment). Prefer over [Uri.base] for OAuth callbacks on web.
Uri oauthBrowserUri() => Uri.parse(web.window.location.href);

/// Removes `code` / `error` query params after OAuth handling so refresh does not re-hit a stale code.
void oauthStripQueryParamsIfOAuthPresent() {
  final uri = Uri.parse(web.window.location.href);
  final q = uri.queryParameters;
  if (!q.containsKey('code') &&
      !q.containsKey('error') &&
      !q.containsKey('error_description')) {
    return;
  }
  final clean = uri.replace(queryParameters: const {});
  web.window.history.replaceState(null, '', clean.toString());
}

void debugLogOAuthUri() {
  if (kDebugMode) {
    debugPrint('[Auth] OAuth URI (web): ${web.window.location.href}');
  }
}
