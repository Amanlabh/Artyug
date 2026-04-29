import 'razorpay_web_checkout_types.dart';

Future<RazorpayWebCheckoutResponse> openRazorpayWebCheckout({
  required String keyId,
  required String orderId,
  required int amountPaise,
  required String artworkTitle,
  String? contactEmail,
  String? contactPhone,
}) async {
  return const RazorpayWebCheckoutResponse(
    success: false,
    errorMessage: 'Razorpay web checkout is only available in web builds.',
  );
}
