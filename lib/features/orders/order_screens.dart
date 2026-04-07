import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/order.dart' as app_order;

// ─── Order List Screen ──────────────────────────────────────────────────────
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});
  @override
  State<OrderListScreen> createState() => _OrderListState();
}

class _OrderListState extends State<OrderListScreen> {
  List<app_order.OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final data = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() {
        _orders = (data as List)
            .map((m) => app_order.OrderModel.fromJson(m as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _orders = []; _loading = false; });
    }
  }

  String _formatAmount(double? amount, String currency) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return fmt.format(amount ?? 0);
  }

  Color _statusColor(String s) => switch (s) {
    'completed' => const Color(0xFF16A34A),
    'pending' => Colors.amber[700]!,
    'failed' => const Color(0xFFDC2626),
    _ => kGrey,
  };

  Widget _modePill(app_order.OrderModel o) {
    final isDemo = o.isDemoPurchase;
    final color = isDemo ? AppColors.warning : AppColors.success;
    final label = isDemo ? 'DEMO' : 'LIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      backgroundColor: kBg, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: kBlack), onPressed: () => context.pop()),
      title: const Text('MY ORDERS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack)),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: kOrange))
        : _orders.isEmpty
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 64, color: kGrey),
                  const SizedBox(height: 16),
                  const Text('No orders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack)),
                  const SizedBox(height: 8),
                  const Text('Your purchases will appear here.', style: TextStyle(color: kGrey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/main'),
                    style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: kWhite),
                    child: const Text('Browse Art', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ))
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final o = _orders[i];
                    return GestureDetector(
                      onTap: () => context.push('/order/${o.id}', extra: o),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(children: [
                          // Artwork thumbnail
                          Container(
                            width: 68, height: 68,
                            decoration: BoxDecoration(
                              color: kBg, borderRadius: BorderRadius.circular(12),
                            ),
                            child: o.artworkMediaUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(o.artworkMediaUrl!, fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.image_outlined, size: 28, color: kGrey),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.artworkTitle ?? 'Artwork', style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textOnLight,
                              ), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                'by ${o.sellerName ?? 'Artist'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textOnLightSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(children: [
                                Text(_formatAmount(o.amount, o.currency ?? 'INR'), style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textOnLight,
                                )),
                                const SizedBox(width: 8),
                                _modePill(o),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(o.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(o.status.toUpperCase(), style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor(o.status), letterSpacing: 0.5,
                                  )),
                                ),
                              ]),
                              if (o.hasCertificate) ...[
                                const SizedBox(height: 6),
                                Row(children: [
                                  const Icon(Icons.verified_outlined, size: 13, color: kOrange),
                                  const SizedBox(width: 4),
                                  const Text('Certificate Issued', style: TextStyle(fontSize: 11, color: kOrange, fontWeight: FontWeight.w600)),
                                ]),
                              ],
                            ],
                          )),
                          const Icon(Icons.chevron_right, color: AppColors.textOnLightSecondary, size: 20),
                        ]),
                      ),
                    );
                  },
                ),
              ),
  );
}

// ─── Order Detail Loader — used when navigation has no `extra` ────────────────
class OrderDetailLoadingScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailLoadingScreen({super.key, required this.orderId});
  @override
  State<OrderDetailLoadingScreen> createState() => _OrderDetailLoadingScreenState();
}

class _OrderDetailLoadingScreenState extends State<OrderDetailLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Try Supabase
    try {
      final data = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .single();
      final order = app_order.OrderModel.fromJson(data);
      if (!mounted) return;
      context.replace('/order/${widget.orderId}', extra: order);
    } catch (_) {
      // Fall back to list
      if (mounted) context.go('/orders');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: const Center(child: CircularProgressIndicator(color: kOrange)),
  );
}

// ─── Order Detail Screen ──────────────────────────────────────────────────────
class OrderDetailScreen extends StatelessWidget {
  final app_order.OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      backgroundColor: kBg, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: kBlack), onPressed: () => context.pop()),
      title: const Text('ORDER DETAIL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack)),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Artwork header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (order.artworkMediaUrl != null) ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(order.artworkMediaUrl!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
            if (order.artworkMediaUrl != null) const SizedBox(height: 16),
            Text(order.artworkTitle ?? 'Artwork', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textOnLight)),
            const SizedBox(height: 4),
            Text('by ${order.sellerName ?? 'Artist'}', style: const TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary)),
          ]),
        ),
        const SizedBox(height: 14),

        // Order info
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
          child: Column(children: [
            _Row('Order ID', order.id.substring(0, 12) + '...'),
            const SizedBox(height: 10),
            _Row('Date', (order.createdAt?.toIso8601String() ?? '').split('T').first),
            const SizedBox(height: 10),
            _Row('Amount', '₹${(order.amount ?? 0).toStringAsFixed(0)}'),
            const SizedBox(height: 10),
            _Row('Status', order.status.toUpperCase()),
            if (order.paymentMethod != null) ...[
              const SizedBox(height: 10),
              _Row('Payment', order.paymentMethod!),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // Certificate CTA
        if (order.hasCertificate) Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: kOrange.withOpacity(0.3))),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.verified, size: 22, color: kWhite),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Certificate of Authenticity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kBlack)),
              const Text('Issued for this artwork', style: TextStyle(fontSize: 12, color: kGrey)),
            ])),
            ElevatedButton(
              onPressed: () => context.push('/certificates'),
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: kWhite, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
        ),

        // Note: current order model doesn't expose tx hash; certificate screen
        // and explorer link is shown on purchase confirmation instead.
        if (order.purchaseMode != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BLOCKCHAIN PROOF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textOnLight, letterSpacing: 1)),
              const SizedBox(height: 12),
              Text('Mode: ${order.isDemoPurchase ? 'Demo' : 'Live'}', style: const TextStyle(fontSize: 12, color: kOrange, fontFamily: 'monospace')),
            ]),
          ),
        ],
        const SizedBox(height: 32),
      ]),
    ),
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textOnLightSecondary)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textOnLight)),
    ],
  );
}
