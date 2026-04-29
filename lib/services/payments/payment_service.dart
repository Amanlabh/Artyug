library artyug.payment_service;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import 'razorpay_web_checkout_stub.dart'
    if (dart.library.js_interop) 'razorpay_web_checkout_web.dart'
    as razorpay_web;

/// Payment Service - Razorpay (live), Dodo and Stripe (coming soon).
///
/// Native flow:
///   1. Call [initiateRazorpayPayment] to create an order via
///      `create-razorpay-order`.
///   2. Open the native Razorpay sheet.
///   3. Resolve through the plugin callbacks.
///
/// Web flow:
///   Uses Razorpay Checkout.js with the server-created `order_id`.

enum PaymentGateway { razorpay, dodo, stripe, demo }

/// User-selectable live checkout rail (subset of [PaymentGateway]).
enum CheckoutPaymentMethod { razorpay, dodo, stripe }

class PaymentResult {
  final bool success;
  final String? orderId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? errorMessage;
  final PaymentGateway gateway;
  final double amount;
  final String currency;
  final String? hostedCheckoutUrl;

  const PaymentResult({
    required this.success,
    this.orderId,
    this.razorpayOrderId,
    this.razorpayPaymentId,
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
      final normalized =
          base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      return '$normalized/orders';
    }
    if (kIsWeb) {
      return '${Uri.base.origin}/orders';
    }
    return 'https://artyug.app/orders';
  }

  /// Only Razorpay is currently live. Dodo and Stripe are coming soon.
  static List<CheckoutPaymentMethod> availableCheckoutMethods() {
    final out = <CheckoutPaymentMethod>[];
    if (AppConfig.razorpayKeyId != null &&
        AppConfig.razorpayKeyId!.trim().isNotEmpty) {
      out.add(CheckoutPaymentMethod.razorpay);
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

  static Future<PaymentResult> openNativeRazorpay({
    required String orderId,
    required int amountPaise,
    required String artworkTitle,
    String? contactEmail,
    String? contactPhone,
  }) {
    final completer = Completer<PaymentResult>();
    final razorpay = Razorpay();

    void cleanUp() {
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse resp) {
      cleanUp();
      completer.complete(
        PaymentResult(
          success: true,
          razorpayOrderId: orderId,
          razorpayPaymentId: resp.paymentId,
          gateway: PaymentGateway.razorpay,
          amount: amountPaise / 100.0,
          currency: 'INR',
        ),
      );
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse resp) {
      cleanUp();
      completer.complete(
        PaymentResult(
          success: false,
          razorpayOrderId: orderId,
          errorMessage: resp.message ?? 'Payment failed or cancelled',
          gateway: PaymentGateway.razorpay,
          amount: amountPaise / 100.0,
          currency: 'INR',
        ),
      );
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse resp) {
      cleanUp();
      completer.complete(
        PaymentResult(
          success: true,
          razorpayOrderId: orderId,
          errorMessage: 'External wallet: ${resp.walletName}',
          gateway: PaymentGateway.razorpay,
          amount: amountPaise / 100.0,
          currency: 'INR',
        ),
      );
    });

    final options = <String, dynamic>{
      'key': AppConfig.razorpayKeyId,
      'order_id': orderId,
      'amount': amountPaise,
      'name': 'Artyug',
      'description': artworkTitle,
      'currency': 'INR',
      'prefill': <String, dynamic>{
        if (contactEmail != null) 'email': contactEmail,
        if (contactPhone != null) 'contact': contactPhone,
      },
      'theme': {'color': '#1C6EF2'},
      'send_sms_hash': true,
      'retry': {'enabled': true, 'max_count': 2},
    };

    razorpay.open(options);
    return completer.future;
  }

  static Future<PaymentResult?> initiateRazorpayPayment({
    required String artworkId,
    required double amountInr,
    required String artworkTitle,
    String? contactEmail,
    String? contactPhone,
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
      final amountPaise =
          (data['amount'] as num?)?.toInt() ?? (amountInr * 100).round();
      final keyId = data['key_id'] as String? ?? AppConfig.razorpayKeyId;

      if (razorpayOrderId == null) {
        debugPrint('[PaymentService] No order_id in Edge Function response');
        return null;
      }

      if (!kIsWeb) {
        return await openNativeRazorpay(
          orderId: razorpayOrderId,
          amountPaise: amountPaise,
          artworkTitle: artworkTitle,
          contactEmail: contactEmail,
          contactPhone: contactPhone,
        );
      }

      if (keyId == null || keyId.trim().isEmpty) {
        return PaymentResult(
          success: false,
          razorpayOrderId: razorpayOrderId,
          errorMessage:
              'Live web checkout is not configured correctly. Missing Razorpay key_id in server response.',
          gateway: PaymentGateway.razorpay,
          amount: amountInr,
          currency: 'INR',
        );
      }

      final webResult = await razorpay_web.openRazorpayWebCheckout(
        keyId: keyId,
        orderId: razorpayOrderId,
        amountPaise: amountPaise,
        artworkTitle: artworkTitle,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
      );

      return PaymentResult(
        success: webResult.success,
        razorpayOrderId: webResult.orderId ?? razorpayOrderId,
        razorpayPaymentId: webResult.paymentId,
        errorMessage: webResult.errorMessage,
        gateway: PaymentGateway.razorpay,
        amount: amountInr,
        currency: 'INR',
      );
    } catch (e) {
      debugPrint('[PaymentService] initiateRazorpayPayment failed: $e');
      return null;
    }
  }

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
          if ((AppConfig.dodoPaymentsApiKey ?? '').isNotEmpty)
            'api_key': AppConfig.dodoPaymentsApiKey,
          'metadata': {'artwork_id': artworkId, 'source': 'artyug_flutter'},
        },
      );

      if (response.status != 200) {
        debugPrint(
          '[PaymentService] create-dodo-checkout error: ${response.data}',
        );
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
      final hosted = nested['hosted_url'] as String?;
      if (hosted != null && hosted.isNotEmpty) return hosted;

      final url = nested['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
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

  static String? blockMessageForLiveMode(bool runtimeLiveMode) {
    final reason = AppConfig.livePaymentBlockReasonWhenLive(runtimeLiveMode);
    if (reason == null) return null;
    return 'Live payments are not configured ($reason). Add RAZORPAY_KEY_ID to .env.';
  }

  static String? get razorpayBlockMessage {
    if (AppConfig.razorpayKeyId == null ||
        AppConfig.razorpayKeyId!.trim().isEmpty) {
      return 'RAZORPAY_KEY_ID is not set';
    }
    return null;
  }
}
