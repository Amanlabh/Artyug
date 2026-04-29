import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../features/dashboard/collector/collector_dashboard_screen.dart';
import '../../features/dashboard/creator/creator_dashboard_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/onboarding_guide.dart';
import '../../widgets/artyug_search_bar.dart';
import '../../widgets/dashboard_background.dart';
import '../../widgets/profile_sheet.dart';
import '../../widgets/shop_selector_sheet.dart';
import '../explore/explore_screen.dart';
import '../profile/profile_screen.dart';

const _primaryNavItems = [
  _NavItem(icon: Icons.home_rounded, label: 'Home', tabIndex: 0),
  _NavItem(icon: Icons.explore_rounded, label: 'Explore', tabIndex: 1),
  _NavItem(
      icon: Icons.dashboard_customize_rounded, label: 'Dashboard', tabIndex: 3),
  _NavItem(icon: Icons.receipt_long_rounded, label: 'Orders', route: '/orders'),
  _NavItem(icon: Icons.person_rounded, label: 'Profile', tabIndex: 2),
];

const _studioNavItems = [
  _NavItem(
      icon: Icons.add_photo_alternate_rounded,
      label: 'Upload Artwork',
      route: '/upload'),
  _NavItem(
      icon: Icons.store_rounded,
      label: 'Studios',
      route: '/shop'),
  _NavItem(
      icon: Icons.gavel_rounded,
      label: 'Auctions',
      route: '/auctions'),
  _NavItem(
      icon: Icons.workspace_premium_rounded,
      label: 'Certificates',
      route: '/certificates'),
  _NavItem(
      icon: Icons.dashboard_customize_rounded,
      label: 'Creator Dashboard',
      route: '/creator-dashboard'),
  _NavItem(
      icon: Icons.collections_bookmark_rounded,
      label: 'Collector Dashboard',
      route: '/collector-dashboard'),
  _NavItem(icon: Icons.groups_rounded, label: 'Guilds', route: '/guild'),
  _NavItem(icon: Icons.event_rounded, label: 'Events', route: '/events'),
];

const _trustNavItems = [
  _NavItem(
      icon: Icons.verified_user_rounded,
      label: 'Authenticity',
      route: '/authenticity-center'),
  _NavItem(
      icon: Icons.smart_toy_rounded,
      label: 'AI Assistant',
      route: '/ai-assistant'),
  _NavItem(
      icon: Icons.qr_code_scanner_rounded,
      label: 'Verify QR',
      route: '/verify'),
  _NavItem(icon: Icons.nfc_rounded, label: 'NFC Scan', route: '/nfc-scan'),
];

class _NavItem {
  final IconData icon;
  final String label;
  final int? tabIndex;
  final String? route;

  const _NavItem({
    required this.icon,
    required this.label,
    this.tabIndex,
    this.route,
  });
}

enum _DashboardView { creator, collector }

class MainTabsScreen extends StatefulWidget {
  final int? initialTabIndex;
  final String? initialDashboard;

  const MainTabsScreen({
    super.key,
    this.initialTabIndex,
    this.initialDashboard,
  });

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  final GlobalKey<ScaffoldState> _mobileShellKey = GlobalKey<ScaffoldState>();
  _DashboardView _dashboardView = _DashboardView.creator;
  bool _isDesktopSidebarOpen = true;

  List<Widget> get _screens => [
        const FeedScreen(useShellTopBar: true),
        const ExploreScreen(embedInShell: true),
        const ProfileScreen(),
        _dashboardShell(),
      ];

