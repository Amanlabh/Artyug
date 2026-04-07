library artyug.payment_service;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

/// Payment Service — gateway abstraction for Razorpay, Dodo Payments, Stripe Checkout.
///
/// **Secrets:** Razorpay `KEY_ID` may live in the client; order creation uses the
/// `create-razorpay-order` Edge Function. Dodo and Stripe secret keys should be set as
/// Supabase Edge Function secrets (`create-dodo-checkout`, `create-stripe-checkout`).
///
/// Deploy the functions under `supabase/functions/` and set:
///   supabase secrets set DODO_PAYMENTS_API_KEY=...
///   supabase secrets set STRIPE_SECRET_KEY=sk_test_... or sk_live_...
/// Optional: DODO_PAYMENTS_DEFAULT_PRODUCT_ID, DODO_PAYMENTS_MODE=test_mode|live_mode

enum PaymentGateway { razorpay, dodo, stripe, demo }

/// User-selectable live checkout rail (subset of [PaymentGateway]).
enum CheckoutPaymentMethod { razorpay, dodo, stripe }

class PaymentResult {
  final bool success;
  final String? orderId;
  final String? razorpayOrderId;
  final String? errorMessage;
  final PaymentGateway gateway;
  final double amount;
  final String currency;
  final String? hostedCheckoutUrl;

  const PaymentResult({
    required this.success,
    this.orderId,
    this.razorpayOrderId,
    this.errorMessage,
    required this.gateway,
    required this.amount,
    required this.currency,
    this.hostedCheckoutUrl,
  });

  bool get isDemo => gateway == PaymentGateway.demo;
  bool get requiresWebRedirect =>
      (gateway == PaymentGateway.razorpay ||
          gateway == PaymentGateway.dodo ||
          gateway == PaymentGateway.stripe) &&
      hostedCheckoutUrl != null;
}

class PaymentService {
  static String defaultPaymentReturnUrl() {
    final base = AppConfig.publicSiteUrl;
    if (base != null && base.isNotEmpty) {
      final u = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      return '$u/orders';
    }
    if (kIsWeb) {
      final o = Uri.base.origin;
      return '$o/orders';
    }
    return 'https://artyug.app/orders';
  }

  /// In-app **Live** mode: which hosted checkouts to offer (from .env / flags).
  static List<CheckoutPaymentMethod> availableCheckoutMethods() {
    final out = <CheckoutPaymentMethod>[];
    if (AppConfig.razorpayKeyId != null && AppConfig.razorpayKeyId!.trim().isNotEmpty) {
      out.add(CheckoutPaymentMethod.razorpay);
    }
    if (AppConfig.dodoCheckoutEnabled) {
      out.add(CheckoutPaymentMethod.dodo);
    }
    if (AppConfig.stripeCheckoutEnabled) {
      out.add(CheckoutPaymentMethod.stripe);
    }
    return out;
  }

  static PaymentGateway gatewayForMethod(CheckoutPaymentMethod m) {
    switch (m) {
      case CheckoutPaymentMethod.razorpay:
        return PaymentGateway.razorpay;
      case CheckoutPaymentMethod.dodo:
        return PaymentGateway.dodo;
      case CheckoutPaymentMethod.stripe:
        return PaymentGateway.stripe;
    }
  }

  /// [runtimeLiveMode] comes from [AppModeProvider] — must match the in-app Demo/Live toggle.
  static PaymentGateway resolveGateway({
    required bool runtimeLiveMode,
    required String currency,
    CheckoutPaymentMethod? selectedMethod,
  }) {
    if (!runtimeLiveMode) return PaymentGateway.demo;
    if (selectedMethod != null) {
      return gatewayForMethod(selectedMethod);
    }
    if (currency == 'INR' &&
        AppConfig.razorpayKeyId != null &&
        AppConfig.razorpayKeyId!.trim().isNotEmpty) {
      return PaymentGateway.razorpay;
    }
    if (AppConfig.dodoCheckoutEnabled) return PaymentGateway.dodo;
    if (AppConfig.stripeCheckoutEnabled) return PaymentGateway.stripe;
    return PaymentGateway.demo;
  }

  static String formatAmount(double amount, String currency) {
    switch (currency) {
      case 'INR':
        return '₹${amount.toStringAsFixed(0)}';
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'SOL':
        return '${amount.toStringAsFixed(4)} SOL';
      default:
        return '${amount.toStringAsFixed(2)} $currency';
    }
  }

  static int toSmallestUnit(double amount, String currency) {
    switch (currency) {
      case 'INR':
      case 'USD':
        return (amount * 100).round();
      default:
        return amount.round();
    }
  }

