// Model for orders table
class OrderModel {
  final String id;
  final String? artworkId;
  final String? artworkTitle;
  final String? artworkMediaUrl;
  final String? artworkType;
  final String buyerId;
  final String? buyerName;
  final String? sellerId;
  final String? sellerName;
  final double? amount;
  final String? currency;
  final String? paymentMethod;
  final String status;
  final bool authenticityEnabled;
  final String? certificateId;
  final String? purchaseMode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderModel({
    required this.id,
    this.artworkId,
    this.artworkTitle,
    this.artworkMediaUrl,
    this.artworkType,
    required this.buyerId,
    this.buyerName,
    this.sellerId,
    this.sellerName,
    this.amount,
    this.currency,
    this.paymentMethod,
    this.status = 'pending',
    this.authenticityEnabled = true,
    this.certificateId,
    this.purchaseMode,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      artworkId: json['artwork_id'] as String?,
      artworkTitle: json['artwork_title'] as String?,
      artworkMediaUrl: json['artwork_media_url'] as String?,
      artworkType: json['artwork_type'] as String?,
      buyerId: json['buyer_id'] as String,
      buyerName: json['buyer_name'] as String?,
      sellerId: json['seller_id'] as String?,
      sellerName: json['seller_name'] as String?,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      currency: json['currency'] as String?,
      paymentMethod: json['payment_method'] as String?,
      status: json['status'] as String? ?? 'pending',
      authenticityEnabled: json['authenticity_enabled'] as bool? ?? true,
      certificateId: json['certificate_id'] as String?,
      purchaseMode: json['purchase_mode'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get hasCertificate => certificateId != null && authenticityEnabled;
  bool get isDemoPurchase =>
      purchaseMode != null && purchaseMode!.toLowerCase() == 'demo';

  String get displayAmount => amount != null
      ? '₹${amount!.toStringAsFixed(0)}'
      : 'Free';

  String get statusLabel => switch (status) {
    'completed' => 'Completed',
    'pending' => 'Pending',
    'cancelled' => 'Cancelled',
    'failed' => 'Failed',
    _ => status,
  };
}