  @override
  void initState() {
    super.initState();
    _applyRoutePreset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setInitialTabIfProvided();
      OnboardingGuide.showIfNeeded(context);
    });
  }

  @override
  void didUpdateWidget(covariant MainTabsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDashboard != widget.initialDashboard) {
      _applyRoutePreset();
    }
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _setInitialTabIfProvided();
    }
  }

  void _applyRoutePreset() {
    final raw = widget.initialDashboard?.trim().toLowerCase();
    if (raw == 'collector') {
      _dashboardView = _DashboardView.collector;
      return;
    }
    if (raw == 'creator') {
      _dashboardView = _DashboardView.creator;
    }
  }

  void _setInitialTabIfProvided() {
    final i = widget.initialTabIndex;
    if (i == null || !mounted) return;
    context.read<MainTabProvider>().setIndex(i);
  }

  void _openNavItem(_NavItem item) {
    if (item.tabIndex != null) {
      context.read<MainTabProvider>().setIndex(item.tabIndex!);
      return;
    }
    if (item.route != null) {
      if (item.route == '/creator-dashboard') {
        setState(() => _dashboardView = _DashboardView.creator);
        context.go('/main?tab=3&dashboard=creator');
        return;
      }
      if (item.route == '/collector-dashboard') {
        setState(() => _dashboardView = _DashboardView.collector);
        context.go('/main?tab=3&dashboard=collector');
        return;
      }
      context.push(item.route!);
    }
  }

  Future<void> _handleUpload(BuildContext context) async {
    // ShopSelectorSheet returns:
    //   Map<String,dynamic> → user chose a specific studio (backed by shop table)
    //   null               → user chose "Portfolio Only" (confirmed via button)
    //                        OR user swiped to dismiss (we navigate anyway)
    final result = await ShopSelectorSheet.show(context);

    if (!mounted) return;

    // User chose "Create New Studio" in selector
    if (result?['__action'] == 'create_studio') {
      final created = await context.push<Map<String, dynamic>>('/create-gallery');
      if (!mounted) return;
      if (created != null && (created['id']?.toString().isNotEmpty ?? false)) {
        final shopId = Uri.encodeComponent(created['id']?.toString() ?? '');
        final shopName = Uri.encodeComponent(created['name']?.toString() ?? '');
        context.push('/upload?shopId=$shopId&shopName=$shopName');
      } else {
        // If studio creation was cancelled, return to upload without studio
        context.push('/upload');
      }
      return;
    }

    if (result != null) {
      final shopId = Uri.encodeComponent(result['id']?.toString() ?? '');
      final shopName = Uri.encodeComponent(result['name']?.toString() ?? '');
      context.push('/upload?shopId=$shopId&shopName=$shopName');
    } else {
      // Portfolio only or dismissed — open upload with no shop attached
      context.push('/upload');
    }
  }


  bool _isItemActive(_NavItem item, int currentIndex) {
    if (item.tabIndex != null) {
      return currentIndex == item.tabIndex;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<MainTabProvider>().index;
    final isWide = MediaQuery.of(context).size.width >= 980;
    return isWide
        ? _buildDesktopShell(currentIndex)
        : _buildMobileShell(currentIndex);
  }

  Widget _buildDesktopShell(int currentIndex) {
    final modeProvider = context.watch<AppModeProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      body: SafeArea(
        child: Row(
          children: [
            if (_isDesktopSidebarOpen) ...[
              _PremiumSidebar(
                openItem: _openNavItem,
                isActive: (item) => _isItemActive(item, currentIndex),
                scrollable: false,
                onClose: () => setState(() => _isDesktopSidebarOpen = false),
              ),
              const VerticalDivider(width: 1, thickness: 1),
            ],
            Expanded(
              child: Column(
                children: [
                  _ShellTopBar(
                    modeProvider: modeProvider,
                    authProvider: auth,
                    onModeTap: () => _showModeToggle(context, modeProvider),
                    showSidebarToggle: !_isDesktopSidebarOpen,
                    onSidebarToggle: () =>
                        setState(() => _isDesktopSidebarOpen = true),
                  ),
                  Expanded(
                    child: Container(
                      color: AppColors.canvasOf(context),
                      child: IndexedStack(index: currentIndex, children: _screens),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNavItemFromDrawer(_NavItem item) {
    _mobileShellKey.currentState?.closeDrawer();
    _openNavItem(item);
  }

  Widget _buildMobileShell(int currentIndex) {
    final modeProvider = context.watch<AppModeProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      key: _mobileShellKey,
      backgroundColor: cs.surface,
      drawer: Drawer(
        backgroundColor: AppColors.canvasSoftOf(context),
        surfaceTintColor: Colors.transparent,
        width: 304,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: SafeArea(
          child: _PremiumSidebar(
            openItem: _openNavItemFromDrawer,
            isActive: (item) => _isItemActive(item, currentIndex),
            scrollable: true,
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: cs.surface,
        toolbarHeight: 68,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 52,
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: cs.onSurface),
          onPressed: () => _mobileShellKey.currentState?.openDrawer(),
        ),
        titleSpacing: 0,
        title: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => _showModeToggle(context, modeProvider),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    modeProvider.isDemoMode
                        ? Icons.bolt_rounded
                        : Icons.verified_rounded,
                    size: 15,
                    color: modeProvider.isDemoMode
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    modeProvider.isDemoMode ? 'Demo mode' : 'Live mode',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Messages',
            icon: Icon(Icons.chat_bubble_outline_rounded, color: cs.onSurface),
            onPressed: () => context.push('/messages'),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Icon(Icons.notifications_none_rounded, color: cs.onSurface),
            onPressed: () => context.push('/notifications'),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10, left: 2),
            child: ProfileAvatarButton(radius: 17),
          ),
        ],
      ),
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: _BottomNavWithUpload(
        currentIndex: currentIndex,
        onTap: (i) => context.read<MainTabProvider>().setIndex(i),
        onUpload: () => _handleUpload(context),
      ),
    );
  }

  Widget _dashboardShell() {
    return DashboardBackground(
      child: Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _DashboardSwitch(
                  view: _dashboardView,
                  onChanged: (next) => setState(() => _dashboardView = next),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderOf(context)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _dashboardView == _DashboardView.creator
                  ? const CreatorDashboardScreen(
                      key: ValueKey<String>('creator-dashboard'),
                    )
                  : const CollectorDashboardScreen(
                      key: ValueKey<String>('collector-dashboard'),
                    ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _DashboardSwitch extends StatelessWidget {
  final _DashboardView view;
  final ValueChanged<_DashboardView> onChanged;

  const _DashboardSwitch({
    required this.view,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(_DashboardView v, String label, IconData icon) {
      final selected = view == v;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(v),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.accentGradientOf(context) : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoftOf(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          chip(_DashboardView.creator, 'Creator', Icons.palette_outlined),
          chip(
            _DashboardView.collector,
            'Collector',
            Icons.collections_bookmark_outlined,
          ),
        ],
      ),
    );
  }
}

class _PremiumSidebar extends StatelessWidget {
  final void Function(_NavItem item) openItem;
  final bool Function(_NavItem item) isActive;
  /// When true (mobile drawer), content scrolls and skips [Spacer] layout.
  final bool scrollable;
  final VoidCallback? onClose;

  const _PremiumSidebar({
    required this.openItem,
    required this.isActive,
    this.scrollable = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final headerAndNav = <Widget>[
      const SizedBox(height: 24),
      // ── Wordmark logo — matches landing page exactly ────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!scrollable && onClose != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onClose,
                  tooltip: 'Close sidebar',
                  icon: Icon(
                    Icons.menu_open_rounded,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'ARTYUG',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.22, // -0.01em of 22px
                      height: 1,
                    ),
                  ),
                  const TextSpan(
                    text: '.',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE8470A),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Art Marketplace & Studio',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiaryOf(context),
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _SidebarSection(
        title: 'MARKETPLACE',
        children: _primaryNavItems,
        openItem: openItem,
        isActive: isActive,
      ),
      _SidebarSection(
        title: 'STUDIO',
        children: _studioNavItems,
        openItem: openItem,
        isActive: isActive,
      ),
      _SidebarSection(
        title: 'TRUST',
        children: _trustNavItems,
        openItem: openItem,
        isActive: isActive,
      ),
    ];

    final accountPanel = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderStrongOf(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage: auth.user?.userMetadata?['avatar_url'] != null
                  ? NetworkImage(auth.user!.userMetadata!['avatar_url'])
                  : null,
              child: auth.user?.userMetadata?['avatar_url'] == null
                  ? const Icon(Icons.person_rounded, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.user?.userMetadata?['full_name'] ??
                        'Artyug Collector',
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Account & preferences',
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                final router = GoRouter.of(context);
                if (scrollable) Navigator.of(context).pop();
                router.push('/settings');
              },
              icon: Icon(Icons.settings_rounded,
                  color: AppColors.textSecondaryOf(context), size: 20),
            ),
          ],
        ),
      ),
    );

    final body = SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...headerAndNav,
          const SizedBox(height: 12),
          accountPanel,
        ],
      ),
    );

    if (scrollable) {
      return body;
    }

    return Container(
      width: 286,
      decoration: BoxDecoration(
        color: AppColors.canvasSoftOf(context),
        border: Border(
          right: BorderSide(
            color: AppColors.borderStrongOf(context).withValues(alpha: 0.9),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowOf(context, alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: body,
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final String title;
  final List<_NavItem> children;
  final void Function(_NavItem item) openItem;
  final bool Function(_NavItem item) isActive;

  const _SidebarSection({
    required this.title,
    required this.children,
    required this.openItem,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textTertiaryOf(context),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...children.map(
            (item) => _SidebarItem(
              item: item,
              active: isActive(item),
              onTap: () => openItem(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _SidebarItem(
      {required this.item, required this.active, required this.onTap});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active
                ? AppColors.primary.withValues(alpha: 0.16)
                : (_hovered
                    ? AppColors.surfaceOf(context).withValues(alpha: 0.75)
                    : Colors.transparent),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 18,
                color: active ? AppColors.primary : AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: active
                        ? AppColors.textPrimaryOf(context)
                        : AppColors.textSecondaryOf(context),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
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

class _ShellTopBar extends StatelessWidget {
  final AppModeProvider modeProvider;
  final AuthProvider authProvider;
  final VoidCallback onModeTap;
  final bool showSidebarToggle;
  final VoidCallback? onSidebarToggle;

  const _ShellTopBar({
    required this.modeProvider,
    required this.authProvider,
    required this.onModeTap,
    this.showSidebarToggle = false,
    this.onSidebarToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      decoration: BoxDecoration(
        color: AppColors.canvasOf(context),
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          if (showSidebarToggle && onSidebarToggle != null) ...[
            _IconShellButton(
              icon: Icons.menu_rounded,
              onTap: onSidebarToggle!,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ArtyugSearchRouteTrigger(
              height: 46,
              hintText: 'Search artists, creators, artworks…',
              onTap: () =>
                  context.read<MainTabProvider>().setIndex(1), // Explore (in-shell search)
            ),
          ),
          const SizedBox(width: 12),
          _IconShellButton(
              icon: Icons.notifications_none_rounded,
              onTap: () => context.push('/notifications')),
          const SizedBox(width: 8),
          _IconShellButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => context.push('/messages')),
          const SizedBox(width: 8),
          _ModePill(isDemo: modeProvider.isDemoMode, onTap: onModeTap),
          const SizedBox(width: 8),
          // Dark / light theme toggle
          Consumer<ThemeProvider>(
            builder: (_, tp, __) => InkWell(
              onTap: () => tp.toggleTheme(!tp.isDarkMode),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Icon(
                  tp.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: AppColors.textSecondaryOf(context),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Profile avatar → opens Zoom-style profile sheet
          const ProfileAvatarButton(radius: 18),
        ],
      ),
    );
  }
}

class _IconShellButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconShellButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Icon(icon, color: AppColors.textSecondaryOf(context), size: 21),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final bool isDemo;
  final VoidCallback onTap;

  const _ModePill({required this.isDemo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isDemo ? AppColors.warning : AppColors.success;
    final label = isDemo ? 'DEMO' : 'LIVE';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoftOf(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _LiteProPill extends StatelessWidget {
  final bool isProMode;
  final ValueChanged<bool> onChanged;

  const _LiteProPill({
    required this.isProMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoftOf(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment:
                  isProMode ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradientOf(context),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                _LiteProLabel(
                  label: 'Lite',
                  active: !isProMode,
                  onTap: () => onChanged(false),
                ),
                _LiteProLabel(
                  label: 'Pro',
                  active: isProMode,
                  onTap: () => onChanged(true),
                ),
              ],
            ),
          ],
        ),
      );
  }
}

class _LiteProLabel extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LiteProLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.onPrimary : AppColors.textSecondaryOf(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

void _showModeToggle(BuildContext context, AppModeProvider provider) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceOf(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ModeToggleSheet(provider: provider),
  );
}

class _ModeToggleSheet extends StatelessWidget {
  final AppModeProvider provider;

  const _ModeToggleSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Switch App Mode',
            style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontSize: 18,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Demo mode uses sample data. Live mode uses your real Artyug account and transactions.',
            style: TextStyle(
                color: AppColors.textSecondaryOf(context), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _ModeOption(
            active: provider.isDemoMode,
            icon: Icons.science_rounded,
            title: 'Demo Mode',
            subtitle: 'Safe exploration with demo marketplace data',
            color: AppColors.warning,
            onTap: () {
              provider.setMode(AppMode.demo);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          _ModeOption(
            active: provider.isLiveMode,
            icon: Icons.flash_on_rounded,
            title: 'Live Mode',
            subtitle: 'Real feed, real wallets, real authenticity workflows',
            color: AppColors.success,
            onTap: () {
              provider.setMode(AppMode.live);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeOption({
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              active ? color.withValues(alpha: 0.14) : AppColors.surfaceMutedOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context), fontSize: 12)),
                ],
              ),
            ),
            if (active) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Custom bottom nav bar with centered Upload button ─────────────────────────

class _BottomNavWithUpload extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onUpload;

  const _BottomNavWithUpload({
    required this.currentIndex,
    required this.onTap,
    required this.onUpload,
  });

  // Tab indices skip the phantom centre slot
  // Layout: 0=Home  1=Explore  [Upload]  2=Profile  3=Dashboard
  static const _icons = [
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.person_rounded,
    Icons.dashboard_customize_rounded,
  ];
  static const _labels = ['Home', 'Explore', 'Profile', 'Dashboard'];

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.surfaceElevatedOf(context);
    final dividerColor = AppColors.borderOf(context);

    return SafeArea(
      top: false,
      child: Container(
        height: 74,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: dividerColor),
          boxShadow: AppColors.cardShadows(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left two: Home + Explore
            for (int i = 0; i < 2; i++) _BottomNavItem(
              icon: _icons[i],
              label: _labels[i],
              selected: currentIndex == i,
              onTap: () => onTap(i),
            ),

            // Centre — Upload pill button
            Center(
              child: GestureDetector(
                onTap: onUpload,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_photo_alternate_rounded,
                          color: AppColors.onPrimary, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Upload',
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Right two: Profile + Dashboard
            for (int i = 2; i < 4; i++) _BottomNavItem(
              icon: _icons[i],
              label: _labels[i],
              selected: currentIndex == i,
              onTap: () => onTap(i),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondaryOf(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
