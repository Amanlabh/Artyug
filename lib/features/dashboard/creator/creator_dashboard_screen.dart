import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/order.dart';
import '../../../models/painting.dart';
import '../../../models/profile.dart';
import '../../../providers/dashboard_provider.dart';

/// Creator studio — dense KPIs, 7-day revenue from real orders, chart + sales split on wide layouts.
class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({super.key});

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  static const double _wideBreakpoint = 880;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<DashboardProvider>(
        builder: (context, dash, _) {
          if (dash.loading && dash.stats == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (dash.error != null && dash.stats == null) {
            return Center(
              child: Text(
                dash.error!,
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }
          return _buildDashboard(dash);
        },
      ),
    );
  }

  Widget _buildDashboard(DashboardProvider dash) {
    final s = dash.stats!;
    final profile = s.profile;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: () => dash.loadDashboard(),
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _StudioHeader(profile: profile)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _KpiStrip(
                revenueFormatted: currency.format(s.totalRevenue),
                sales: s.totalSales,
                artworks: s.totalArtworks,
                followers: s.totalFollowers,
                likes: s.totalLikes,
                wideBreakpoint: _wideBreakpoint,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= _wideBreakpoint;
                  final buckets = _last7DaysRevenue(s.completedSales);
                  final chart = _RevenueChartCard(buckets: buckets);
                  final salesPanel = _RecentSalesPanel(
                    orders: s.recentSales,
                    currency: currency,
                  );
                  if (wide) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: chart),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: salesPanel),
                        ],
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      chart,
                      const SizedBox(height: 16),
                      salesPanel,
                    ],
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Shortcuts'),
                  const SizedBox(height: 12),
                  _QuickActionsRow(onUpload: () => context.push('/upload')),
                  const SizedBox(height: 24),
                  const _SectionTitle('Authenticity'),
                  const SizedBox(height: 12),
                  _AuthenticityCard(
                    certificatesIssued: s.certificatesIssued,
                    verificationRate: s.verificationRate,
                    onViewCerts: () => context.push('/certificates'),
                    onVerify: () => context.push('/authenticity-center'),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('My artworks'),
                  const SizedBox(height: 12),
                  if (s.myArtworks.isEmpty)
                    const _EmptyState(
                      icon: Icons.palette_outlined,
                      message: 'No artworks yet',
                      sub: 'Upload your first piece',
                    )
                  else
                    _ArtworkStrip(artworks: s.myArtworks),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<double> _last7DaysRevenue(List<OrderModel> completedSales) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));
  final buckets = List<double>.filled(7, 0);
  for (final o in completedSales) {
    final amt = o.amount;
    final created = o.createdAt;
    if (amt == null || created == null) continue;
    final day = DateTime(created.year, created.month, created.day);
    final idx = day.difference(start).inDays;
    if (idx >= 0 && idx < 7) {
      buckets[idx] += amt;
    }
  }
  return buckets;
}

class _StudioHeader extends StatelessWidget {
  final ProfileModel? profile;

