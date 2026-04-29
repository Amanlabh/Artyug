import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/order.dart' as app_order;

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListState();
}

class _OrderListState extends State<OrderListScreen> {
  List<app_order.OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final data = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _orders = (data as List)
            .map(
                (m) => app_order.OrderModel.fromJson(m as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _orders = [];
        _loading = false;
      });
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/main');
    }
  }

  String _formatAmount(double? amount, String currency) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: currency == 'INR' ? '₹' : '$currency ',
      decimalDigits: 0,
    );
    return fmt.format(amount ?? 0);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Recently';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _OrdersHeader(
              title: 'My Orders',
              subtitle:
                  '${_orders.length} purchase${_orders.length == 1 ? '' : 's'}',
              onBack: _handleBack,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _orders.isEmpty
                      ? _OrdersEmptyState(onBrowse: () => context.go('/main'))
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _load,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (_, i) {
                              final order = _orders[i];
                              return _OrderCard(
                                order: order,
                                amountText: _formatAmount(
                                  order.amount,
                                  order.currency ?? 'INR',
                                ),
                                dateText: _formatDate(order.createdAt),
                                onTap: () => context.push('/order/${order.id}',
                                    extra: order),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _OrdersHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  final VoidCallback onBrowse;

  const _OrdersEmptyState({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your completed purchases will show up here with certificates and order details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onBrowse,
              child: const Text('Browse Art'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final app_order.OrderModel order;
  final String amountText;
  final String dateText;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.amountText,
    required this.dateText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OrderThumb(imageUrl: order.artworkMediaUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.artworkTitle ?? 'Artwork',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'by ${order.sellerName ?? 'Artist'}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        label: amountText,
                        textColor: AppColors.textPrimary,
                        bgColor: AppColors.surfaceVariant,
                      ),
                      _MetaPill(
                        label: order.isLivePurchase ? 'LIVE' : 'DEMO',
                        textColor: order.isLivePurchase
                            ? const Color(0xFF16A34A)
                            : AppColors.primary,
                        bgColor: order.isLivePurchase
                            ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.12),
                      ),
                      if (order.paymentMethod?.isNotEmpty == true)
                        _MetaPill(
                          label: order.paymentMethod!.toUpperCase(),
                          textColor: AppColors.textSecondary,
                          bgColor: AppColors.background,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      if (order.hasCertificate)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Certificate issued',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderThumb extends StatelessWidget {
  final String? imageUrl;

  const _OrderThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final src = imageUrl?.trim();
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: (src != null && src.isNotEmpty)
          ? Image.network(
              src,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_outlined,
                size: 28,
                color: AppColors.textTertiary,
              ),
            )
          : const Icon(
              Icons.image_outlined,
              size: 28,
              color: AppColors.textTertiary,
            ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;

  const _MetaPill({
    required this.label,
    required this.textColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: textColor,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  Color get _color => switch (status.toLowerCase()) {
        'completed' => const Color(0xFF16A34A),
        'pending' => const Color(0xFFF59E0B),
        'failed' => const Color(0xFFDC2626),
        'cancelled' => AppColors.textSecondary,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: _color,
        ),
      ),
    );
  }
}

class OrderDetailLoadingScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailLoadingScreen({super.key, required this.orderId});

  @override
  State<OrderDetailLoadingScreen> createState() =>
      _OrderDetailLoadingScreenState();
}

class _OrderDetailLoadingScreenState extends State<OrderDetailLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      if (mounted) context.go('/orders');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  final app_order.OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Recently';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _OrdersHeader(
              title: 'Order Detail',
              subtitle: _formatDate(order.createdAt),
              onBack: () => _handleBack(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    _DetailHero(order: order),
                    const SizedBox(height: 14),
                    _DetailSection(
                      child: Column(
                        children: [
                          _Row('Order ID', '${order.id.substring(0, 12)}...'),
                          const SizedBox(height: 12),
                          _Row('Status', order.statusLabel),
                          const SizedBox(height: 12),
                          _Row('Mode', order.isLivePurchase ? 'Live' : 'Demo'),
                          const SizedBox(height: 12),
                          _Row(
                            'Amount',
                            order.displayAmount.replaceAll('â‚¹', '₹'),
                          ),
                          if (order.paymentMethod?.isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            _Row('Payment', order.paymentMethod!.toUpperCase()),
                          ],
                        ],
                      ),
                    ),
                    if (order.hasCertificate) ...[
                      const SizedBox(height: 14),
                      _DetailSection(
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Certificate of Authenticity',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Issued for this artwork',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () => context.push('/certificates'),
                              child: const Text('View'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  final app_order.OrderModel order;

  const _DetailHero({required this.order});

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.artworkMediaUrl?.isNotEmpty == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                order.artworkMediaUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: AppColors.surfaceVariant,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    size: 36,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          if (order.artworkMediaUrl?.isNotEmpty == true)
            const SizedBox(height: 16),
          Text(
            order.artworkTitle ?? 'Artwork',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'by ${order.sellerName ?? 'Artist'}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final Widget child;

  const _DetailSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
