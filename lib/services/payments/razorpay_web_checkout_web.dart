library artyug.razorpay_web_checkout;

import 'dart:async';
import 'dart:js' as js;

import 'razorpay_web_checkout_types.dart';

Future<RazorpayWebCheckoutResponse> openRazorpayWebCheckout({
  required String keyId,
  required String orderId,
  required int amountPaise,
  required String artworkTitle,
  String? contactEmail,
  String? contactPhone,
}) async {
  final razorpayCtor = js.context['Razorpay'];
  if (razorpayCtor == null) {
    return const RazorpayWebCheckoutResponse(
      success: false,
      errorMessage:
          'Razorpay checkout.js was not loaded. Add the script to web/index.html.',
    );
  }

  final completer = Completer<RazorpayWebCheckoutResponse>();
  final options = js.JsObject.jsify({
    'key': keyId,
    'order_id': orderId,
    'amount': amountPaise,
    'currency': 'INR',
    'name': 'Artyug',
    'description': artworkTitle,
    'retry': {'enabled': true, 'max_count': 2},
    'send_sms_hash': true,
    'theme': {'color': '#1C6EF2'},
    if ((contactEmail ?? '').isNotEmpty || (contactPhone ?? '').isNotEmpty)
      'prefill': {
        if ((contactEmail ?? '').isNotEmpty) 'email': contactEmail,
        if ((contactPhone ?? '').isNotEmpty) 'contact': contactPhone,
      },
  });

  options['handler'] = (dynamic response) {
    if (completer.isCompleted) return;
    final data = _toMap(response);
    completer.complete(
      RazorpayWebCheckoutResponse(
        success: true,
        paymentId: data['razorpay_payment_id']?.toString(),
        orderId: data['razorpay_order_id']?.toString(),
        signature: data['razorpay_signature']?.toString(),
      ),
    );
  };

  options['modal'] = js.JsObject.jsify({
    'ondismiss': () {
      if (completer.isCompleted) return;
      completer.complete(
        const RazorpayWebCheckoutResponse(
          success: false,
          errorMessage: 'Payment was cancelled before completion.',
        ),
      );
    },
  });

  final instance = js.JsObject(razorpayCtor as js.JsFunction, [options]);
  instance.callMethod('on', [
    'payment.failed',
    (dynamic response) {
      if (completer.isCompleted) return;
      final data = _toMap(response);
      final error = data['error'];
      String? message;
      if (error is Map) {
        message = error['description']?.toString() ??
            error['reason']?.toString() ??
            error['step']?.toString();
      }
      completer.complete(
        RazorpayWebCheckoutResponse(
          success: false,
          errorMessage: message ?? 'Razorpay payment failed.',
        ),
      );
    },
  ]);

  instance.callMethod('open');
  return completer.future;
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is js.JsObject) {
    final keys =
        js.context['Object'].callMethod('keys', [value]) as List<dynamic>;
    return {
      for (final key in keys) key.toString(): _unwrap(value[key]),
    };
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

dynamic _unwrap(dynamic value) {
  if (value is js.JsObject) {
    return _toMap(value);
  }
  return value;
}