  static Future<PaymentResult?> initiateRazorpayPayment({
    required String artworkId,
    required double amountInr,
    String? receiptId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (session == null) return null;

      final response = await client.functions.invoke(
        'create-razorpay-order',
        body: {
          'amount_inr': amountInr,
          'artwork_id': artworkId,
          if (receiptId != null) 'receipt': receiptId,
        },
      );

      if (response.status != 200) {
        final errBody = response.data is Map
            ? (response.data as Map)['error']
            : response.data?.toString();
        debugPrint('[PaymentService] Edge function error: $errBody');
        return null;
      }

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      final razorpayOrderId = data['order_id'] as String?;
      final hostedUrl = data['hosted_url'] as String?;

      if (razorpayOrderId == null) return null;

      if (kIsWeb && hostedUrl != null) {
        final uri = Uri.parse(hostedUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      return PaymentResult(
        success: true,
        razorpayOrderId: razorpayOrderId,
        gateway: PaymentGateway.razorpay,
        amount: amountInr,
        currency: 'INR',
        hostedCheckoutUrl: hostedUrl,
      );
    } catch (e) {
      debugPrint('[PaymentService] initiateRazorpayPayment failed: $e');
      return null;
    }
  }

  /// Dodo Payments hosted checkout via Edge Function `create-dodo-checkout`.
  static Future<PaymentResult?> initiateDodoCheckout({
    required String artworkId,
    required String artworkTitle,
    required double amountInr,
    required Map<String, dynamic> billingAddress,
    String? returnUrl,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return null;

      final response = await client.functions.invoke(
        'create-dodo-checkout',
        body: {
          'artwork_id': artworkId,
          'artwork_title': artworkTitle,
          'amount_inr': amountInr,
          'return_url': returnUrl ?? defaultPaymentReturnUrl(),
          'billing_address': billingAddress,
          // Pass the key from .env so Edge Function can use it even without env secrets
          if ((AppConfig.dodoPaymentsApiKey ?? '').isNotEmpty)
            'api_key': AppConfig.dodoPaymentsApiKey,
          'metadata': {
            'artwork_id': artworkId,
            'source': 'artyug_flutter',
          },
        },
      );

      if (response.status != 200) {
        debugPrint('[PaymentService] create-dodo-checkout error ${response.status}: ${response.data}');
        return null;
      }

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      final url = _pickHostedUrl(data);
      if (url == null) return null;

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: url));
      }

      return PaymentResult(
        success: true,
        gateway: PaymentGateway.dodo,
        amount: amountInr,
        currency: 'INR',
        hostedCheckoutUrl: url,
      );
    } catch (e) {
      debugPrint('[PaymentService] initiateDodoCheckout failed: $e');
      return null;
    }
  }

  /// Stripe Checkout Session via Edge Function `create-stripe-checkout`.
  static Future<PaymentResult?> initiateStripeCheckout({
    required String artworkId,
    required String artworkTitle,
    required double amountInr,
    required Map<String, dynamic> billingAddress,
    String? redirectUrl,
    String? cancelUrl,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return null;

      final ret = redirectUrl ?? defaultPaymentReturnUrl();
      final response = await client.functions.invoke(
        'create-stripe-checkout',
        body: {
          'artwork_id': artworkId,
          'artwork_title': artworkTitle,
          'amount_inr': amountInr,
          'success_url': ret,
          'cancel_url': cancelUrl ?? ret,
          'metadata': {
            'artwork_id': artworkId,
            'source': 'artyug_flutter',
            ...billingAddress.map((k, v) => MapEntry('addr_$k', v)),
          },
        },
      );

      if (response.status != 200) {
        debugPrint('[PaymentService] create-stripe-checkout: ${response.data}');
        return null;
      }

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      final url = _pickHostedUrl(data);
      if (url == null) return null;

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: url));
      }

      return PaymentResult(
        success: true,
        gateway: PaymentGateway.stripe,
        amount: amountInr,
        currency: 'INR',
        hostedCheckoutUrl: url,
      );
    } catch (e) {
      debugPrint('[PaymentService] initiateStripeCheckout failed: $e');
      return null;
    }
  }

  static String? _pickHostedUrl(Map<String, dynamic> data) {
    final stripeUrl = data['url'] as String?;
    if (stripeUrl != null && stripeUrl.isNotEmpty) return stripeUrl;
    final direct = data['hosted_url'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;
    final checkoutUrl = data['checkout_url'] as String?;
    if (checkoutUrl != null && checkoutUrl.isNotEmpty) return checkoutUrl;
    final nested = data['data'];
    if (nested is Map) {
      final h = nested['hosted_url'] as String?;
      if (h != null && h.isNotEmpty) return h;
      final u = nested['url'] as String?;
      if (u != null && u.isNotEmpty) return u;
      final hosts = nested['hosted_url'];
      if (hosts is String && hosts.isNotEmpty) return hosts;
    }
    return null;
  }

  static Future<PaymentResult> demoPayment({
    required String artworkId,
    required double amount,
    required String currency,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return PaymentResult(
      success: true,
      orderId:
          'DEMO_${DateTime.now().millisecondsSinceEpoch}_${artworkId.substring(0, artworkId.length > 8 ? 8 : artworkId.length)}',
      gateway: PaymentGateway.demo,
      amount: amount,
      currency: currency,
    );
  }

  /// Explains why hosted checkout is blocked when the app is in Live mode.
  static String? blockMessageForLiveMode(bool runtimeLiveMode) {
    final reason = AppConfig.livePaymentBlockReasonWhenLive(runtimeLiveMode);
    if (reason == null) return null;
    return 'Live payments are not configured ($reason). Add keys or enable '
        'CHECKOUT_ENABLE_DODO / CHECKOUT_ENABLE_STRIPE and deploy Edge Functions.';
  }

  /// Razorpay-only guard (key id must be present for hosted order).
  static String? get razorpayBlockMessage {
    if (AppConfig.razorpayKeyId == null || AppConfig.razorpayKeyId!.trim().isEmpty) {
      return 'RAZORPAY_KEY_ID is not set';
    }
    return null;
  }
}
