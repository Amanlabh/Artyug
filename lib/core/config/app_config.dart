import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppMode { demo, live }

enum ChainMode { devnet, mainnet }

class AppConfig {
  // ─── Supabase ────────────────────────────────────────────────────────────
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Optional. If set, used as Supabase OAuth `redirect_to` (web builds behind proxies, custom domains).
  /// Otherwise web uses [Uri.base.origin] and mobile uses `artyug://login-callback`.
  static String? get oauthRedirectUrl => dotenv.env['OAUTH_REDIRECT_URL'];

  // ─── App & Chain Mode ────────────────────────────────────────────────────
  static AppMode get appMode =>
      dotenv.env['ARTYUG_APP_MODE']?.toLowerCase() == 'live'
          ? AppMode.live
          : AppMode.demo;

  static ChainMode get chainMode =>
      dotenv.env['ARTYUG_CHAIN_MODE']?.toLowerCase() == 'mainnet'
          ? ChainMode.mainnet
          : ChainMode.devnet;

  static bool get isDemoMode => appMode == AppMode.demo;
  static bool get isLiveMode => appMode == AppMode.live;

  // ─── Feature Flags ───────────────────────────────────────────────────────
  static bool get nfcEnabled =>
      dotenv.env['ENABLE_NFC']?.toLowerCase() == 'true';

  /// Off only when explicitly disabled. Default on so a configured
  /// [solanaPrivateKey] alone enables devnet/mainnet memo attestation.
  static bool get solanaEnabled {
    final raw = dotenv.env['ENABLE_SOLANA']?.toLowerCase().trim();
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return true;
  }

  // ─── Blockchain ──────────────────────────────────────────────────────────
  static String get solanaRpcUrl =>
      dotenv.env['SOLANA_RPC_URL']?.trim().isNotEmpty == true
          ? dotenv.env['SOLANA_RPC_URL']!.trim()
          : 'https://api.devnet.solana.com';

  /// Base58 Solana keypair: **64 bytes** `[secret|pub]` (Phantom “export private key”)
  /// or **32-byte** secret seed. A **public wallet address alone cannot sign** txs.
  static String? get solanaPrivateKey {
    final k = dotenv.env['SOLANA_PRIVATE_KEY'];
    if (k == null) return null;
    final t = k.trim();
    return t.isEmpty ? null : t;
  }

  // ─── Payments ────────────────────────────────────────────────────────────
  static String? get razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'];

  /// Raw Dodo API key from .env (used to pass to Edge Function when env secret not set).
  static String? get dodoPaymentsApiKey => dotenv.env['DODO_PAYMENTS_API_KEY']?.trim();

  /// When true, shows Dodo checkout — API key should live in Supabase Edge Function secrets
  /// (recommended). You may also set DODO_PAYMENTS_API_KEY here for local experiments only
  /// (never ship web builds with secrets in .env).
  static bool get dodoCheckoutEnabled {
    final key = dotenv.env['DODO_PAYMENTS_API_KEY']?.trim();
    if (key != null && key.isNotEmpty) return true;
    final flag = dotenv.env['CHECKOUT_ENABLE_DODO']?.toLowerCase().trim();
    return flag == 'true' || flag == '1' || flag == 'yes';
  }

  /// Stripe Checkout: secret key on Edge Function `create-stripe-checkout`, or enable flag after deploy.
  static bool get stripeCheckoutEnabled {
    final key = dotenv.env['STRIPE_PUBLISHABLE_KEY']?.trim();
    if (key != null && key.isNotEmpty) return true;
    final flag = dotenv.env['CHECKOUT_ENABLE_STRIPE']?.toLowerCase().trim();
    return flag == 'true' || flag == '1' || flag == 'yes';
  }

  /// Arc Pay — reserved; when true, will appear as a selectable method (not implemented yet).
  static bool get arcPayCheckoutEnabled {
    final flag = dotenv.env['CHECKOUT_ENABLE_ARC_PAY']?.toLowerCase().trim();
    return flag == 'true' || flag == '1' || flag == 'yes';
  }

  /// Optional site origin for payment return URLs (e.g. https://app.artyug.art).
  static String? get publicSiteUrl => dotenv.env['PUBLIC_SITE_URL']?.trim();

  /// Optional HTTP API base (BFF) if you proxy payments outside Supabase.
  static String? get apiBaseUrl {
    final u = dotenv.env['API_BASE_URL']?.trim();
    return u != null && u.isNotEmpty ? u : null;
  }

  // ─── Guards ──────────────────────────────────────────────────────────────
  /// Env-only check (ignores in-app Demo/Live toggle). Prefer [livePaymentBlockReasonWhenLive].
  static String? get livePaymentBlockReason {
    if (isDemoMode) return null;
    return _livePaymentMissingGatewaysReason;
  }

  /// When the user has chosen **Live** in the app, returns null if at least one gateway is enabled.
  static String? livePaymentBlockReasonWhenLive(bool runtimeLiveMode) {
    if (!runtimeLiveMode) return null;
    return _livePaymentMissingGatewaysReason;
  }

  static String? get _livePaymentMissingGatewaysReason {
    final hasRazorpay = razorpayKeyId != null && razorpayKeyId!.trim().isNotEmpty;
    if (hasRazorpay || dodoCheckoutEnabled || stripeCheckoutEnabled) return null;
    return 'Configure at least one of: RAZORPAY_KEY_ID, CHECKOUT_ENABLE_DODO (+ Edge Function '
        'secret DODO_PAYMENTS_API_KEY), or CHECKOUT_ENABLE_STRIPE (+ Edge Function secret STRIPE_SECRET_KEY)';
  }

  static bool get canMakeRealPayments => livePaymentBlockReason == null;

  /// Returns null if Solana is ready, or a reason string if blocked.
  static String? get solanaBlockReason {
    if (!solanaEnabled) return 'Solana is disabled (set ENABLE_SOLANA=false)';
    if (solanaPrivateKey == null) {
      return 'SOLANA_PRIVATE_KEY is missing — use base58 secret key (64-byte keypair or 32-byte seed), not your public address';
    }
    return null;
  }

  static bool get isSolanaReady => solanaBlockReason == null;
}
