import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../features/feed/feed_screen.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/onboarding_guide.dart';
import '../../widgets/artyug_search_bar.dart';
import '../explore/explore_screen.dart';
import '../profile/profile_screen.dart';

const _primaryNavItems = [
  _NavItem(icon: Icons.home_rounded, label: 'Home', tabIndex: 0),
  _NavItem(icon: Icons.explore_rounded, label: 'Explore', tabIndex: 1),
  _NavItem(icon: Icons.receipt_long_rounded, label: 'Orders', route: '/orders'),
  _NavItem(icon: Icons.person_rounded, label: 'Profile', tabIndex: 2),
];

const _studioNavItems = [
  _NavItem(
      icon: Icons.add_photo_alternate_rounded,
      label: 'Upload Artwork',
      route: '/upload'),
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

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  final GlobalKey<ScaffoldState> _mobileShellKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _screens = [
    const FeedScreen(useShellTopBar: true),
    const ExploreScreen(embedInShell: true),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OnboardingGuide.showIfNeeded(context);
    });
  }

  void _openNavItem(_NavItem item) {
    if (item.tabIndex != null) {
      context.read<MainTabProvider>().setIndex(item.tabIndex!);
      return;
    }
    if (item.route != null) {
      context.push(item.route!);
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            _PremiumSidebar(
              openItem: _openNavItem,
              isActive: (item) => _isItemActive(item, currentIndex),
              scrollable: false,
            ),
            const VerticalDivider(width: 1, color: AppColors.borderStrong),
            Expanded(
              child: Column(
                children: [
                  _ShellTopBar(
                    modeProvider: modeProvider,
                    authProvider: auth,
                    onModeTap: () => _showModeToggle(context, modeProvider),
                  ),
                  Expanded(
                    child: Container(
                      color: AppColors.background,
                      child: IndexedStack(
                          index: currentIndex, children: _screens),
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
    final themeProvider = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      key: _mobileShellKey,
      backgroundColor: cs.surface,
      drawer: Drawer(
        backgroundColor: AppColors.sidebar,
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
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: cs.onSurface),
          tooltip: 'Open menu',
          onPressed: () => _mobileShellKey.currentState?.openDrawer(),
        ),
        title: RichText(
          text: TextSpan(children: [
            TextSpan(
              text: 'ARTYUG',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
                letterSpacing: -0.19,
              ),
            ),
            const TextSpan(
              text: '.',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE8470A),
              ),
            ),
          ]),
        ),
        actions: [
          // Demo/Live pill
          GestureDetector(
            onTap: () => _showModeToggle(context, modeProvider),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (modeProvider.isDemoMode ? AppColors.warning : AppColors.success).withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: (modeProvider.isDemoMode ? AppColors.warning : AppColors.success).withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: modeProvider.isDemoMode ? AppColors.warning : AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    modeProvider.isDemoMode ? 'DEMO' : 'LIVE',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: modeProvider.isDemoMode ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Dark/light toggle
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: cs.onSurface,
            ),
            onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        backgroundColor: cs.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
            context.read<MainTabProvider>().setIndex(index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.explore_rounded), label: 'Explore'),
          NavigationDestination(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/upload'),
        backgroundColor: AppColors.primary,
        icon:
            const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
        label: const Text('Upload',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
    );
  }
}

class _PremiumSidebar extends StatelessWidget {
  final void Function(_NavItem item) openItem;
  final bool Function(_NavItem item) isActive;
  /// When true (mobile drawer), content scrolls and skips [Spacer] layout.
  final bool scrollable;

  const _PremiumSidebar({
    required this.openItem,
    required this.isActive,
    this.scrollable = false,
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
            const Text(
              'Art Marketplace & Studio',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderStrong),
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Account & preferences',
                    style: TextStyle(
                      color: AppColors.textSecondary,
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
              icon: const Icon(Icons.settings_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
          ],
        ),
      ),
    );

    final columnChildren = <Widget>[
      ...headerAndNav,
      if (!scrollable) const Spacer(),
      if (scrollable) const SizedBox(height: 20),
      accountPanel,
    ];

    final body = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...headerAndNav,
                const SizedBox(height: 12),
                accountPanel,
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columnChildren,
          );

    if (scrollable) {
      return body;
    }

    return Container(
      width: 286,
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(
          right: BorderSide(
            color: AppColors.borderStrong.withValues(alpha: 0.9),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
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
              style: const TextStyle(
                color: AppColors.textTertiary,
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
                    ? AppColors.surface.withValues(alpha: 0.75)
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
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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

  const _ShellTopBar({
    required this.modeProvider,
    required this.authProvider,
    required this.onModeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  tp.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => context.push('/profile'),
            borderRadius: BorderRadius.circular(999),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.22),
              backgroundImage: authProvider.user?.userMetadata?['avatar_url'] !=
                      null
                  ? NetworkImage(authProvider.user!.userMetadata!['avatar_url'])
                  : null,
              child: authProvider.user?.userMetadata?['avatar_url'] == null
                  ? Text(
                      (authProvider.user?.email ?? 'A')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
          ),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 21),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
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
              '$label MODE',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

void _showModeToggle(BuildContext context, AppModeProvider provider) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
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
          const Text(
            'Switch App Mode',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Demo mode uses sample data. Live mode uses your real Artyug account and transactions.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4),
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
              active ? color.withValues(alpha: 0.14) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : AppColors.border),
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
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
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
