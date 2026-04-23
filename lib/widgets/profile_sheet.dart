/// ArtYug Profile Quick Sheet
/// Zoom-inspired profile panel that slides up from the profile avatar tap.
/// Shows avatar, name, email, quick stats, and navigation actions.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Shows the profile bottom sheet.
Future<void> showProfileSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select(
              'id, display_name, username, bio, profile_picture_url, '
              'artist_type, is_verified, is_premium, followers_count, '
              'following_count, artworks_count')
          .eq('id', uid)
          .single();
      if (!mounted) return;
      setState(() {
        _profile = data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    // Fallback values from auth metadata if profile not loaded
    final name = _profile?['display_name'] as String? ??
        user?.userMetadata?['full_name'] as String? ??
        'Artyug User';
    final email = user?.email ?? '';
    final avatarUrl = _profile?['profile_picture_url'] as String? ??
        user?.userMetadata?['avatar_url'] as String?;
    final artistType = _profile?['artist_type'] as String?;
    final isVerified = _profile?['is_verified'] as bool? ?? false;
    final isPremium = _profile?['is_premium'] as bool? ?? false;
    final followersCount = (_profile?['followers_count'] as num?)?.toInt() ?? 0;
    final artworksCount = (_profile?['artworks_count'] as num?)?.toInt() ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.72, 0.92],
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(
                        color: AppColors.primary))
                    : ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          // ── Avatar + name + email ──────────────────────────
                          Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.2),
                                  backgroundImage: avatarUrl != null
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        )
                                      : null,
                                ),
                                if (isPremium)
                                  Positioned(
                                    top: -6,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFF6A2B),
                                              Color(0xFFE8470A),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: const Text(
                                          'PRO',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded,
                                    color: AppColors.primary, size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Email chip
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(100),
                                border:
                                    Border.all(color: AppColors.borderStrong),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _maskEmail(email),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.expand_more_rounded,
                                      color: AppColors.textTertiary, size: 14),
                                ],
                              ),
                            ),
                          ),

                          if (artistType != null) ...[
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                _capitalise(artistType),
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // ── Stats row ───────────────────────────────────────
                          Row(
                            children: [
                              _StatChip(label: 'Artworks', value: '$artworksCount'),
                              const SizedBox(width: 10),
                              _StatChip(label: 'Followers', value: _compact(followersCount)),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Action list ─────────────────────────────────────
                          _ActionSection(
                            items: [
                              _ActionItem(
                                icon: Icons.person_outline_rounded,
                                label: 'My Profile',
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/profile');
                                },
                              ),
                              _ActionItem(
                                icon: Icons.dashboard_customize_rounded,
                                label: 'Creator Dashboard',
                                onTap: () {
                                  Navigator.pop(context);
                                  context.go('/main?tab=3&dashboard=creator');
                                },
                              ),
                              _ActionItem(
                                icon: Icons.store_rounded,
                                label: 'My Artworks for Sale',
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/shop');
                                },
                              ),
                              _ActionItem(
                                icon: Icons.gavel_rounded,
                                label: 'My Auctions',
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/auctions');
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ActionSection(
                            items: [
                              _ActionItem(
                                icon: Icons.settings_rounded,
                                label: 'Settings',
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/settings');
                                },
                              ),
                              _ActionItem(
                                icon: Icons.logout_rounded,
                                label: 'Sign out',
                                destructive: true,
                                onTap: () async {
                                  Navigator.pop(context);
                                  await auth.signOut();
                                  if (context.mounted) {
                                    context.go('/sign-in');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length < 2) return email;
    final name = parts[0];
    final visible = name.length > 3 ? name.substring(0, 3) : name;
    return '$visible***@${parts[1]}';
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  final List<_ActionItem> items;
  const _ActionSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              ListTile(
                onTap: item.onTap,
                dense: true,
                leading: Icon(item.icon,
                    size: 20,
                    color: item.destructive
                        ? AppColors.error
                        : AppColors.textSecondary),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: item.destructive
                        ? AppColors.error
                        : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: item.destructive
                    ? null
                    : const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textTertiary, size: 18),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 52,
                    color: AppColors.border.withValues(alpha: 0.5)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
}

/// Compact avatar widget for top-right of AppBar / Shell header.
/// Tap → opens the profile sheet.
class ProfileAvatarButton extends StatelessWidget {
  final double radius;
  const ProfileAvatarButton({super.key, this.radius = 17});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final avatarUrl = auth.user?.userMetadata?['avatar_url'] as String?;
    final name = auth.user?.userMetadata?['full_name'] as String? ?? '';

    return GestureDetector(
      onTap: () => showProfileSheet(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withValues(alpha: 0.18),
            backgroundImage:
                avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: radius * 0.85,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          // Online indicator dot
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