  const _StudioHeader({this.profile});

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: AppColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                  if (!canPop) const SizedBox(width: 8),
                  const Text(
                    'ARTYUG',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Artist Studio',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: AppColors.textSecondary),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.18),
                    backgroundImage: profile?.profilePictureUrl != null
                        ? NetworkImage(profile!.profilePictureUrl!)
                        : null,
                    child: profile?.profilePictureUrl == null
                        ? Text(
                            profile?.initials ?? '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile?.displayNameOrUsername ?? 'Creator',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile?.isVerified == true) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sales, certificates, and catalogue',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final String revenueFormatted;
  final int sales;
  final int artworks;
  final int followers;
  final int likes;
  final double wideBreakpoint;

  const _KpiStrip({
    required this.revenueFormatted,
    required this.sales,
    required this.artworks,
    required this.followers,
    required this.likes,
    required this.wideBreakpoint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= wideBreakpoint;
        final cards = [
          _KpiTile(
            label: 'Total revenue',
            value: revenueFormatted,
            icon: Icons.payments_outlined,
            accent: true,
          ),
          _KpiTile(
            label: 'Completed sales',
            value: '$sales',
            icon: Icons.shopping_bag_outlined,
          ),
          _KpiTile(
            label: 'Artworks',
            value: '$artworks',
            icon: Icons.palette_outlined,
          ),
          _KpiTile(
            label: 'Reach',
            value: '${_formatInt(followers)} · ${_formatInt(likes)}',
            sublabel: 'followers · likes',
            icon: Icons.insights_outlined,
          ),
        ];
        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        return SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: math.min(168.0, c.maxWidth * 0.42),
              child: cards[i],
            ),
          ),
        );
      },
    );
  }

  static String _formatInt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool accent;
  final String? sublabel;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = false,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final border = accent
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.border;
    final bg = accent ? AppColors.primarySoft : AppColors.surfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: accent ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent ? AppColors.primary : AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sublabel != null)
            Text(
              sublabel!,
              style: TextStyle(
                color: AppColors.textTertiary.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _RevenueChartCard extends StatelessWidget {
  final List<double> buckets;

  const _RevenueChartCard({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final labels = List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      final short = DateFormat('EEE').format(d);
      return short.length >= 2 ? short.substring(0, 2) : short;
    });
    final peak = buckets.fold<double>(0, (a, b) => math.max(a, b));
    final maxY = math.max(1.0, peak * 1.15);
    final hasData = buckets.any((v) => v > 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Last 7 days',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                hasData ? 'Revenue by day' : 'No sales in range',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 5 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxY > 5 ? maxY / 4 : 1,
                      getTitlesWidget: (v, m) => Text(
                        v >= 1000
                            ? '${(v / 1000).toStringAsFixed(0)}k'
                            : v.toInt().toString(),
                        style: TextStyle(
                          color: AppColors.textTertiary.withValues(alpha: 0.85),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        final isToday = i == 6;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final y = buckets[i];
                  final isToday = i == 6;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: y,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: y <= 0
                            ? Colors.transparent
                            : (isToday
                                ? AppColors.primary
                                : AppColors.surfaceHigh),
                        gradient: y <= 0 || isToday
                            ? null
                            : LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.surfaceHigh,
                                  AppColors.textTertiary
                                      .withValues(alpha: 0.35),
                                ],
                              ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSalesPanel extends StatelessWidget {
  final List<OrderModel> orders;
  final NumberFormat currency;

  const _RecentSalesPanel({
    required this.orders,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent sales',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No completed sales yet',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _OrderRow(order: orders[i], currency: currency),
            ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  final NumberFormat currency;

  const _OrderRow({required this.order, required this.currency});

  @override
  Widget build(BuildContext context) {
    final amount = order.amount;
    final amountStr = amount != null
        ? currency.format(amount)
        : order.displayAmount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.artworkTitle ?? 'Artwork',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  order.buyerName ?? 'Buyer',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            amountStr,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onUpload;

  const _QuickActionsRow({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickChip(
        icon: Icons.add_photo_alternate_outlined,
        label: 'Upload',
        onTap: onUpload,
      ),
      _QuickChip(
        icon: Icons.workspace_premium_outlined,
        label: 'Certificates',
        onTap: () => context.push('/certificates'),
      ),
      _QuickChip(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Verify QR',
        onTap: () => context.push('/verify'),
      ),
      _QuickChip(
        icon: Icons.receipt_long_outlined,
        label: 'Orders',
        onTap: () => context.push('/orders'),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            actions[i],
          ],
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkStrip extends StatelessWidget {
  final List<PaintingModel> artworks;

  const _ArtworkStrip({required this.artworks});

  @override
  Widget build(BuildContext context) {
    final list = artworks.take(12).toList();
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final art = list[i];
          return GestureDetector(
            onTap: () => ctx.push('/artwork/${art.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Image.network(
                    art.imageUrl,
                    width: 132,
                    height: 172,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                      decoration: const BoxDecoration(
                        gradient: AppColors.cardOverlay,
                      ),
                      child: Text(
                        art.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (art.isAvailable)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'For sale',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 36),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthenticityCard extends StatelessWidget {
  final int certificatesIssued;
  final double verificationRate;
  final VoidCallback onViewCerts;
  final VoidCallback onVerify;

  const _AuthenticityCard({
    required this.certificatesIssued,
    required this.verificationRate,
    required this.onViewCerts,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (verificationRate * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Certificate vault',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$certificatesIssued certificate${certificatesIssued == 1 ? '' : 's'} linked',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Verification coverage',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: verificationRate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceHigh,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewCerts,
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text('View certs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Verify QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
