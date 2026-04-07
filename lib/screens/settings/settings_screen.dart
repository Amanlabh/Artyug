import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../widgets/onboarding_guide.dart';
import '../../core/config/app_config.dart';

// ignore: unused_import
import 'dart:ui';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _saveNotifications(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', v);
    setState(() => _notificationsEnabled = v);
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await Provider.of<AuthProvider>(context, listen: false).signOut();
        if (mounted) context.go('/sign-in');
      } catch (_) {
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.textPrimary,
        content: Text('$feature — coming soon!',
            style: const TextStyle(color: AppColors.background)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Container(height: 1, color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile ───────────────────────────────────────────────
            _SectionLabel('PROFILE'),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                subtitle: 'Update your name, bio, and photo',
                onTap: () => context.push('/edit-profile'),
              ),
              _SettingsTile(
                icon: Icons.lock_outline,
                label: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showComingSoon('Password change'),
                isLast: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ── Authenticity ──────────────────────────────────────────
            _SectionLabel('AUTHENTICITY'),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.qr_code_scanner_outlined,
                label: 'Scan QR Code',
                subtitle: 'Verify artwork authenticity',
                onTap: () => context.push('/verify'),
              ),
              _SettingsTile(
                icon: Icons.nfc_outlined,
                label: 'NFC Scan',
                subtitle: 'Read NFC chip on physical artwork',
                onTap: () => context.push('/nfc-scan'),
              ),
              _SettingsTile(
                icon: Icons.verified_outlined,
                label: 'My Certificates',
                subtitle: 'View your authenticity certificates',
                onTap: () => context.push('/certificates'),
                isLast: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ── Notifications ─────────────────────────────────────────
            _SectionLabel('NOTIFICATIONS'),
            _SettingsGroup(children: [
              _SwitchTile(
                icon: Icons.notifications_outlined,
                label: 'Push Notifications',
                subtitle: 'Likes, comments, and sales alerts',
                value: _notificationsEnabled,
                onChanged: _saveNotifications,
                isLast: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ── Support ───────────────────────────────────────────────
            _SectionLabel('SUPPORT'),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.help_outline,
                label: 'Help Center',
                subtitle: 'FAQ and how-to guides',
                onTap: () => _showComingSoon('Help center'),
              ),
              _SettingsTile(
                icon: Icons.mail_outline,
                label: 'Contact Support',
                subtitle: 'hello@artyug.in',
                onTap: () => _showComingSoon('Support contact'),
                isLast: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ── Developer / Mode ─────────────────────────────────────
            _SectionLabel('APPEARANCE & MODE'),
            _SettingsGroup(children: [
              Builder(builder: (ctx) {
                final tp = ctx.watch<ThemeProvider>();
                return _SwitchTile(
                  icon: tp.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  label: 'Dark Mode',
                  subtitle: tp.isDarkMode ? 'Switch to light theme' : 'Switch to dark theme',
                  value: tp.isDarkMode,
                  onChanged: (v) => tp.toggleTheme(v),
                );
              }),
              Builder(builder: (ctx) {
                final modeProvider = ctx.watch<AppModeProvider>();
                return _SwitchTile(
                  icon: modeProvider.isDemoMode ? Icons.science_outlined : Icons.flash_on_rounded,
                  label: 'Live Mode',
                  subtitle: modeProvider.isDemoMode
                      ? 'Currently using sample data'
                      : 'Using real Supabase + payments',
                  value: modeProvider.isLiveMode,
                  onChanged: (v) => modeProvider.setMode(v ? AppMode.live : AppMode.demo),
                );
              }),
              _SettingsTile(
                icon: Icons.auto_awesome_outlined,
                label: 'Replay App Guide',
                subtitle: 'Show the intro walkthrough again',
                onTap: () async {
                  await OnboardingGuide.reset();
                  if (context.mounted) {
                    await OnboardingGuide.showIfNeeded(context, force: true);
                  }
                },
                isLast: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ── Account ───────────────────────────────────────────────
            _SectionLabel('ACCOUNT'),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.exit_to_app_outlined,
                label: 'Sign Out',
                onTap: _handleSignOut,
                showArrow: false,
                isLast: true,
              ),
            ]),

            const SizedBox(height: 8),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.delete_outline,
                label: 'Delete Account',
                subtitle: 'Permanently remove all data',
                onTap: () => _showComingSoon('Account deletion'),
                showArrow: false,
                isDanger: true,
                isLast: true,
              ),
            ]),

            const SizedBox(height: 32),

            // ── App version ───────────────────────────────────────────
            Center(
              child: Column(children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: 'ARTYUG',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: -0.15)),
                    const TextSpan(
                        text: '.',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            color: Color(0xFFE8470A),
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                  ]),
                ),
                const SizedBox(height: 4),
                const Text('v1.0.0 · SocialFi Art Platform',
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 12)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1)),
    );
  }
}

// ─── Settings Group ───────────────────────────────────────────────────────────
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showArrow;
  final bool isDanger;
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.showArrow = true,
    this.isDanger = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.error : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: isLast
            ? null
            : const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.8))),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDanger
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (showArrow)
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
        ]),
      ),
    );
  }
}

// ─── Switch Tile ──────────────────────────────────────────────────────────────
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  const _SwitchTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.8))),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withOpacity(0.3),
          inactiveThumbColor: AppColors.textTertiary,
          inactiveTrackColor: AppColors.surfaceVariant,
        ),
      ]),
    );
  }
}
