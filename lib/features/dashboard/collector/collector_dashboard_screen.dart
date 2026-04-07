import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/supabase_media_url.dart';
import '../../../models/certificate.dart';
import '../../../models/order.dart';
import '../../../models/profile.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../services/demo_wallet_service.dart';

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  State<CollectorDashboardScreen> createState() =>
      _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
          return _buildContent(context, dash);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardProvider dash) {
    final s = dash.stats!;
    final profile = s.profile;
    final border = AppColors.borderOf(context);
    final isDemo = context.watch<AppModeProvider>().isDemoMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (context.canPop())
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.pop(),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimaryOf(context),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceOf(context).withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ),
        _PortfolioHero(
          profile: profile,
          totalSpent: s.totalSpent,
          owned: s.ownedArtworks,
          certificates: s.certificatesCount,
          showDemoWallet: isDemo,
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(
              bottom: BorderSide(color: border),
            ),
          ),
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryOf(context),
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Items'),
              Tab(text: 'Vault'),
              Tab(text: 'Saved'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PurchasesTab(purchases: s.myPurchases),
              _VaultTab(certificates: s.myCertificates),
              const _SavedTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Portfolio header (Magic Eden–style hierarchy) ─────────────────────────

class _PortfolioHero extends StatelessWidget {
  final ProfileModel? profile;
  final double totalSpent;
  final int owned;
  final int certificates;
  final bool showDemoWallet;

  const _PortfolioHero({
    required this.profile,
    required this.totalSpent,
    required this.owned,
    required this.certificates,
    this.showDemoWallet = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayNameOrUsername ?? 'Collector';
    final initials = profile?.initials ?? '?';
    final avatarUrl =
        SupabaseMediaUrl.resolve(profile?.profilePictureUrl);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF12081F),
            Color(0xFF0E1424),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          context.canPop() ? 4 : 16,
          20,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.borderStrong.withValues(alpha: 0.85),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Collector portfolio',
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStatChip(
                              label: 'Total spent',
                              value: '₹${totalSpent.toStringAsFixed(0)}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HeroStatChip(
                              label: 'Owned',
                              value: '$owned',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HeroStatChip(
                              label: 'Certs',
                              value: '$certificates',
                            ),
                          ),
                        ],
                      ),
                      if (showDemoWallet) ...[
                        const SizedBox(height: 10),
                        FutureBuilder<int>(
                          future: DemoWalletService.getBalanceInr(),
                          builder: (context, snap) {
                            final bal = snap.data ?? DemoWalletService.initialBalanceInr;
                            final pct = (bal / DemoWalletService.initialBalanceInr)
                                .clamp(0.0, 1.0);
                            return Container(
                              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Demo wallet',
                                        style: TextStyle(
                                          color: AppColors.textSecondaryOf(context),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () async {
                                          await DemoWalletService.reset();
                                          if (context.mounted) {
                                            // Rebuild to show updated balance.
                                            (context as Element).markNeedsBuild();
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.warning,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text(
                                          'Reset',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        '₹$bal',
                                        style: const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'left to invest',
                                        style: TextStyle(
                                          color: AppColors.textTertiaryOf(context),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 6,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.08),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textTertiaryOf(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Purchases / Items tab ─────────────────────────────────────────────────

enum _PurchaseSort { recent, priceHigh, priceLow, title }

class _PurchasesTab extends StatefulWidget {
  final List<OrderModel> purchases;

  const _PurchasesTab({required this.purchases});

  @override
  State<_PurchasesTab> createState() => _PurchasesTabState();
}

class _PurchasesTabState extends State<_PurchasesTab> {
  final _searchCtrl = TextEditingController();
  bool _gridView = true;
  _PurchaseSort _sort = _PurchaseSort.recent;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<OrderModel> get _filteredSorted {
    var list = List<OrderModel>.from(widget.purchases);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) {
        final t = (o.artworkTitle ?? '').toLowerCase();
        final s = (o.sellerName ?? '').toLowerCase();
        return t.contains(q) || s.contains(q);
      }).toList();
    }
    switch (_sort) {
      case _PurchaseSort.recent:
        list.sort((a, b) {
          final da = a.createdAt ?? DateTime(1970);
          final db = b.createdAt ?? DateTime(1970);
          return db.compareTo(da);
        });
        break;
      case _PurchaseSort.priceHigh:
        list.sort((a, b) => (b.amount ?? 0).compareTo(a.amount ?? 0));
        break;
      case _PurchaseSort.priceLow:
        list.sort((a, b) => (a.amount ?? 0).compareTo(b.amount ?? 0));
        break;
      case _PurchaseSort.title:
        list.sort((a, b) => (a.artworkTitle ?? '')
            .toLowerCase()
            .compareTo((b.artworkTitle ?? '').toLowerCase()));
        break;
    }
    return list;
  }

  String get _sortLabel => switch (_sort) {
        _PurchaseSort.recent => 'Recent',
        _PurchaseSort.priceHigh => 'Price: high → low',
        _PurchaseSort.priceLow => 'Price: low → high',
        _PurchaseSort.title => 'Title A–Z',
      };

  @override
  Widget build(BuildContext context) {
    if (widget.purchases.isEmpty) {
      return _EmptyPortfolio(
        icon: Icons.inventory_2_outlined,
        title: 'No items yet',
        subtitle: 'Works you buy will show up here — browse the marketplace.',
        actionLabel: 'Browse artworks',
        onAction: () => context.push('/explore'),
      );
    }

    final items = _filteredSorted;
    final border = AppColors.borderOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              _ViewToggle(
                grid: _gridView,
                onChanged: (g) => setState(() => _gridView = g),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search items',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiaryOf(context),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.textTertiaryOf(context),
                      size: 22,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceOf(context),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_PurchaseSort>(
                tooltip: 'Sort',
                onSelected: (v) => setState(() => _sort = v),
                color: AppColors.surfaceOf(context),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _PurchaseSort.recent,
                    child: Text(
                      'Recent',
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    ),
                  ),
                  PopupMenuItem(
                    value: _PurchaseSort.priceHigh,
                    child: Text(
                      'Price: high → low',
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    ),
                  ),
                  PopupMenuItem(
                    value: _PurchaseSort.priceLow,
                    child: Text(
                      'Price: low → high',
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    ),
                  ),
                  PopupMenuItem(
                    value: _PurchaseSort.title,
                    child: Text(
                      'Title A–Z',
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sort_rounded,
                        size: 18,
                        color: AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 96),
                        child: Text(
                          _sortLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.textTertiaryOf(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No matches for your search',
                style: TextStyle(color: AppColors.textSecondaryOf(context)),
              ),
            ),
          )
        else
          Expanded(
            child: _gridView
                ? _PurchasesGrid(orders: items)
                : _PurchasesList(orders: items),
          ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool grid;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.grid, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleIcon(
            icon: Icons.grid_view_rounded,
            selected: grid,
            onTap: () => onChanged(true),
          ),
          _ToggleIcon(
            icon: Icons.view_list_rounded,
            selected: !grid,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: selected
                ? AppColors.primary
                : AppColors.textTertiaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _PurchasesGrid extends StatelessWidget {
  final List<OrderModel> orders;

  const _PurchasesGrid({required this.orders});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final count = w >= 1200
            ? 5
            : w >= 900
                ? 4
                : w >= 600
                    ? 3
                    : 2;
        const spacing = 12.0;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 0.68,
          ),
          itemCount: orders.length,
          itemBuilder: (context, i) => _PurchaseCard(order: orders[i]),
        );
      },
    );
  }
}

class _PurchasesList extends StatelessWidget {
  final List<OrderModel> orders;

  const _PurchasesList({required this.orders});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _PurchaseListRow(order: orders[i]),
    );
  }
}

/// Marketplace-style card: image-first, metadata below.
class _PurchaseCard extends StatelessWidget {
  final OrderModel order;

  const _PurchaseCard({required this.order});

  void _onTap(BuildContext context) {
    final id = order.artworkId;
    if (id != null && id.isNotEmpty) {
      context.push('/artwork/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderOf(context);
    final imageUrl = SupabaseMediaUrl.resolve(order.artworkMediaUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: order.isDemoPurchase
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : border,
            ),
            boxShadow: AppColors.cardShadows(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: AppColors.surfaceMutedOf(context),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.surfaceMutedOf(context),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.textTertiaryOf(context),
                                  size: 36,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.surfaceMutedOf(context),
                              child: Icon(
                                Icons.palette_outlined,
                                color: AppColors.textTertiaryOf(context),
                                size: 36,
                              ),
                            ),
                    ),
                    if (order.isDemoPurchase)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'DEMO',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    if (order.hasCertificate)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: AppColors.success,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Certified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.artworkTitle ?? 'Artwork',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.sellerName ?? 'Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textTertiaryOf(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            order.displayAmount,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (order.artworkId != null &&
                              order.artworkId!.isNotEmpty)
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.textTertiaryOf(context),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseListRow extends StatelessWidget {
  final OrderModel order;

  const _PurchaseListRow({required this.order});

  void _onTap(BuildContext context) {
    final id = order.artworkId;
    if (id != null && id.isNotEmpty) {
      context.push('/artwork/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderOf(context);
    final imageUrl = SupabaseMediaUrl.resolve(order.artworkMediaUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: order.isDemoPurchase
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : border,
            ),
            boxShadow: AppColors.cardShadows(context),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.surfaceMutedOf(context),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surfaceMutedOf(context),
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textTertiaryOf(context),
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceMutedOf(context),
                          child: Icon(
                            Icons.palette_outlined,
                            color: AppColors.textTertiaryOf(context),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.artworkTitle ?? 'Artwork',
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${order.sellerName ?? 'Artist'}',
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          order.displayAmount,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        if (order.hasCertificate)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: AppColors.success,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Certified',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (order.isDemoPurchase)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Text(
                              'Demo',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyPortfolio({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: AppColors.textTertiaryOf(context),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vault ─────────────────────────────────────────────────────────────────

class _VaultTab extends StatelessWidget {
  final List<CertificateModel> certificates;

  const _VaultTab({required this.certificates});

  @override
  Widget build(BuildContext context) {
    if (certificates.isEmpty) {
      return _EmptyPortfolio(
        icon: Icons.verified_user_outlined,
        title: 'Vault is empty',
        subtitle:
            'Certificates for authenticated purchases will appear here.',
        actionLabel: 'Browse artworks',
        onAction: () => context.push('/explore'),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final count = w >= 800 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: count == 1 ? 3.2 : 2.8,
          ),
          itemCount: certificates.length,
          itemBuilder: (context, i) => _CertificateTile(cert: certificates[i]),
        );
      },
    );
  }
}

class _CertificateTile extends StatelessWidget {
  final CertificateModel cert;

  const _CertificateTile({required this.cert});

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCertDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: AppColors.cardShadows(context),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: QrImageView(
                  data: cert.qrCode,
                  version: QrVersions.auto,
                  size: 52,
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cert.artworkTitle,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${cert.artistName}',
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          cert.isBlockchainAnchored ? Icons.link : Icons.shield_outlined,
                          size: 13,
                          color: cert.isBlockchainAnchored
                              ? AppColors.primary
                              : AppColors.textTertiaryOf(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cert.blockchainLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: cert.isBlockchainAnchored
                                  ? AppColors.primary
                                  : AppColors.textTertiaryOf(context),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCertDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Certificate Details',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: cert.qrCode,
                version: QrVersions.auto,
                size: 160,
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _Row('Artwork', cert.artworkTitle),
            _Row('Artist', cert.artistName),
            _Row('Type', cert.blockchainLabel),
            _Row('Hash', cert.displayTruncatedHash),
            if (cert.solanaExplorerUrl != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View on Solana Explorer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(cert.solanaExplorerUrl!);
                    final ok = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!sheetContext.mounted) return;
                    if (!ok) {
                      await Clipboard.setData(
                        ClipboardData(text: cert.solanaExplorerUrl!),
                      );
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not open browser — link copied',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy QR Code'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: cert.qrCode));
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('QR code copied')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String l;
  final String v;

  const _Row(this.l, this.v);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Flexible(
              child: Text(
                v,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

// ─── Saved ─────────────────────────────────────────────────────────────────

class _SavedTab extends StatelessWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context) {
    return _EmptyPortfolio(
      icon: Icons.bookmark_outline_rounded,
      title: 'Saved',
      subtitle: 'Like artworks on the feed to save them here later.',
      actionLabel: 'Go to home',
      onAction: () => context.go('/main'),
    );
  }
}
